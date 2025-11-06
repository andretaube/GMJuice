//
//  SCPerformanceAnalyzer.swift
//  GMJuice
//
//  Created by Claude on 11/4/25.
//

import Foundation
import SwiftData

// MARK: - Analysis Models

/// Temporal training context
struct TemporalAnalysis {
    let daysSinceLastMatch: Int
    let trainingFrequency: TrainingCadence
    let averageGapDays: Double
    let hasRecentGap: Bool           // 60+ days since last match

    enum TrainingCadence: String {
        case veryFrequent = "Weekly or more"
        case regular = "Bi-weekly to monthly"
        case occasional = "Every 1-3 months"
        case infrequent = "Sporadic (3+ months)"
        case insufficient = "Insufficient data"
    }
}

/// Per-stage performance metrics
struct StageAnalysis {
    let stageCode: String
    let stageName: String
    let matchCount: Int

    // Time statistics
    let averageTime: Decimal
    let bestTime: Decimal
    let standardDeviation: Decimal
    let peakTime: Decimal

    // Performance metrics
    let consistencyScore: Decimal  // Average % point variation around recent average (lower = more consistent)
    let performanceVsPeak: Decimal // Percentage of peak (based on recent average)
    let recentTrend: Decimal       // Positive = improving, negative = declining

    // Classification context
    let bestClassification: ShooterClass
    let averageClassification: ShooterClass

    // Improvement potential (based on best time)
    let bestPerformanceVsPeak: Decimal  // Percentage of peak based on best time
    let nextClassification: ShooterClass // Target classification level
    let timeToNextLevel: Decimal        // Time needed to reach next classification
    let gainToNextLevel: Decimal        // Seconds to improve from best to reach next level

    // Temporal context
    let mostRecentDate: Date?
    let oldestDate: Date?
}

/// Complete performance analysis for a division
struct CoachingAnalysis {
    let memberNumber: String
    let divisionCode: String
    let matchCount: Int
    let totalMatchesAnalyzed: Int

    // Current classification from profile
    let currentClassification: ShooterClass
    let currentPercentage: Decimal?

    // Classification metrics
    let currentTime: Decimal?               // Average time of classification stages
    let improvedStagesCount: Int            // Stages improved in last 30 days
    let classificationStagesCount: Int      // Stages used for classification in last 30 days

    // Stage-by-stage breakdown
    let stageAnalyses: [StageAnalysis]

    // Strategic insights
    let topStrengths: [StageAnalysis]      // Best 3 stages
    let topWeaknesses: [StageAnalysis]     // Worst 3 stages
    let volatileStages: [StageAnalysis]    // High variance stages

    // Overall metrics
    let overallConsistency: Decimal
    let recentPerformanceDirection: TrendDirection

    // Temporal analysis
    let temporalAnalysis: TemporalAnalysis

    enum TrendDirection {
        case improving
        case stable
        case declining
    }
}

// MARK: - Performance Analyzer

/// Analyzes SCSA match performance data to generate coaching insights
class SCPerformanceAnalyzer {
    private let memberNumber: String
    private let divisionCode: String
    private let context: ModelContext

    init(memberNumber: String, divisionCode: String, context: ModelContext) {
        self.memberNumber = memberNumber
        self.divisionCode = divisionCode
        self.context = context
    }

    /// Analyze all available performance data
    func analyzePerformance() throws -> CoachingAnalysis {
        // Fetch all scores for this member and division
        let descriptor = FetchDescriptor<SCMatchScore>(
            predicate: #Predicate<SCMatchScore> { score in
                score.memberNumber == memberNumber &&
                score.divisionCode == divisionCode
            },
            sortBy: [SortDescriptor(\SCMatchScore.scoreDate)]
        )

        let allScores = try context.fetch(descriptor)

        guard !allScores.isEmpty else {
            throw AnalysisError.noData
        }

