//
//  ShooterProfile+Extensions.swift
//  GMJuice
//
//  Created by Andre Taube on 10/17/25.
//

extension ShooterProfile {
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
