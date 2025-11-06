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
    let consistencyScore: Decimal  // Coefficient of variation (lower is better)
    let performanceVsPeak: Decimal // Percentage
    let recentTrend: Decimal       // Positive = improving, negative = declining

    // Classification context
    let bestClassification: ShooterClass
    let averageClassification: ShooterClass

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

        let stageName = scores.first?.stageName ?? stageCode
        let times = scores.map { $0.time }

        // Basic statistics
        let averageTime = times.reduce(Decimal(0), +) / Decimal(times.count)
        let bestTime = times.min() ?? 0
        let peakTime = scores.first?.peakTime ?? 0

        // Standard deviation
        let variance = times.map { pow(NSDecimalNumber(decimal: $0 - averageTime).doubleValue, 2) }
            .reduce(0.0, +) / Double(times.count)
        let stdDev = Decimal(sqrt(variance))

        // Coefficient of variation (consistency score)
        let consistencyScore = averageTime > 0 ? (stdDev / averageTime) * 100 : 0

        // Performance vs peak
        let performanceVsPeak = peakTime > 0 ? (peakTime / averageTime) * 100 : 0
        let bestPerformanceVsPeak = peakTime > 0 ? (peakTime / bestTime) * 100 : 0

        // Recent trend (compare last 3 vs first 3)
        let recentTrend = calculateStageTrend(scores: scores)

        // Classification levels
        let bestClassification = ShooterClass.shooterClass(percentage: bestPerformanceVsPeak)
        let averageClassification = ShooterClass.shooterClass(percentage: performanceVsPeak)

        // Temporal data
        let sortedByDate = scores.sorted { $0.scoreDate < $1.scoreDate }
        let mostRecent = sortedByDate.last?.scoreDate
        let oldest = sortedByDate.first?.scoreDate

        return StageAnalysis(
            stageCode: stageCode,
            stageName: stageName,
            matchCount: scores.count,
            averageTime: averageTime,
            bestTime: bestTime,
            standardDeviation: stdDev,
            peakTime: peakTime,
            consistencyScore: consistencyScore,
            performanceVsPeak: performanceVsPeak,
            recentTrend: recentTrend,
            bestClassification: bestClassification,
            averageClassification: averageClassification,
            mostRecentDate: mostRecent,
            oldestDate: oldest
        )
    }

    private func calculateStageTrend(scores: [SCMatchScore]) -> Decimal {
        guard scores.count >= 4 else { return 0 }

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
        // Strengths = highest performance vs peak
        return analyses
            .sorted { $0.performanceVsPeak > $1.performanceVsPeak }
            .prefix(3)
            .map { $0 }
    }

    private func identifyWeaknesses(from analyses: [StageAnalysis]) -> [StageAnalysis] {
        // Weaknesses = lowest performance vs peak
        return analyses
            .sorted { $0.performanceVsPeak < $1.performanceVsPeak }
            .prefix(3)
            .map { $0 }
    }

    private func identifyVolatileStages(from analyses: [StageAnalysis]) -> [StageAnalysis] {
        // Volatile = highest consistency score (coefficient of variation)
        return analyses
            .filter { $0.matchCount >= 3 } // Need at least 3 matches
            .sorted { $0.consistencyScore > $1.consistencyScore }
            .prefix(3)
            .map { $0 }
    }

    private func calculateOverallConsistency(from analyses: [StageAnalysis]) -> Decimal {
        guard !analyses.isEmpty else { return 0 }

        let totalConsistency = analyses.map { $0.consistencyScore }.reduce(Decimal(0), +)
        return totalConsistency / Decimal(analyses.count)
    }

    private func calculateRecentTrend(from scores: [SCMatchScore]) -> CoachingAnalysis.TrendDirection {
        guard scores.count >= 6 else { return .stable }

        let sortedScores = scores.sorted { $0.scoreDate < $1.scoreDate }
        let recentCount = min(3, sortedScores.count / 3)

        let recent = sortedScores.suffix(recentCount)
        let earlier = sortedScores.dropLast(recentCount).suffix(recentCount)

        guard !recent.isEmpty && !earlier.isEmpty else { return .stable }

        let recentAvg = recent.map { $0.time }.reduce(Decimal(0), +) / Decimal(recent.count)
        let earlierAvg = earlier.map { $0.time }.reduce(Decimal(0), +) / Decimal(earlier.count)

        let improvement = earlierAvg - recentAvg
        let percentChange = earlierAvg > 0 ? (improvement / earlierAvg) * 100 : 0

        // Consider significant if > 2% change
        if percentChange > 2 {
            return .improving
        } else if percentChange < -2 {
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

        // Gap detection (60+ days = significant gap)
        let hasGap = daysSince > 60

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
        // Get scores from last 30 days that were used for classification
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentClassificationScores = scores.filter {
            $0.usedForClassification && $0.scoreDate >= thirtyDaysAgo
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
        case 0..<14:
            cadence = .veryFrequent    // Weekly or more
        case 14..<45:
            cadence = .regular         // Bi-weekly to monthly
        case 45..<90:
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