        // Get current classification from profile
        let profileDescriptor = FetchDescriptor<ShooterProfile>()
        let profiles = try context.fetch(profileDescriptor)
        let profile = profiles.first

        let divisionEnum = Division(rawValue: divisionCode)
        let divProfile = profile?.divisions.first { $0.division == divisionEnum }
        let currentClassification = divProfile?.classification ?? .U
        let currentPercentage = divProfile?.currentPercentage

        // Analyze each stage
        var stageAnalyses: [StageAnalysis] = []
        let groupedByStage = Dictionary(grouping: allScores) { $0.stageCode }

        for (stageCode, scores) in groupedByStage {
            guard let analysis = analyzeStage(stageCode: stageCode, scores: scores) else {
                continue
            }
            stageAnalyses.append(analysis)
        }

        stageAnalyses.sort { $0.stageCode < $1.stageCode }

        // Calculate strategic insights
        let topStrengths = identifyStrengths(from: stageAnalyses)
        let topWeaknesses = identifyWeaknesses(from: stageAnalyses)
        let volatileStages = identifyVolatileStages(from: stageAnalyses)

        // Overall metrics
        let overallConsistency = calculateOverallConsistency(from: stageAnalyses)
        let recentTrend = calculateRecentTrend(from: allScores)

        // Temporal analysis
        let temporalAnalysis = calculateTemporalAnalysis(from: allScores)

        // Count unique matches
        let uniqueMatches = Set(allScores.map { "\($0.matchName)-\($0.scoreDate)" })

        // Calculate classification metrics
        let (currentTime, classificationStagesCount) = calculateCurrentTime(from: allScores)
        let improvedStagesCount = calculateImprovedStages(from: allScores)

