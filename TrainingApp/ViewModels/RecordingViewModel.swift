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
        stringRun = StringRun(stageId: self.stageId, divisionId: self.divisionId)
        counter += 1
    }

    func recordShot(now: Double, split: Double, first: Double) {
        let stringShot = StringShot(now: now, split: split, first: first)
        stringRun.time = now
        stringRun.stringShots.append(stringShot)
    }
}
