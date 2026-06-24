//
//  RecordingViewModel.swift
//  GMJuice
//
//  Observes RecordingManager and exposes set-based state for RecordingView.
//

import Foundation
import Combine
import SwiftData
import SwiftUI

@MainActor
public class RecordingViewModel: ObservableObject, RecordingViewModelProtocol {
    private let stageId: String
    private let divisionId: String

    @Published var currentString: StringRun?
    @Published var currentSet: [StringRun] = []
    @Published var completedStages: [StageRun] = []
    @Published var setSize: Int = 5
    @Published var stringIndex: Int = 0
    @Published var setIsComplete: Bool = false
    @Published var shotCount: Int = 0
    @Published var connectionStatus: BLEConnectionStatus = .Disconnected

    private let manager = RecordingManager.shared
    private let ble = BLEManager.shared
    private var cancellables = Set<AnyCancellable>()

    init(stageId: String, divisionId: String) {
        self.stageId = stageId
        self.divisionId = divisionId

        ble.$connectionStatus.receive(on: RunLoop.main).assign(to: \.connectionStatus, on: self).store(in: &cancellables)
        manager.$currentString.receive(on: RunLoop.main).assign(to: \.currentString, on: self).store(in: &cancellables)
        manager.$currentSet.receive(on: RunLoop.main).assign(to: \.currentSet, on: self).store(in: &cancellables)
        manager.$completedStages.receive(on: RunLoop.main).assign(to: \.completedStages, on: self).store(in: &cancellables)
        manager.$setSize.receive(on: RunLoop.main).assign(to: \.setSize, on: self).store(in: &cancellables)
        manager.$stringIndex.receive(on: RunLoop.main).assign(to: \.stringIndex, on: self).store(in: &cancellables)
        manager.$setIsComplete.receive(on: RunLoop.main).assign(to: \.setIsComplete, on: self).store(in: &cancellables)
        manager.$shotCount.receive(on: RunLoop.main).assign(to: \.shotCount, on: self).store(in: &cancellables)
    }

    /// Strings shown for the current set: finalized strings plus the in-progress one (if it has shots).
    var displayedSetStrings: [StringRun] {
        var arr = currentSet
        if let s = currentString, !s.stringShots.isEmpty { arr.append(s) }
        return arr
    }

    var countedStrings: Int { max(setSize - 1, 1) }

    /// Index (within displayedSetStrings) of the slowest string — the one that gets dropped.
    func worstIndex() -> Int? {
        let strings = displayedSetStrings
        guard strings.count > 1 else { return nil }
        var worst = 0
        for (i, s) in strings.enumerated() where s.adjustedTime > strings[worst].adjustedTime { worst = i }
        return worst
    }

    /// Stage total (sum of best N-1) once the set has all its strings; nil otherwise.
    func stageTotal() -> Decimal? {
        let times = displayedSetStrings.map { $0.adjustedTime }.filter { $0 > 0 }
        guard times.count >= setSize else { return nil }
        return times.sorted().prefix(countedStrings).reduce(Decimal(0), +)
    }

    func adjustedTime(for run: StringRun) -> Decimal { run.adjustedTime }
    func shouldFlashRed(for run: StringRun) -> Bool { run.shouldFlashRed }
}
