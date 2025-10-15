//
//  RecordingViewModel.swift
//  TrainingApp
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


    private let ble = BLEManager.shared
    
    init(stageId: String, divisionId: String) {
        
        stringRun = StringRun(stageId: stageId, divisionId: divisionId)
        
        self.stageId = stageId
        self.divisionId = divisionId
        
        ble.onBeep = {[weak self] in
            self?.startString()
        }
        
        ble.onShot = {[weak self] now, split, first in
            self?.recordShot(now: now, split: split, first: first)
        }
    }
    
    func startString() {
        if !stringRun.stringShots.isEmpty {
            allRuns.append(stringRun)
        }
        stringRun = StringRun(stageId: self.stageId, divisionId: self.divisionId)
        counter += 1
    }

    func recordShot(now: Double, split: Double, first: Double) {
        let stringShot = StringShot(now: now, split: split, first: first)
        stringRun.time = now
        stringRun.stringShots.append(stringShot)
    }
    
    func bestTime() -> Double? {
        allRuns
            .filter { $0.time > 0 }
            .map(\.time)
            .min()
    }

    func bestFirstShot() -> Double? {
        allRuns
            .compactMap { run in
                run.stringShots.first?.first
            }
            .filter { $0 > 0 }
            .min()
    }
    
    func worstTime() -> Double? {
        allRuns
            .filter { $0.time > 0 }
            .map(\.time)
            .max()
    }

    func worstFirstShot() -> Double? {
        allRuns
            .compactMap { run in
                run.stringShots.first?.first
            }
            .filter { $0 > 0 }
            .max()
    }
}
