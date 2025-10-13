//
//  DivisionProfile.swift
//  TrainingApp
//
//  Created by Andre Taube on 10/11/25.
//

import SwiftData

@Model
final class DivisionProfile {
    var division: Division
    var classification: ShooterClass

    init(division: Division, classification: ShooterClass = .U) {
        self.division = division
        self.classification = classification
    }
}
