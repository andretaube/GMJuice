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

    // How this was generated (optional - for transparency)
    let generationExplanation: String?       // Brief explanation of categorization logic

    // Memberwise initializer
    init(matchTheme: String, bankerStages: [BankerStage], executeStages: [ExecuteStage], riskStages: [RiskStage], matchStrategy: String, generationExplanation: String? = nil) {
        self.matchTheme = matchTheme
        self.bankerStages = bankerStages
        self.executeStages = executeStages
        self.riskStages = riskStages
        self.matchStrategy = matchStrategy
        self.generationExplanation = generationExplanation
    }

    // Custom decoding for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        matchTheme = try container.decode(String.self, forKey: .matchTheme)
        bankerStages = try container.decode([BankerStage].self, forKey: .bankerStages)
        // Provide default empty array if executeStages is missing (backward compatibility)
        executeStages = (try? container.decode([ExecuteStage].self, forKey: .executeStages)) ?? []
        riskStages = try container.decode([RiskStage].self, forKey: .riskStages)
        matchStrategy = try container.decode(String.self, forKey: .matchStrategy)
        // Optional field for backward compatibility
        generationExplanation = try? container.decode(String.self, forKey: .generationExplanation)
    }

    struct BankerStage: Codable, Hashable {
        let stageCode: String
        let stageName: String
        let performance: String              // e.g., "Recent: 85.0% | Best: 89.0%"
        let reasoning: String                // Why this is a banker (consistent, strong, improving)
    }

    struct ExecuteStage: Codable, Hashable {
        let stageCode: String
        let stageName: String
        let performance: String              // e.g., "Recent: 75.0% | Best: 78.0%"
        let note: String                     // Simple note (e.g., "Execute normally", "Solid middle")
    }

    struct RiskStage: Codable, Hashable {
        let stageCode: String
        let stageName: String
        let performance: String              // e.g., "Recent: 68.0% | Best: 72.0%"
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

    // How this was generated (optional - for transparency)
    let generationExplanation: String?       // Brief explanation of how priorities were calculated

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
    let expirationDate: Date                 // Wednesday: hourly until new data, otherwise: 24 hours

    let matchCard: MatchCard
    let practiceCard: PracticeCard

    // Analysis summary used to generate cards
    let analysisSummary: AnalysisSummary
    
    // Whether Claude AI was used to generate insights
    let aiEnabled: Bool

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
    
    // Custom decoding for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        divisionCode = try container.decode(String.self, forKey: .divisionCode)
        memberNumber = try container.decode(String.self, forKey: .memberNumber)
        generatedDate = try container.decode(Date.self, forKey: .generatedDate)
        expirationDate = try container.decode(Date.self, forKey: .expirationDate)
        matchCard = try container.decode(MatchCard.self, forKey: .matchCard)
        practiceCard = try container.decode(PracticeCard.self, forKey: .practiceCard)
        analysisSummary = try container.decode(AnalysisSummary.self, forKey: .analysisSummary)
        // Default to true for backward compatibility with existing cached cards
        aiEnabled = (try? container.decode(Bool.self, forKey: .aiEnabled)) ?? true
    }
    
    private enum CodingKeys: String, CodingKey {
        case divisionCode, memberNumber, generatedDate, expirationDate
        case matchCard, practiceCard, analysisSummary, aiEnabled
    }
    
    // Memberwise initializer for compatibility
    init(divisionCode: String, memberNumber: String, generatedDate: Date, expirationDate: Date, 
         matchCard: MatchCard, practiceCard: PracticeCard, analysisSummary: AnalysisSummary, aiEnabled: Bool) {
        self.divisionCode = divisionCode
        self.memberNumber = memberNumber
        self.generatedDate = generatedDate
        self.expirationDate = expirationDate
        self.matchCard = matchCard
        self.practiceCard = practiceCard
        self.analysisSummary = analysisSummary
        self.aiEnabled = aiEnabled
    }
}
