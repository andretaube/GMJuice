//
//  RecordingManager.swift
//  GMJuice
//
//  Manages the set-based recording session:
//  - Subscribes to BLE timer beep/shot events
//  - Groups strings into sets (5 strings, or 4 for Outer Limits)
//  - On set completion, scores the best (N-1) strings, persists a StageRun,
//    and pushes it onto the session history; the next beep starts a fresh set
//

import Foundation
import SwiftData
import Combine

@MainActor
final class RecordingManager: ObservableObject {
    static let shared = RecordingManager()

    // MARK: - Published State

    /// The string currently being shot (nil before the first beep / between sets is impossible — always restarts).
    @Published var currentString: StringRun?
    /// Finalized strings in the current set (not yet including the in-progress string).
    @Published var currentSet: [StringRun] = []
    /// Completed, scored stages this session (most recent last).
    @Published var completedStages: [StageRun] = []
    @Published var isRecording = false
    @Published var shotCount = 0
    /// Number of strings per set: 5 for most stages, 4 for Outer Limits (SC-104).
    @Published var setSize = 5
    /// 1-based index of the string currently being shot, within the current set.
    @Published var stringIndex = 0
    /// True once the current set has all its strings shot (the stage total is now meaningful).
    @Published var setIsComplete = false

    // MARK: - Callbacks

    var onStringStarted: ((StringRun) -> Void)?
    var onShotRecorded: ((StringShot, Int) -> Void)?
    var onStringCompleted: ((StringRun) -> Void)?
    var onStageCompleted: ((StageRun) -> Void)?

    // MARK: - Private

    private let ble = BLEManager.shared
    private let analytics = AnalyticsService.shared
    private var modelContext: ModelContext?
    private var currentStageId: String?
    private var currentDivisionId: String?

    /// Number of scored strings (best N-1 of N).
    private var countedStrings: Int { max(setSize - 1, 1) }

    private init() {
        setupBLECallbacks()
    }

    // MARK: - Session

    func startSession(stageId: String, divisionId: String, modelContext: ModelContext) {
        self.currentStageId = stageId
        self.currentDivisionId = divisionId
        self.modelContext = modelContext
        self.setSize = getStage(for: stageId)?.strings ?? 5
        self.currentSet = []
        self.currentString = nil
        self.completedStages = []
        self.shotCount = 0
        self.stringIndex = 0
        self.isRecording = false
        self.setIsComplete = false
        print("📝 Set-based session started: \(stageId) - \(divisionId) (set size \(setSize))")
    }

    func endSession() {
        // Finalize an in-progress string into the set, then persist if the set is complete.
        if let s = currentString, !s.stringShots.isEmpty {
            currentSet.append(s)
        }
        currentString = nil
        if currentSet.count >= setSize {
            finalizeStage()
        }

        currentSet = []
        completedStages = []
        currentStageId = nil
        currentDivisionId = nil
        modelContext = nil
        isRecording = false
        shotCount = 0
        stringIndex = 0
        setIsComplete = false

        onStringStarted = nil
        onShotRecorded = nil
        onStringCompleted = nil
        onStageCompleted = nil
        print("🏁 Recording session ended")
    }

    // MARK: - Set / String lifecycle

    /// On each beep: finalize the previous string, roll over a completed set, and start a new string.
    /// Internal (not private) so tests can drive the set lifecycle without a live BLE timer.
    func handleBeep() {
        // 1. finalize the in-progress string into the current set
        if let s = currentString, !s.stringShots.isEmpty {
            currentSet.append(s)
            onStringCompleted?(s)
        }
        currentString = nil

        // 2. if the set is complete, score + persist it, then reset for a new set
        if currentSet.count >= setSize {
            finalizeStage()
            currentSet = []
            setIsComplete = false
        }

        // 3. start a fresh string
        startString()
    }

    private func startString() {
        guard let stageId = currentStageId, let divisionId = currentDivisionId else {
            print("⚠️ Cannot start string: no active session")
            return
        }
        let s = StringRun(stageId: stageId, divisionId: divisionId)
        currentString = s
        isRecording = true
        shotCount = 0
        stringIndex = currentSet.count + 1
        print("📝 String #\(stringIndex)/\(setSize) started")
        onStringStarted?(s)
    }

    private func finalizeStage() {
        guard let stageId = currentStageId, let divisionId = currentDivisionId else { return }
        let times = currentSet.map { $0.adjustedTime }.filter { $0 > 0 }
        guard times.count >= countedStrings else {
            print("⚠️ Set incomplete (\(times.count) valid strings) — not scored")
            return
        }
        // Best (countedStrings) = drop the slowest beyond the counted number.
        let bestN = times.sorted().prefix(countedStrings).reduce(Decimal(0), +)

        let stage = StageRun(stageId: stageId, divisionId: divisionId, date: Date(), bestNTime: bestN, stringCount: setSize)
        stage.strings = currentSet
        completedStages.append(stage)

        if let ctx = modelContext {
            ctx.insert(stage)
            do {
                try ctx.save()
                print("💾 Stage scored & saved: \(bestN)s (best \(countedStrings) of \(setSize))")
            } catch {
                print("❌ Failed to save stage: \(error)")
                analytics.trackError(error, context: "RecordingManager.finalizeStage")
            }
        }
        onStageCompleted?(stage)
    }

    func recordShot(now: Decimal, split: Decimal, first: Decimal) {
        guard isRecording, let s = currentString else {
            print("⚠️ Shot ignored: not recording")
            return
        }
        let shot = StringShot(now: now, split: split, first: first)
        s.stringShots.append(shot)
        s.time = now
        shotCount = s.stringShots.count

        // Once a full string's worth of shots is in, the (finalized + current) count
        // tells us whether the set's total is now meaningful.
        let liveStringCount = currentSet.count + 1
        setIsComplete = (liveStringCount >= setSize) && (shotCount >= 5)

        onShotRecorded?(shot, shotCount)
    }

    func toggleTargetMiss(_ target: Int) {
        guard let s = currentString else { return }
        guard target >= 1 && target <= 5 else { return }
        if let idx = s.missedTargets.firstIndex(of: target) {
            s.missedTargets.remove(at: idx)
        } else {
            s.missedTargets.append(target)
        }
        objectWillChange.send()
    }

    // MARK: - BLE

    private func setupBLECallbacks() {
        ble.onBeep = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleBeep()
            }
        }
        ble.onShot = { [weak self] now, split, first in
            Task { @MainActor [weak self] in
                self?.recordShot(now: now, split: split, first: first)
            }
        }
    }
}
