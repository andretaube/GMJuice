//
//  Constants.swift
//  GMJuice
//
//  Created by Claude on 11/5/25.
//

import Foundation

// MARK: - UserDefaults Keys

/// UserDefaults keys for app preferences
enum UserDefaultsKeys {
    /// The USPSA number of the current user (to identify which ShooterProfile is "mine")
    static let currentUserUSPSANumber = "current_user_uspsa_number"
}

// MARK: - Helper Extensions

extension UserDefaults {
    /// Get the current user's USPSA number
    var currentUserUSPSANumber: String? {
        get { string(forKey: UserDefaultsKeys.currentUserUSPSANumber) }
        set { set(newValue, forKey: UserDefaultsKeys.currentUserUSPSANumber) }
    }
}

/// Global constants for performance analysis and coaching calculations
enum AnalysisConstants {

    // MARK: - Recency Filtering

    /// Number of recent matches to use for average/trend/consistency calculations
    static let recentMatchesThreshold = 10

    /// Number of days to look back for recent performance data (used for average, consistency, trend)
    static let recentDaysWindow = 180

    // MARK: - Chart Time Windows

    /// Number of days to show in Performance Timeline chart
    static let performanceTimelineDays = 730  // 2 years

    /// Number of days to show in Recent Performance chart (same as average calculation)
    static let recentPerformanceDays = recentDaysWindow  // 180 days

    // MARK: - Practice Priority Weights

    /// Weight given to stages below current classification level
    /// Formula: basePenalty + (gapFromLevel * multiplier)
    struct PracticePriority {
        /// Base penalty for being below current level (higher = more priority)
        static let belowLevelBasePenalty: Double = 50.0

        /// Multiplier for gap from level threshold
        /// Example: 10% gap from level = 50 + (10 * 0.5) = 55 penalty
        static let belowLevelGapMultiplier: Double = 0.5

        /// Maximum penalty for declining performance
        static let decliningMaxPenalty: Double = 12.0

        /// Multiplier for declining trend severity
        /// Example: -5% trend = abs(-5) * 2 = 10 penalty
        static let decliningTrendMultiplier: Double = 2.0

        /// Maximum penalty for high variance (inconsistency)
        static let highVarianceMaxPenalty: Double = 8.0

        /// Variance threshold for high variance classification
        /// Stages with consistency > this value are considered high variance
        static let highVarianceThreshold: Double = 8.0

        /// Variance baseline for penalty calculation
        static let highVarianceBaseline: Double = 8.0

        /// Multiplier for variance penalty
        /// Example: 10% variance = (10 - 8) / 2.5 = 0.8 penalty
        static let highVarianceDivisor: Double = 2.5

        /// Maximum penalty for large best-avg gap
        static let bestAvgGapMaxPenalty: Double = 5.0

        /// Gap threshold before penalty starts (percentage points)
        static let bestAvgGapThreshold: Double = 10.0

        /// Multiplier for gap penalty
        /// Example: 14% gap = (14 - 10) / 4 = 1 penalty
        static let bestAvgGapDivisor: Double = 4.0

        /// Number of stages to assign to high priority bucket
        static let highPriorityCount = 4

        /// Minimum number of stages to assign to maintenance bucket
        static let maintenanceMinCount = 2
    }

    // MARK: - Match Card Reliability Weights

    /// Weights for calculating match day stage reliability
    struct MatchReliability {
        /// Variance threshold for "very consistent" bonus
        static let veryConsistentThreshold: Double = 6.0

        /// Variance threshold for "moderately consistent" bonus
        static let moderateConsistentThreshold: Double = 8.0

        /// Bonus points for very consistent stages
        static let veryConsistentBonus: Double = 15.0

        /// Bonus points for moderately consistent stages
        static let moderateConsistentBonus: Double = 8.0

        /// Trend threshold for "strong improvement" bonus
        static let strongImprovementThreshold: Double = 5.0

        /// Trend threshold for "moderate improvement" bonus
        static let moderateImprovementThreshold: Double = 2.0

        /// Bonus points for strong improvement
        static let strongImprovementBonus: Double = 10.0

        /// Bonus points for moderate improvement
        static let moderateImprovementBonus: Double = 5.0

        /// Trend threshold for "strong decline" penalty
        static let strongDeclineThreshold: Double = -5.0

        /// Trend threshold for "moderate decline" penalty
        static let moderateDeclineThreshold: Double = -2.0

