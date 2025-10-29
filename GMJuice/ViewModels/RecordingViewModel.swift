//
//  RecordingViewModel.swift
//  GMJuice
//
//  Thin view model that observes RecordingManager and provides
//  computed properties for the RecordingView UI.
//

import Foundation
import Combine
import SwiftData
import SwiftUI

@MainActor
public class RecordingViewModel: ObservableObject {
    private let stageId: String
    private let divisionId: String

    // Observe manager state
    @Published var stringRun: StringRun
    @Published var counter: Int = 0
    @Published var allRuns: [StringRun] = []
    @Published var connectionStatus: BLEConnectionStatus = .Disconnected

    private let manager = RecordingManager.shared
    private let ble = BLEManager.shared
    private var cancellables = Set<AnyCancellable>()

    init(stageId: String, divisionId: String) {
        self.stageId = stageId
        self.divisionId = divisionId

        // Initialize with empty string
        self.stringRun = StringRun(stageId: stageId, divisionId: divisionId)

        // Subscribe to BLE connection status
        ble.$connectionStatus
            .receive(on: RunLoop.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)

        // Subscribe to RecordingManager state
        manager.$currentString
            .receive(on: RunLoop.main)
            .sink { [weak self] currentString in
                guard let self = self else { return }
                // If currentString is nil, create a fresh empty string
                self.stringRun = currentString ?? StringRun(stageId: stageId, divisionId: divisionId)
            }
            .store(in: &cancellables)

        manager.$stringCounter
            .receive(on: RunLoop.main)
            .assign(to: \.counter, on: self)
            .store(in: &cancellables)

        manager.$allStrings
            .receive(on: RunLoop.main)
            .assign(to: \.allRuns, on: self)
            .store(in: &cancellables)
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
