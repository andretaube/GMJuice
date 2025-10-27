//
//  RecordingViewModel.swift
//  GMJuice
//

import Foundation
import Combine
import SwiftData
import SwiftUI

@MainActor
public class RecordingViewModel: ObservableObject {
    private let stageId : String
    private let divisionId : String

    @Published var stringRun: StringRun
    @Published var counter: Int = 0
    @Published var allRuns: [StringRun] = []
    @Published var connectionStatus: BLEConnectionStatus = .Disconnected

    private let ble = BLEManager.shared
    private var cancellables = Set<AnyCancellable>()

    init(stageId: String, divisionId: String) {

        stringRun = StringRun(stageId: stageId, divisionId: divisionId)

        self.stageId = stageId
        self.divisionId = divisionId

        // Subscribe to BLE connection status changes
        ble.$connectionStatus
            .receive(on: RunLoop.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)

        ble.onBeep = {[weak self] in
            self?.startString()
        }

        ble.onShot = {[weak self] now, split, first in
            self?.recordShot(now: now, split: split, first: first)
        }
    }

    func startString() {
        stringRun = StringRun(stageId: self.stageId, divisionId: self.divisionId)
        allRuns.append(stringRun)
        counter += 1
    }

    func recordShot(now: Decimal, split: Decimal, first: Decimal) {
        let stringShot = StringShot(now: now, split: split, first: first)
        stringRun.time = now
        stringRun.stringShots.append(stringShot)
    }
    
    func bestTime() -> Decimal? {
        allRuns
            .filter { $0.time > 0 }
            .map { $0.adjustedTime }
            .min()
    }

    func bestFirstShot() -> Decimal? {
        allRuns
            .compactMap { run in
                run.stringShots.first?.first
            }
            .filter { $0 > 0 }
            .min()
    }
    
    func worstTime() -> Decimal? {
        allRuns
            .filter { $0.time > 0 }
            .map { $0.adjustedTime }
            .max()
    }

    func worstFirstShot() -> Decimal? {
        allRuns
            .compactMap { run in
                run.stringShots.first?.first
            }
            .filter { $0 > 0 }
            .max()
    }
    
    func times() -> [Decimal] {
        allRuns
            .sorted { $0.date < $1.date }
            .map(\.time)          // extract each run's total time
            .filter { $0 > 0 }    // only valid (non-zero) times
    }

    // MARK: - Steel Challenge Penalty Calculation

    /// Get the adjusted time (raw time + penalties), capped at 30 seconds
    func adjustedTime(for run: StringRun) -> Decimal {
        return run.adjustedTime
    }

    /// Check if a run should flash red
    func shouldFlashRed(for run: StringRun) -> Bool {
        return run.shouldFlashRed
    }
}
