//
//  ShooterProfile.swift
//  TrainingApp
//
//  Created by Andre Taube on 10/11/25.
//

import SwiftData

@Model
final class ShooterProfile {
    var uspsaNumber: String?
    var divisions: [DivisionProfile] = []
    var defaultDivision: Division?   // used as initial “active” suggestion

    init(uspsaNumber: String? = nil) {
        self.uspsaNumber = uspsaNumber
    }

    // helpers
    func profile(for division: Division) -> DivisionProfile? {
        divisions.first { $0.division == division }
    }
    func ensureProfile(for division: Division) -> DivisionProfile {
        if let existing = profile(for: division) { return existing }
        let dp = DivisionProfile(division: division)
        divisions.append(dp)
        return dp
    }
    func removeDivision(_ division: Division) {
        divisions.removeAll { $0.division == division }
        if defaultDivision == division { defaultDivision = nil }
    }
}
