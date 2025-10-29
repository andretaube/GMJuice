//
//  RecordingManager.swift
//  GMJuice
//
//  Manages the recording session lifecycle:
//  - Subscribes to BLE timer events
//  - Manages recording state (current string, shot tracking)
//  - Persists completed strings to database
//  - Provides callbacks for UI/voice components
//

import Foundation
import SwiftData
import Combine

@MainActor
final class RecordingManager: ObservableObject {
    static let shared = RecordingManager()

    // MARK: - Published State

    @Published var currentString: StringRun?
    @Published var isRecording = false
    @Published var shotCount = 0
    @Published var allStrings: [StringRun] = []
    @Published var stringCounter = 0

    // MARK: - Callbacks for External Components

    /// Called when a new string is started
    var onStringStarted: ((StringRun) -> Void)?

    /// Called when a shot is recorded
    var onShotRecorded: ((StringShot, Int) -> Void)?  // shot, total count

    /// Called when string is completed and saved to database
    var onStringCompleted: ((StringRun) -> Void)?

    /// Called when string is cancelled
    var onStringCancelled: (() -> Void)?

    // MARK: - Private Properties

    private let ble = BLEManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?

    // Current session context
    private var currentStageId: String?
    private var currentDivisionId: String?

    private init() {
        setupBLECallbacks()
    }

    // MARK: - Session Management

    /// Start a new recording session for a stage/division
    func startSession(stageId: String, divisionId: String, modelContext: ModelContext) {
        self.currentStageId = stageId
        self.currentDivisionId = divisionId
        self.modelContext = modelContext
        self.allStrings = []
        self.stringCounter = 0
        print("📝 Recording session started: \(stageId) - \(divisionId)")
    }

    /// End the current recording session
    func endSession() {
        if isRecording {
            finishString()
        }

        // Clear all state to prevent stale references
        currentString = nil
        currentStageId = nil
        currentDivisionId = nil
        modelContext = nil
        allStrings = []
        stringCounter = 0
        isRecording = false
        shotCount = 0

        // Clear callbacks to prevent stale references
        onStringStarted = nil
        onShotRecorded = nil
        onStringCompleted = nil
        onStringCancelled = nil

        print("🏁 Recording session ended - all state and callbacks cleared")
    }

    // MARK: - String Management

    /// Start a new string
    func startString() {
        guard let stageId = currentStageId,
              let divisionId = currentDivisionId else {
            print("⚠️ Cannot start string: no active session")
            return
        }

        let newString = StringRun(stageId: stageId, divisionId: divisionId)
        currentString = newString
        allStrings.append(newString)
        stringCounter += 1
        isRecording = true
        shotCount = 0

        print("📝 String #\(stringCounter) started")
        onStringStarted?(newString)
    }

    /// Finish the current string and persist to database
    func finishString() {
        guard let string = currentString else {
            print("⚠️ No current string to finish")
            return
        }

        isRecording = false

        // Save to database if we have 5+ shots and context is available
        if shotCount >= 5 {
            guard let context = modelContext else {
                print("⚠️ No model context available - string not saved to database")
                print("🏁 String finished (not persisted)")
                return
            }

            do {
                context.insert(string)
                try context.save()
                print("💾 String saved to database: \(string.time)s")
                onStringCompleted?(string)
            } catch {
                print("❌ Failed to save string: \(error)")
            }
        }

        print("🏁 String finished")
    }

    /// Cancel the current string (don't save to database)
    func cancelString() {
        guard let string = currentString else {
            print("⚠️ No current string to cancel")
            return
        }

        // Remove from allStrings
        if let index = allStrings.firstIndex(where: { $0 === string }) {
            allStrings.remove(at: index)
            stringCounter -= 1
        }

        currentString = nil
        isRecording = false
        shotCount = 0

        print("🚫 String cancelled")
        onStringCancelled?()
    }

    /// Record a shot in the current string
    func recordShot(now: Decimal, split: Decimal, first: Decimal) {
        guard isRecording, let string = currentString else {
            print("⚠️ Shot ignored: not recording")
            return
        }

        let shot = StringShot(now: now, split: split, first: first)
        string.stringShots.append(shot)
        string.time = now
        shotCount = string.stringShots.count

        print("💥 Shot #\(shotCount) recorded: \(now)s")
        onShotRecorded?(shot, shotCount)
    }

    /// Toggle a target as miss/hit
    func toggleTargetMiss(_ target: Int) {
        guard let string = currentString else {
            print("⚠️ No current string to toggle miss")
            return
        }

        // Validate target number (1-5)
        guard target >= 1 && target <= 5 else {
            print("⚠️ Invalid target number: \(target)")
            return
        }

        if let index = string.missedTargets.firstIndex(of: target) {
            string.missedTargets.remove(at: index)
            print("✓ Target \(target) marked as HIT")
        } else {
            string.missedTargets.append(target)
            print("✓ Target \(target) marked as MISS")
        }

        // Save if already persisted
        if let context = modelContext {
            // Check if string is already inserted in context
            do {
                try context.save()
            } catch {
                print("⚠️ Failed to save miss toggle: \(error)")
            }
        }
    }

    // MARK: - BLE Integration

    private func setupBLECallbacks() {
        ble.onBeep = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("🎵 BLE: Beep detected")

                // If already recording, finish current string first
                if self.isRecording {
                    self.finishString()
                }

                // Start new string
                self.startString()
            }
        }

        ble.onShot = { [weak self] now, split, first in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("🎯 BLE: Shot detected")
                self.recordShot(now: now, split: split, first: first)
            }
        }
    }
}
