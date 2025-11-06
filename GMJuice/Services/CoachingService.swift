//
//  CoachingService.swift
//  GMJuice
//
//  Created by Claude on 11/4/25.
//

import Foundation
import CryptoKit

// MARK: - Coaching Service

/// Service for generating AI-powered coaching cards using Claude API
class CoachingService {
    static let shared = CoachingService()

    private let apiKey: String?
    private let apiURL = "https://api.anthropic.com/v1/messages"
    private let modelName = "claude-3-5-haiku-20241022"  // Claude 3.5 Haiku for cost efficiency

    private init() {
        // Try to load API key from environment or plist
        self.apiKey = Self.loadAPIKey()
    }

    // MARK: - Public API

    /// Generate coaching cards for a performance analysis
    func generateCoaching(for analysis: CoachingAnalysis) async throws -> CoachingCards {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw CoachingError.noAPIKey
        }

        // Build the prompt
        let prompt = buildPrompt(from: analysis)

        // Call Claude API
        let response = try await callClaudeAPI(prompt: prompt, apiKey: apiKey)

        // Parse the JSON response
        let cards = try parseResponse(response, analysis: analysis)

        return cards
    }

    // MARK: - Private Methods

    private static func loadAPIKey() -> String? {
        // First try environment variable
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            return envKey
        }

        // Then try Info.plist
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let key = dict["ANTHROPIC_API_KEY"] as? String {
            return key
        }

        return nil
    }

    private func buildPrompt(from analysis: CoachingAnalysis) -> String {
        let divisionStrategy = getDivisionStrategy(analysis.divisionCode)

        var prompt = """
        You are an expert SCSA (Steel Challenge Shooting Association) coach. Generate coaching cards based on this performance data.

        SHOOTER PROFILE:
        Division: \(analysis.divisionCode)
        Current Classification: \(analysis.currentClassification.rawValue)
        """

        if let currentPct = analysis.currentPercentage {
            let pctValue = NSDecimalNumber(decimal: currentPct).doubleValue
            prompt += "\nCurrent Percentage: \(String(format: "%.2f", pctValue))%"
        }

        prompt += "\nMatches Analyzed: \(analysis.matchCount)"
        prompt += "\nRecent Trend: \(analysis.recentPerformanceDirection)"

        // Temporal context
        let temporal = analysis.temporalAnalysis
        prompt += "\n\nTEMPORAL CONTEXT:"
        prompt += "\n- Days Since Last Match: \(temporal.daysSinceLastMatch)"
        prompt += "\n- Training Frequency: \(temporal.trainingFrequency.rawValue) (avg \(String(format: "%.0f", temporal.averageGapDays)) days between matches)"

        if temporal.hasRecentGap {
            prompt += "\n- ⚠️ TRAINING GAP: \(temporal.daysSinceLastMatch) days since last match (possible rustiness)"
        }

        prompt += "\n\nDIVISION STRATEGY: \(divisionStrategy)"

        // Stage performance breakdown
        prompt += "\n\nSTAGE PERFORMANCE ANALYSIS:"
        for stage in analysis.stageAnalyses {
            let avgTime = NSDecimalNumber(decimal: stage.averageTime).doubleValue
            let bestTime = NSDecimalNumber(decimal: stage.bestTime).doubleValue
            let peakTime = NSDecimalNumber(decimal: stage.peakTime).doubleValue
            let performance = NSDecimalNumber(decimal: stage.performanceVsPeak).doubleValue
            let consistency = NSDecimalNumber(decimal: stage.consistencyScore).doubleValue
            let trend = NSDecimalNumber(decimal: stage.recentTrend).doubleValue

            prompt += """
            \n\(stage.stageCode) - \(stage.stageName):
              - Matches: \(stage.matchCount)
              - Average: \(String(format: "%.2f", avgTime))s (vs Peak: \(String(format: "%.2f", peakTime))s)
              - Best: \(String(format: "%.2f", bestTime))s (\(stage.bestClassification.rawValue) level)
              - Performance: \(String(format: "%.1f", performance))% (\(stage.averageClassification.rawValue) average)
              - Consistency: ±\(String(format: "%.1f", consistency))%
              - Recent Trend: \(String(format: "%+.1f", trend))%
            """
        }

        // Strategic insights
        prompt += "\n\nTOP STRENGTHS (Best Performing):"
        for stage in analysis.topStrengths {
            let performance = NSDecimalNumber(decimal: stage.performanceVsPeak).doubleValue
            prompt += "\n- \(stage.stageCode) (\(stage.stageName)) - \(String(format: "%.1f", performance))%"
        }

        prompt += "\n\nTOP WEAKNESSES (Needs Improvement):"
        for stage in analysis.topWeaknesses {
            let performance = NSDecimalNumber(decimal: stage.performanceVsPeak).doubleValue
            let deficit = 100.0 - performance
            prompt += "\n- \(stage.stageCode) (\(stage.stageName)) - \(String(format: "%.1f", deficit))% below peak"
        }

        prompt += "\n\nVOLATILE STAGES (Inconsistent):"
        for stage in analysis.volatileStages {
            let consistency = NSDecimalNumber(decimal: stage.consistencyScore).doubleValue
            prompt += "\n- \(stage.stageCode) (\(stage.stageName)) - ±\(String(format: "%.1f", consistency))% variance"
        }

        // Request specific JSON format
        prompt += """


        Generate TWO data-driven coaching cards in JSON format with this EXACT structure:

        {
          "matchCard": {
            "matchTheme": "Strategic focus for the match (e.g., 'Consistency over speed', 'Capitalize on your strengths', 'Don't crash on weak stages', 'Be steady and execute')",
            "bankerStages": [
              {
                "stageCode": "SC-101",
                "stageName": "5 To Go",
                "performance": "85% of peak",
                "reasoning": "Why this is a banker (e.g., 'Most consistent stage', 'Strong performance', 'Improving trend')"
              }
              // 3-4 banker stages - stages with strong/consistent performance to rely on
            ],
            "executeStages": [
              {
                "stageCode": "SC-103",
                "stageName": "Showdown",
                "performance": "74% of peak",
                "note": "Simple note (e.g., 'Execute normally', 'Solid middle', 'Just do your thing')"
              }
              // 1-2 execute stages - middle performance, no special strategy needed
            ],
            "riskStages": [
              {
                "stageCode": "SC-104",
                "stageName": "Outer Limits",
                "performance": "68% of peak",
                "caution": "What to watch (e.g., 'High variance - stay focused', 'Weakest stage - play safe', 'Recent decline - rebuild confidence')"
              }
              // 2-3 risk stages - stages requiring extra focus/caution
            ],
            "matchStrategy": "2-3 sentence compact match plan focusing on how to maximize performance (e.g., Bank on your 4 strong stages, don't crash on the weak ones, focus on consistency)"
          },
          "practiceCard": {
            "weeklyTheme": "Data-driven focus for practice",
            "highPriority": [
              {
                "stageCode": "SC-104",
                "stageName": "Outer Limits",
                "currentPerformance": "63.2% of peak",
                "potentialGain": "2.8 seconds improvement possible",
                "reasoning": "Statistical reasoning why this stage offers best ROI"
              }
              // 3-4 stages for 60% of practice time - biggest opportunities
            ],
            "mediumPriority": [
              {
                "stageCode": "SC-105",
                "stageName": "Accelerator",
                "currentPerformance": "72.1% of peak",
                "potentialGain": "1.2 seconds improvement possible",
                "reasoning": "Statistical reasoning for secondary focus"
              }
              // 2-3 stages for 30% of practice time - moderate gains
            ],
            "maintenance": [
              {
                "stageCode": "SC-107",
                "stageName": "Speed Option",
                "currentPerformance": "85.9% of peak",
                "potentialGain": "Already strong",
                "reasoning": "Statistical reasoning to maintain (e.g., 'Preserve confidence builder')"
              }
              // 1-2 stages for 10% of practice time - maintain strengths
            ],
            "practiceStrategy": "2-3 sentence overall practice strategy based on ROI analysis and temporal context"
          }
        }

        CRITICAL GUIDELINES:
        1. Match Card - ALL 8 STAGES MUST BE COVERED:
           - IMPORTANT: bankerStages + executeStages + riskStages MUST include all 8 stages
           - Count stages carefully: 3-4 banker + 1-2 execute + 2-3 risk = 8 total
           - matchTheme: One clear strategic focus (consistency, capitalize on strengths, etc.)
           - bankerStages: 3-4 stages with strong/consistent performance to bank on
           - executeStages: 1-2 stages with middle performance, just execute normally
           - riskStages: 2-3 stages requiring extra caution (high variance, weak, declining)
           - matchStrategy: Simple, actionable plan for match day
           - Keep it COMPACT - this is a quick-reference card for competition
           - NO generic tips - only data-driven strategy

        2. Practice Card - ALL 8 STAGES MUST BE COVERED:
           - IMPORTANT: highPriority + mediumPriority + maintenance MUST include all 8 stages
           - Count stages carefully: 3-4 high + 2-3 medium + 1-2 maintenance = 8 total
           - NO stage should be left out
           - Focus on WHICH stages to practice and WHY based on ROI
           - NO specific drills or techniques
           - Consider: performance gap, variance, trend, classification impact

        3. Temporal Context Integration:
           - If recent gap (60+ days): Flag consistency issues, recommend focus on solid execution
           - If infrequent training: Prioritize highest ROI stages
           - If frequent training: Can distribute practice more evenly
           - If below historical form: Theme = rebuild consistency
           - If above historical form: Theme = capitalize on momentum

        4. Statistical Language:
           - Use percentages, variances, trends from the data
           - Quantify improvements (seconds, classification impact)
           - Calculate ROI (time invested vs potential gain)

        Return ONLY the JSON object, no additional text.
        """

        return prompt
    }

    private func getDivisionStrategy(_ divisionCode: String) -> String {
        let speedDivisions = ["RFPO", "RFPI", "CO", "OPN", "PCCO"]
        let ironSightDivisions = ["PROD", "SS", "ISR", "PCCI"]
        let revolverDivisions = ["OSR", "ISR"]

        if speedDivisions.contains(divisionCode) {
            return "Speed divisions - Speed is king, accept 95% accuracy. Focus on aggressive transitions and explosive first shots."
        } else if revolverDivisions.contains(divisionCode) {
            return "Revolver - No makeup shots available. First shot quality is critical. Smooth trigger control and precise sight picture."
        } else if ironSightDivisions.contains(divisionCode) {
            return "Iron sights - Balance speed and accuracy. Sight picture discipline matters. Build rhythm and consistency."
        } else {
            return "Focus on consistency and executing your plan. Play to your strengths."
        }
    }

    private func callClaudeAPI(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: apiURL) else {
            throw CoachingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody: [String: Any] = [
            "model": modelName,
            "max_tokens": 2048,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoachingError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Claude API error: \(httpResponse.statusCode) - \(errorMessage)")
            throw CoachingError.apiError(httpResponse.statusCode, errorMessage)
        }

        // Parse Claude API response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw CoachingError.invalidResponse
        }

        return text
    }

    private func parseResponse(_ response: String, analysis: CoachingAnalysis) throws -> CoachingCards {
        print("📥 Raw Claude Response:")
        print(response)
        print(String(repeating: "=", count: 80))

        // Extract JSON from response (Claude might wrap it in markdown code blocks)
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            print("❌ Failed to convert extracted JSON to data")
            throw CoachingError.parsingFailed
        }

        let decoder = JSONDecoder()
        do {
            let apiResponse = try decoder.decode(APIResponse.self, from: data)
            print("✅ Successfully decoded coaching cards")
            return createCoachingCards(from: apiResponse, analysis: analysis)
        } catch {
            print("❌ JSON Decoding Error: \(error)")
            if let decodingError = error as? DecodingError {
                printDecodingError(decodingError)
            }
            throw CoachingError.parsingFailed
        }
    }

    private func extractJSON(from response: String) -> String {
        // Remove markdown code blocks if present
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for ```json ... ``` wrapper
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }

        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to find JSON object boundaries
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            let jsonRange = startIndex...endIndex
            return String(cleaned[jsonRange])
        }

        return cleaned
    }

    private func printDecodingError(_ error: DecodingError) {
        switch error {
        case .keyNotFound(let key, let context):
            print("   Missing key: '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        case .typeMismatch(let type, let context):
            print("   Type mismatch for type: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            print("   Expected: \(type)")
        case .valueNotFound(let type, let context):
            print("   Value not found for type: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        case .dataCorrupted(let context):
            print("   Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            print("   Debug: \(context.debugDescription)")
        @unknown default:
            print("   Unknown decoding error: \(error)")
        }
    }

    private func createCoachingCards(from apiResponse: APIResponse, analysis: CoachingAnalysis) -> CoachingCards {
        let performanceHash = calculatePerformanceHash(from: analysis)
        let currentPct = analysis.currentPercentage.map { NSDecimalNumber(decimal: $0).doubleValue }

        return CoachingCards(
            divisionCode: analysis.divisionCode,
            memberNumber: analysis.memberNumber,
            generatedDate: Date(),
            expirationDate: nextThursday(from: Date()),
            matchCard: apiResponse.matchCard,
            practiceCard: apiResponse.practiceCard,
            analysisSummary: CoachingCards.AnalysisSummary(
                matchCount: analysis.matchCount,
                currentClassification: analysis.currentClassification.rawValue,
                currentPercentage: currentPct,
                performanceHash: performanceHash
            )
        )
    }

    /// Calculate the next Thursday from a given date
    /// If today is Thursday, returns next Thursday (7 days later)
    private func nextThursday(from date: Date) -> Date {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)

        // In Gregorian calendar: 1=Sunday, 2=Monday, ..., 5=Thursday
        // Days until next Thursday (if today is Thursday, go to next week)
        var daysUntilThursday = (5 - currentWeekday + 7) % 7
        if daysUntilThursday == 0 {
            daysUntilThursday = 7  // If today is Thursday, expire next Thursday
        }

        return calendar.date(byAdding: .day, value: daysUntilThursday, to: date) ?? date
    }

    // Moved from below - helper struct for API response
    private struct APIResponse: Codable {
        let matchCard: MatchCard
        let practiceCard: PracticeCard
    }

    /// Generate a hash of the performance data to detect significant changes
    func calculatePerformanceHash(from analysis: CoachingAnalysis) -> String {
        var hashString = "\(analysis.divisionCode)-\(analysis.matchCount)-\(analysis.currentClassification.rawValue)"

        for stage in analysis.stageAnalyses {
            let perf = NSDecimalNumber(decimal: stage.performanceVsPeak).doubleValue
            hashString += "-\(stage.stageCode):\(String(format: "%.1f", perf))"
        }

        let data = Data(hashString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    enum CoachingError: Error, LocalizedError {
        case noAPIKey
        case invalidURL
        case invalidResponse
        case apiError(Int, String)
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "Anthropic API key not configured. Please add ANTHROPIC_API_KEY to your environment or Info.plist."
            case .invalidURL:
                return "Invalid API URL"
            case .invalidResponse:
                return "Invalid response from Claude API"
            case .apiError(let code, let message):
                return "Claude API error (\(code)): \(message)"
            case .parsingFailed:
                return "Failed to parse coaching response"
            }
        }
    }
}
