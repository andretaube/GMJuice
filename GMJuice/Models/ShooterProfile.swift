//
//  ShooterProfile.swift
//  GMJuice
//
//  Created by Andre Taube on 10/11/25.
//

import SwiftData

@Model
final class ShooterProfile {
    // Make it non-optional so TextField binding is simple
    var uspsaNumber: String = ""

    // Persisted relationship to division profiles
    @Relationship(deleteRule: .cascade)
    var divisions: [DivisionProfile] = []

    init(uspsaNumber: String = "") {
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
    }
}