        /// Penalty for strong decline
        static let strongDeclinePenalty: Double = 10.0

        /// Penalty for moderate decline
        static let moderateDeclinePenalty: Double = 5.0

        /// Variance threshold for "very inconsistent" penalty
        static let veryInconsistentThreshold: Double = 10.0

        /// Variance threshold for "moderately inconsistent" penalty
        static let moderateInconsistentThreshold: Double = 8.0

        /// Penalty for very inconsistent stages
        static let veryInconsistentPenalty: Double = 15.0

        /// Penalty for moderately inconsistent stages
        static let moderateInconsistentPenalty: Double = 8.0

        /// Number of stages to categorize as "banker" stages
        static let bankerStagesCount = 4

        /// Number of stages to categorize as "risk" stages
        static let riskStagesCount = 3
    }

    // MARK: - Performance Classification Thresholds

    /// Thresholds for identifying performance issues
    struct PerformanceThresholds {
        /// Trend below this value is considered "declining"
        static let decliningTrendThreshold: Double = -5.0

        /// Variance above this value is considered "high variance"
        static let highVarianceThreshold: Double = 8.0

        /// Minimum matches required for volatile stage identification
        static let volatileStageMinMatches = 3

        /// Trend above this value is considered "improving"
        static let improvingTrendThreshold: Double = 2.0

        /// Trend within +/- this value is considered "stable"
        static let stableTrendThreshold: Double = 2.0
    }

    // MARK: - Trend Calculation

    /// Parameters for trend line calculations
    struct TrendCalculation {
        /// Minimum number of scores required for trend calculation
        static let minimumScoresForTrend = 4

        /// Minimum number of scores required for overall trend direction
        static let minimumScoresForDirection = 6

        /// Recent fraction for overall trend (last 1/3 of scores)
        static let recentFractionDivisor = 3
    }

    // MARK: - Temporal Analysis

    /// Thresholds for training frequency and temporal patterns
    struct TemporalThresholds {
        /// Days defining "very frequent" training (weekly or more)
        static let veryFrequentMaxDays: Double = 14.0

        /// Days defining "regular" training (bi-weekly to monthly)
        static let regularMaxDays: Double = 45.0

        /// Days defining "occasional" training (every 1-3 months)
        static let occasionalMaxDays: Double = 90.0

        /// Days defining a "significant gap" in training
        static let significantGapDays = 60

        /// Days to look back for "improved stages" calculation
        static let improvedStagesLookbackDays = 30
    }

    // MARK: - Consistency Rating Thresholds

    /// Thresholds for rating consistency
    /// Consistency = Average % point variation around the average % across recent scores
    /// This measures how much your scores vary (independent of how close they are to your best)
    ///
    /// Example: If average is 88% and recent scores are 88%, 87%, 89%, 86%
    /// Differences from average: |88-88|, |87-88|, |89-88|, |86-88| = 0, 1, 1, 2
    /// Consistency = (0 + 1 + 1 + 2) / 4 = 1.0 percentage points (very consistent!)
    ///
    /// If average is 88% but scores are 82%, 86%, 90%, 94%
    /// Differences from average: 6, 2, 2, 6
    /// Consistency = (6 + 2 + 2 + 6) / 4 = 4.0 percentage points (less consistent)
    struct ConsistencyRating {
        /// Threshold for "Great" consistency (scores vary within ±3% of average)
        static let greatThreshold: Double = 3.0

        /// Threshold for "Good" consistency (scores vary within ±5% of average)
        static let goodThreshold: Double = 5.0

        /// Threshold for "Medium" consistency (scores vary within ±8% of average)
        static let mediumThreshold: Double = 8.0

        // Above medium = "Low" consistency (scores vary more than ±8% from average)
    }

    // MARK: - Helper Methods

    /// Get the number of scores to use for recent analysis
    /// - Parameters:
    ///   - recentScores: Scores within the recent days window
    ///   - allScores: All available scores
    /// - Returns: Array of scores to use (recent window or last N matches)
    static func getRecentScores<T>(recentScores: [T], allScores: [T]) -> [T] {
        // Get last N matches
        let lastNMatches = Array(allScores.suffix(recentMatchesThreshold))

        // Use whichever is larger: last 90 days OR last N matches
        if recentScores.count > lastNMatches.count {
            return recentScores
        } else {
            return lastNMatches
        }
    }
}
