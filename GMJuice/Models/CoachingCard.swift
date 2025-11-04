//
//  CoachingCard.swift
//  GMJuice
//
//  Created by Claude on 11/4/25.
//

import Foundation

// MARK: - Coaching Card Models

/// Match Card - Quick reference for match day
struct MatchCard: Codable, Hashable {
    // Core match theme
    let matchTheme: String                   // Strategic focus for the match (e.g., "Consistency over speed", "Capitalize on strengths")

    // Banker stages - stages to rely on for solid performance
    let bankerStages: [BankerStage]          // 3-4 stages with strong/consistent performance

    // Execute stages - middle performance, just execute normally
    let executeStages: [ExecuteStage]        // 1-2 stages that are average, no special strategy needed

    // Risk stages - stages requiring extra focus/caution
    let riskStages: [RiskStage]              // 2-3 stages with high variance or weaker performance

    // Overall approach for match day
    let matchStrategy: String                // 2-3 sentence match plan

    // Custom decoding for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        matchTheme = try container.decode(String.self, forKey: .matchTheme)
        bankerStages = try container.decode([BankerStage].self, forKey: .bankerStages)
        // Provide default empty array if executeStages is missing (backward compatibility)
        executeStages = (try? container.decode([ExecuteStage].self, forKey: .executeStages)) ?? []
        riskStages = try container.decode([RiskStage].self, forKey: .riskStages)
        matchStrategy = try container.decode(String.self, forKey: .matchStrategy)
    }

    struct BankerStage: Codable, Hashable {
        let stageCode: String
        let stageName: String
        let performance: String              // e.g., "85% of peak"
        let reasoning: String                // Why this is a banker (consistent, strong, improving)
    }

    struct ExecuteStage: Codable, Hashable {
        let stageCode: String
        let stageName: String
        let performance: String              // e.g., "75% of peak"
        let note: String                     // Simple note (e.g., "Execute normally", "Solid middle")
    }

    struct RiskStage: Codable, Hashable {
        let stageCode: String
        let stageName: String
        let performance: String              // e.g., "68% of peak"
        let caution: String                  // What to watch for (high variance, declining, weak spot)
    }
}

/// Practice Card - Weekly training guidance
struct PracticeCard: Codable, Hashable {
    // Training theme
    let weeklyTheme: String                  // Overall focus area

    // Training priorities with ROI analysis
    let highPriority: [PracticeStage]        // 60% of time - Best ROI
    let mediumPriority: [PracticeStage]      // 30% of time - Secondary gains
    let maintenance: [PracticeStage]         // 10% of time - Preserve strengths

    // Overall practice approach
    let practiceStrategy: String             // Data-driven practice strategy

    struct PracticeStage: Codable, Hashable {
        let stageCode: String
        let stageName: String
        let currentPerformance: String       // e.g., "63.2% of peak"
        let potentialGain: String            // e.g., "2.8s improvement possible"
        let reasoning: String                // Why to focus on this stage
    }
}

/// Combined coaching cards for a division
struct CoachingCards: Codable {
    let divisionCode: String
    let memberNumber: String
    let generatedDate: Date
    let expirationDate: Date                 // Next Thursday from generation

    let matchCard: MatchCard
    let practiceCard: PracticeCard

    // Analysis summary used to generate cards
    let analysisSummary: AnalysisSummary

    struct AnalysisSummary: Codable {
        let matchCount: Int
        let currentClassification: String
        let currentPercentage: Double?
        let performanceHash: String          // Hash of analysis data for change detection
    }

    /// Check if cards are still valid (not expired)
    var isValid: Bool {
        Date() < expirationDate
    }

    /// Check if analysis has changed significantly
    func needsRegeneration(newHash: String) -> Bool {
        analysisSummary.performanceHash != newHash || !isValid
    }
}