        return CoachingAnalysis(
            memberNumber: memberNumber,
            divisionCode: divisionCode,
            matchCount: uniqueMatches.count,
            totalMatchesAnalyzed: allScores.count,
            currentClassification: currentClassification,
            currentPercentage: currentPercentage,
            currentTime: currentTime,
            improvedStagesCount: improvedStagesCount,
            classificationStagesCount: classificationStagesCount,
            stageAnalyses: stageAnalyses,
            topStrengths: topStrengths,
            topWeaknesses: topWeaknesses,
            volatileStages: volatileStages,
            overallConsistency: overallConsistency,
            recentPerformanceDirection: recentTrend,
            temporalAnalysis: temporalAnalysis
        )
    }

    // MARK: - Private Analysis Methods

    private func analyzeStage(stageCode: String, scores: [SCMatchScore]) -> StageAnalysis? {
        guard !scores.isEmpty else { return nil }

        // CRITICAL: Ensure scores are sorted by date (ascending) since Dictionary grouping doesn't preserve order
        let scores = scores.sorted { $0.scoreDate < $1.scoreDate }

        let stageName = scores.first?.stageName ?? stageCode

        // Filter for recent scores: last N days OR minimum M matches (whichever gives more data)
        let lookbackDate = Calendar.current.date(byAdding: .day, value: -AnalysisConstants.recentDaysWindow, to: Date()) ?? Date()
        let recentScores = scores.filter { $0.scoreDate >= lookbackDate }

        let scoresToUse = AnalysisConstants.getRecentScores(recentScores: recentScores, allScores: scores)

        #if DEBUG
        if scoresToUse.count != scores.count {
            print("  📊 \(stageCode): Using \(scoresToUse.count) of \(scores.count) scores (last \(AnalysisConstants.recentDaysWindow) days or \(AnalysisConstants.recentMatchesThreshold) matches)")
        }
        #endif

        let times = scoresToUse.map { $0.time }
        let allTimes = scores.map { $0.time } // Keep all times for best time calculation

        // Basic statistics (use recent data for average, all data for best)
        let averageTime = times.reduce(Decimal(0), +) / Decimal(times.count)
        let bestTime = allTimes.min() ?? 0  // Best time from ALL history
        let peakTime = scores.first?.peakTime ?? 0

        // Performance vs peak
        let performanceVsPeak = peakTime > 0 ? (peakTime / averageTime) * 100 : 0
        let bestPerformanceVsPeak = peakTime > 0 ? (peakTime / bestTime) * 100 : 0

        // Consistency: Average % difference from average % across recent scores
        // This measures how much your scores vary (lower = more consistent)
        let consistencyScore: Decimal
        if peakTime > 0 && performanceVsPeak > 0 {
            // Calculate each score's performance %
            let scorePerformances = scoresToUse.map { score -> Double in
                NSDecimalNumber(decimal: (peakTime / score.time) * 100).doubleValue
            }

            // Calculate variability around the average
            let avgPerformance = NSDecimalNumber(decimal: performanceVsPeak).doubleValue
            let differences = scorePerformances.map { abs($0 - avgPerformance) }
            let avgDifference = differences.reduce(0.0, +) / Double(differences.count)
            consistencyScore = Decimal(avgDifference)
        } else {
            consistencyScore = 0
        }

        // Also calculate standard deviation for internal use if needed
        let variance = times.map { pow(NSDecimalNumber(decimal: $0 - averageTime).doubleValue, 2) }
            .reduce(0.0, +) / Double(times.count)
        let stdDev = Decimal(sqrt(variance))

        // Recent trend (use filtered scores for trend calculation)
        let recentTrend = calculateStageTrend(scores: scoresToUse)

        // Classification levels
        let bestClassification = ShooterClass.shooterClass(percentage: bestPerformanceVsPeak)
        let averageClassification = ShooterClass.shooterClass(percentage: performanceVsPeak)

        // Calculate improvement potential (based on best time)
        let nextClassification = bestClassification.nextClass
        let nextThreshold = bestClassification.nextClassThreshold

        // Calculate time needed to reach next classification level
        // Formula: targetTime = peakTime / (nextThreshold / 100)
        let timeToNextLevel: Decimal
        if peakTime > 0 && nextThreshold > 0 {
            timeToNextLevel = peakTime / (nextThreshold / 100)
        } else {
            timeToNextLevel = 0
        }

        // Calculate gain: how many seconds to improve from current best
        let gainToNextLevel = bestTime - timeToNextLevel

        // Temporal data
        let sortedByDate = scores.sorted { $0.scoreDate < $1.scoreDate }
        let mostRecent = sortedByDate.last?.scoreDate
        let oldest = sortedByDate.first?.scoreDate

        return StageAnalysis(
            stageCode: stageCode,
            stageName: stageName,
            matchCount: scores.count,  // Total matches (all history)
            averageTime: averageTime,  // Average from recent data
            bestTime: bestTime,  // Best from all history
            standardDeviation: stdDev,  // Variance from recent data
            peakTime: peakTime,
            consistencyScore: consistencyScore,  // Consistency from recent data
            performanceVsPeak: performanceVsPeak,  // Based on recent average
            recentTrend: recentTrend,  // Trend from recent data
            bestClassification: bestClassification,
            averageClassification: averageClassification,
            bestPerformanceVsPeak: bestPerformanceVsPeak,
            nextClassification: nextClassification,
            timeToNextLevel: timeToNextLevel,
            gainToNextLevel: gainToNextLevel,
            mostRecentDate: mostRecent,
            oldestDate: oldest
        )
    }

    private func calculateStageTrend(scores: [SCMatchScore]) -> Decimal {
        guard scores.count >= AnalysisConstants.TrendCalculation.minimumScoresForTrend else { return 0 }

        let sortedScores = scores.sorted { $0.scoreDate < $1.scoreDate }
        let halfPoint = sortedScores.count / 2

        let firstHalf = sortedScores.prefix(halfPoint)
        let secondHalf = sortedScores.suffix(halfPoint)

        let firstAvg = firstHalf.map { $0.time }.reduce(Decimal(0), +) / Decimal(firstHalf.count)
        let secondAvg = secondHalf.map { $0.time }.reduce(Decimal(0), +) / Decimal(secondHalf.count)

        // Positive trend = getting faster (improvement)
        let improvement = firstAvg - secondAvg
        let percentChange = firstAvg > 0 ? (improvement / firstAvg) * 100 : 0

        return percentChange
    }

    private func identifyStrengths(from analyses: [StageAnalysis]) -> [StageAnalysis] {
        // Strengths = highest BEST performance vs peak
        return analyses
            .sorted { $0.bestPerformanceVsPeak > $1.bestPerformanceVsPeak }
            .prefix(3)
            .map { $0 }
    }

    private func identifyWeaknesses(from analyses: [StageAnalysis]) -> [StageAnalysis] {
        // Weaknesses = lowest BEST performance vs peak
        return analyses
            .sorted { $0.bestPerformanceVsPeak < $1.bestPerformanceVsPeak }
            .prefix(3)
            .map { $0 }
    }

    private func identifyVolatileStages(from analyses: [StageAnalysis]) -> [StageAnalysis] {
        // Volatile = highest consistency score (coefficient of variation)
        return analyses
            .filter { $0.matchCount >= AnalysisConstants.PerformanceThresholds.volatileStageMinMatches }
            .sorted { $0.consistencyScore > $1.consistencyScore }
            .prefix(3)
            .map { $0 }
    }

    private func calculateOverallConsistency(from analyses: [StageAnalysis]) -> Decimal {
        guard !analyses.isEmpty else { return 0 }

        // Overall consistency = average of each stage's consistency
        // Each stage consistency is already calculated from recent scores (90 days or 10 matches)
        // So this gives us: average consistency across all stages that have been shot recently
        let totalConsistency = analyses.map { $0.consistencyScore }.reduce(Decimal(0), +)
        return totalConsistency / Decimal(analyses.count)
    }

    private func calculateRecentTrend(from scores: [SCMatchScore]) -> CoachingAnalysis.TrendDirection {
        guard scores.count >= AnalysisConstants.TrendCalculation.minimumScoresForDirection else { return .stable }

        let sortedScores = scores.sorted { $0.scoreDate < $1.scoreDate }
        let recentCount = min(AnalysisConstants.TrendCalculation.recentFractionDivisor, sortedScores.count / AnalysisConstants.TrendCalculation.recentFractionDivisor)

        let recent = sortedScores.suffix(recentCount)
        let earlier = sortedScores.dropLast(recentCount).suffix(recentCount)

        guard !recent.isEmpty && !earlier.isEmpty else { return .stable }

        let recentAvg = recent.map { $0.time }.reduce(Decimal(0), +) / Decimal(recent.count)
        let earlierAvg = earlier.map { $0.time }.reduce(Decimal(0), +) / Decimal(earlier.count)

        let improvement = earlierAvg - recentAvg
        let percentChange = earlierAvg > 0 ? (improvement / earlierAvg) * 100 : 0
        let percentChangeDouble = NSDecimalNumber(decimal: percentChange).doubleValue

        let stableThreshold = AnalysisConstants.PerformanceThresholds.stableTrendThreshold

        // Consider significant if beyond stable threshold
        if percentChangeDouble > stableThreshold {
            return .improving
        } else if percentChangeDouble < -stableThreshold {
            return .declining
        } else {
            return .stable
        }
    }

    // MARK: - Temporal Analysis Methods

    private func calculateTemporalAnalysis(from scores: [SCMatchScore]) -> TemporalAnalysis {
        guard !scores.isEmpty else {
            return TemporalAnalysis(
                daysSinceLastMatch: 0,
                trainingFrequency: .insufficient,
                averageGapDays: 0,
                hasRecentGap: false
            )
        }

        let sortedScores = scores.sorted { $0.scoreDate < $1.scoreDate }

        // Days since last match
        let mostRecent = sortedScores.last!
        let daysSince = Int(Date().timeIntervalSince(mostRecent.scoreDate) / (24 * 60 * 60))

        // Training frequency
        let (frequency, avgGap) = calculateTrainingFrequency(scores: sortedScores)

        // Gap detection
        let hasGap = daysSince > AnalysisConstants.TemporalThresholds.significantGapDays

        return TemporalAnalysis(
            daysSinceLastMatch: daysSince,
            trainingFrequency: frequency,
            averageGapDays: avgGap,
            hasRecentGap: hasGap
        )
    }

    private func calculateCurrentTime(from scores: [SCMatchScore]) -> (Decimal?, Int) {
        // Filter for classification scores (should be one per stage)
        let classificationScores = scores.filter { $0.usedForClassification }

        guard !classificationScores.isEmpty else {
            return (nil, 0)
        }

        // Sum all classification stage times (this is the total classification time)
        let totalTime = classificationScores.map { $0.time }.reduce(Decimal(0), +)

        return (totalTime, classificationScores.count)
    }

    private func calculateImprovedStages(from scores: [SCMatchScore]) -> Int {
        // Get scores from last N days that were used for classification
        let lookbackDate = Calendar.current.date(byAdding: .day, value: -AnalysisConstants.TemporalThresholds.improvedStagesLookbackDays, to: Date()) ?? Date()
        let recentClassificationScores = scores.filter {
            $0.usedForClassification && $0.scoreDate >= lookbackDate
        }

        // Group by stage to count unique improved stages
        let stageGroups = Dictionary(grouping: recentClassificationScores) { $0.stageCode }

        var improvedStages = Set<String>()

        for (stageCode, stageScores) in stageGroups {
            // Sort by date to get chronological order
            let sortedScores = stageScores.sorted { $0.scoreDate < $1.scoreDate }

            // Check if there are at least 2 scores to compare
            guard sortedScores.count >= 2 else { continue }

            // Compare most recent with previous - if time decreased (got faster), it's an improvement
            let mostRecent = sortedScores.last!
            let previous = sortedScores[sortedScores.count - 2]

            if mostRecent.time < previous.time {
                improvedStages.insert(stageCode)
            }
        }

        return improvedStages.count
    }

    private func calculateTrainingFrequency(scores: [SCMatchScore]) -> (TemporalAnalysis.TrainingCadence, Double) {
        guard scores.count >= 2 else {
            return (.insufficient, 0)
        }

        // Calculate gaps between consecutive matches
        let gaps = zip(scores, scores.dropFirst()).map {
            $1.scoreDate.timeIntervalSince($0.scoreDate) / (24 * 60 * 60)
        }

        let avgGap = gaps.reduce(0.0, +) / Double(gaps.count)

        let cadence: TemporalAnalysis.TrainingCadence
        switch avgGap {
        case 0..<AnalysisConstants.TemporalThresholds.veryFrequentMaxDays:
            cadence = .veryFrequent    // Weekly or more
        case AnalysisConstants.TemporalThresholds.veryFrequentMaxDays..<AnalysisConstants.TemporalThresholds.regularMaxDays:
            cadence = .regular         // Bi-weekly to monthly
        case AnalysisConstants.TemporalThresholds.regularMaxDays..<AnalysisConstants.TemporalThresholds.occasionalMaxDays:
            cadence = .occasional      // Every 1-3 months
        default:
            cadence = .infrequent      // Sporadic (3+ months)
        }

        return (cadence, avgGap)
    }

    enum AnalysisError: Error, LocalizedError {
        case noData
        case insufficientData

        var errorDescription: String? {
            switch self {
            case .noData:
                return "No match data available for analysis"
            case .insufficientData:
                return "Insufficient match data for meaningful analysis"
            }
        }
    }
}
