//
//  DivisionProfile.swift
//  GMJuice
//
//  Created by Andre Taube on 10/11/25.
//

import SwiftData

@Model
final class DivisionProfile {
    var division: Division
    var classification: ShooterClass = ShooterClass.U
    init(division: Division) { self.division = division }
}
