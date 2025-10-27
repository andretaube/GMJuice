//
//  StringRun+Extensions.swift
//  GMJuice
//
//  Created by Andre Taube on 10/17/25.
//

import Foundation

extension StringRun {
    var orderedStringShots: [StringShot] {
        stringShots.sorted { $0.now < $1.now }
    }

    // MARK: - Steel Challenge Penalty Calculation

    /// Calculate penalty time for a string run based on missed targets
    /// Returns (penaltySeconds, shouldFlashRed)
    func calculatePenalty() -> (penalty: Decimal, shouldFlash: Bool) {
        var penalty: Decimal = 0

        // Calculate penalty for each missed target
        for target in missedTargets {
            if target == 5 {
                // Stop plate miss: +30 seconds (max penalty)
                penalty += 30
            } else {
                // Regular plate miss: +3 seconds
                penalty += 3
            }
        }

        // Cap at 30 seconds and determine if should flash
        let shouldFlash = penalty >= 30
        penalty = min(penalty, 30)

        return (penalty, shouldFlash)
    }

    /// Get the adjusted time (raw time + penalties), capped at 30 seconds
    var adjustedTime: Decimal {
        let (penalty, _) = calculatePenalty()
        let adjusted = time + penalty
        return min(adjusted, 30)
    }

    /// Check if a run should flash red (has 30-second penalty)
    var shouldFlashRed: Bool {
        let (_, shouldFlash) = calculatePenalty()
        return shouldFlash
    }
}
