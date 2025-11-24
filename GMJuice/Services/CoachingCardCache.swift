//
//  CoachingCardCache.swift
//  GMJuice
//
//  Created by Claude on 11/4/25.
//

import Foundation
import SwiftData

// MARK: - Coaching Card Cache

/// Result containing both coaching cards and the analysis used to generate them
struct CoachingResult {
    let cards: CoachingCards
    let analysis: CoachingAnalysis
}

/// Manages caching of coaching cards with 7-day expiration
@MainActor
class CoachingCardCache {
    static let shared = CoachingCardCache()

    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let versionKey = "CoachingCardCache_AppVersion"
    private let lastDataUpdateKey = "CoachingCardCache_LastDataUpdate"

    private init() {
        // Use app's cache directory
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = caches.appendingPathComponent("CoachingCards", isDirectory: true)

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Check app version and clear cache if version changed
        checkAndClearCacheOnVersionChange()
    }

    /// Check if app version changed and clear cache if so
    private func checkAndClearCacheOnVersionChange() {
        let currentVersion = getCurrentAppVersion()
        let storedVersion = UserDefaults.standard.string(forKey: versionKey)

        #if DEBUG
        // In debug builds, always clear cache to ensure fresh data during development
        print("🔧 DEBUG: Clearing coaching card cache on every launch")
        clearAllCaches()
        UserDefaults.standard.set(currentVersion, forKey: versionKey)
        #else
        // In release builds, only clear cache when build number changes
        if storedVersion != currentVersion {
            print("📦 Build number changed from \(storedVersion ?? "nil") to \(currentVersion). Clearing coaching card cache.")
            clearAllCaches()
            UserDefaults.standard.set(currentVersion, forKey: versionKey)
        }
        #endif
    }

    /// Get current build number (increments with every build/update)
    private func getCurrentAppVersion() -> String {
        // Use only build number - this increments with every TestFlight/App Store build
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        return build
    }

    /// Check if today is Wednesday (match data update day)
    private func isWednesday() -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        return weekday == 4 // 1 = Sunday, 2 = Monday, ..., 4 = Wednesday
    }

    /// Check if we received new data today (performance hash changed)
    private func receivedNewDataToday() -> Bool {
        guard let lastUpdate = UserDefaults.standard.object(forKey: lastDataUpdateKey) as? Date else {
            return false
        }
        let calendar = Calendar.current
        return calendar.isDateInToday(lastUpdate)
    }

    /// Record that new data was received (performance hash changed)
    private func recordDataUpdate() {
        UserDefaults.standard.set(Date(), forKey: lastDataUpdateKey)
        print("📊 Recorded new data update at \(Date())")
    }

    /// Get expiration date based on current day and data update status
    private func getExpirationDate() -> Date {
        if isWednesday() && !receivedNewDataToday() {
            // On Wednesday before new data arrives: expire every hour
            let expiration = Date().addingTimeInterval(60 * 60) // 1 hour
            print("📅 Wednesday hourly refresh: cache expires at \(expiration)")
            return expiration
        } else {
            // Normal operation: 24 hour expiration
            return Date().addingTimeInterval(24 * 60 * 60)
        }
    }

    // MARK: - Public API

    /// Get cached coaching cards or generate new ones, along with performance analysis
    func getCoachingCards(
        memberNumber: String,
        divisionCode: String,
        context: ModelContext,
        forceRefresh: Bool = false
    ) async throws -> CoachingResult {
        let cacheKey = "\(memberNumber)-\(divisionCode)"

        // Analyze performance (always needed for analysis tab)
        print("📊 Analyzing performance...")
        let analyzer = SCPerformanceAnalyzer(
            memberNumber: memberNumber,
            divisionCode: divisionCode,
            context: context
        )
        let analysis = try analyzer.analyzePerformance()

        // Try to load from cache first
        if !forceRefresh, let cached = loadFromCache(key: cacheKey) {
            // Check if still valid (based on expiration logic)
            if cached.isValid {
                let currentHash = CoachingService.shared.calculatePerformanceHash(from: analysis)
                if !cached.needsRegeneration(newHash: currentHash) {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    print("✅ Using cached coaching cards (expires: \(formatter.string(from: cached.expirationDate)))")
                    return CoachingResult(cards: cached, analysis: analysis)
                } else {
                    print("📈 Performance changed significantly (new data detected), regenerating cards...")
                    // Record that we received new data (hash changed)
                    recordDataUpdate()
                }
            } else {
                print("📅 Cache expired - regenerating coaching cards...")
            }
        }

        // Generate new cards
        print("🤖 Generating coaching cards...")

        // Build practice card in Swift with AI-generated reasoning
        let practiceCard = await buildPracticeCard(from: analysis)

        // Build match card in Swift with AI-generated reasoning
        let matchCard = await buildMatchCard(from: analysis)

        // Combine cards
        let performanceHash = CoachingService.shared.calculatePerformanceHash(from: analysis)
        let currentPct = analysis.currentPercentage.map { NSDecimalNumber(decimal: $0).doubleValue }

        let cards = CoachingCards(
            divisionCode: divisionCode,
            memberNumber: memberNumber,
            generatedDate: Date(),
            expirationDate: getExpirationDate(), // Wednesday: hourly until new data, otherwise: 24 hours
            matchCard: matchCard,
            practiceCard: practiceCard,
            analysisSummary: CoachingCards.AnalysisSummary(
                matchCount: analysis.matchCount,
                currentClassification: analysis.currentClassification.rawValue,
                currentPercentage: currentPct,
                performanceHash: performanceHash
            ),
            aiEnabled: RemoteConfigService.shared.isClaudeAIEnabled
        )

        // Save to cache
        saveToCache(cards: cards, key: cacheKey)

        return CoachingResult(cards: cards, analysis: analysis)
    }

    /// Clear cached cards for a specific member/division
    func clearCache(memberNumber: String, divisionCode: String) {
        let cacheKey = "\(memberNumber)-\(divisionCode)"
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).json")

        try? fileManager.removeItem(at: fileURL)
        print("🗑️ Cleared cache for \(cacheKey)")
    }

    /// Clear all cached coaching cards
    func clearAllCaches() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        print("🗑️ Cleared all coaching card caches")
    }

    /// Check if valid cached cards exist
    func hasCachedCards(memberNumber: String, divisionCode: String) -> Bool {
        let cacheKey = "\(memberNumber)-\(divisionCode)"
        guard let cached = loadFromCache(key: cacheKey) else {
            return false
        }
        return cached.isValid
    }

    // MARK: - Private Methods

    /// Build practice card using Swift logic with AI-generated reasoning
    private func buildPracticeCard(from analysis: CoachingAnalysis) async -> PracticeCard {
        let currentLevel = analysis.currentClassification

        // Analyze each stage with multiple factors
        struct StageWithFactors {
            let stage: StageAnalysis
            let bestPerf: Double
            let avgPerf: Double
            let perfGap: Double
            let trend: Double
            let consistency: Double
            let isBelowLevel: Bool
            let isHighVariance: Bool
            let isDeclining: Bool
        }

        let stagesWithFactors = analysis.stageAnalyses.map { stage -> StageWithFactors in
            let bestPerf = NSDecimalNumber(decimal: stage.bestPerformanceVsPeak).doubleValue
            let avgPerf = NSDecimalNumber(decimal: stage.performanceVsPeak).doubleValue
            let perfGap = bestPerf - avgPerf
            let trend = NSDecimalNumber(decimal: stage.recentTrend).doubleValue
            let consistency = NSDecimalNumber(decimal: stage.consistencyScore).doubleValue

            return StageWithFactors(
                stage: stage,
                bestPerf: bestPerf,
                avgPerf: avgPerf,
                perfGap: perfGap,
                trend: trend,
                consistency: consistency,
                isBelowLevel: stage.bestClassification < currentLevel,
                isHighVariance: consistency > AnalysisConstants.PracticePriority.highVarianceThreshold,
                isDeclining: trend < AnalysisConstants.PerformanceThresholds.decliningTrendThreshold
            )
        }

        #if DEBUG
        print("\n🎯 BUILDING PRACTICE CARD WITH ENHANCED ANALYSIS:")
        print("Current Level: \(currentLevel.rawValue)")
        print("\nStage Analysis:")
        for sf in stagesWithFactors.sorted(by: { $0.bestPerf < $1.bestPerf }) {
            print("  \(sf.stage.stageCode): \(String(format: "%.1f", sf.bestPerf))% (avg: \(String(format: "%.1f", sf.avgPerf))%)")
            print("    Gap: \(String(format: "%.1f", sf.perfGap))% | Trend: \(String(format: "%+.1f", sf.trend))% | Variance: ±\(String(format: "%.1f", sf.consistency))%")
            if sf.isBelowLevel { print("    ⚠️ BELOW LEVEL") }
            if sf.isDeclining { print("    📉 DECLINING") }
            if sf.isHighVariance { print("    ⚡ HIGH VARIANCE") }
        }
        #endif

        var highPriority: [StageWithFactors] = []
        var mediumPriority: [StageWithFactors] = []
        var maintenance: [StageWithFactors] = []

        // Calculate weighted priority score for each stage
        // Lower score = higher priority (needs more practice)
        struct ScoredStage {
            let stageWithFactors: StageWithFactors
            let priorityScore: Double
        }

        let scoredStages = stagesWithFactors.map { sf -> ScoredStage in
            var score: Double = 0

            // Base score: Lower % = higher priority (inverted, so lower % gives lower score)
            // Range: 0-100 (lower is higher priority)
            score += sf.bestPerf

            // Below current level: HIGHEST priority - growing potential
            // This is the most important factor - stages below your level have the most room to grow
            if sf.isBelowLevel {
                let levelThreshold = NSDecimalNumber(decimal: currentLevel.percentThreshold).doubleValue
                let gapFromLevel = levelThreshold - sf.bestPerf
                let belowLevelPenalty = AnalysisConstants.PracticePriority.belowLevelBasePenalty +
                                        (gapFromLevel * AnalysisConstants.PracticePriority.belowLevelGapMultiplier)
                score -= belowLevelPenalty
            }

            // Declining performance: based on trend severity
            // Less weight than below-level, but still important
            if sf.isDeclining {
                let trendPenalty = min(
                    AnalysisConstants.PracticePriority.decliningMaxPenalty,
                    abs(sf.trend) * AnalysisConstants.PracticePriority.decliningTrendMultiplier
                )
                score -= trendPenalty
            }

            // High variance: based on consistency
            if sf.isHighVariance {
                let variancePenalty = min(
                    AnalysisConstants.PracticePriority.highVarianceMaxPenalty,
                    (sf.consistency - AnalysisConstants.PracticePriority.highVarianceBaseline) / AnalysisConstants.PracticePriority.highVarianceDivisor
                )
                score -= variancePenalty
            }

            // Large best-avg gap
            if sf.perfGap > AnalysisConstants.PracticePriority.bestAvgGapThreshold {
                let gapPenalty = min(
                    AnalysisConstants.PracticePriority.bestAvgGapMaxPenalty,
                    (sf.perfGap - AnalysisConstants.PracticePriority.bestAvgGapThreshold) / AnalysisConstants.PracticePriority.bestAvgGapDivisor
                )
                score -= gapPenalty
            }

            return ScoredStage(stageWithFactors: sf, priorityScore: score)
        }

        // Sort by priority score (lowest score = highest priority)
        let sortedByPriority = scoredStages.sorted { $0.priorityScore < $1.priorityScore }

        #if DEBUG
        print("\n🎯 WEIGHTED PRIORITY SCORES (lower = higher priority):")
        for scored in sortedByPriority {
            let sf = scored.stageWithFactors
            print("  \(sf.stage.stageCode): \(String(format: "%.1f", scored.priorityScore)) points (\(String(format: "%.1f", sf.bestPerf))% base, \(sf.isBelowLevel ? "below level" : ""), \(sf.isDeclining ? "declining" : ""), \(sf.isHighVariance ? "high variance" : ""))")
        }
        #endif

        // Assign to buckets based on sorted priority
        for (index, scored) in sortedByPriority.enumerated() {
            if index < AnalysisConstants.PracticePriority.highPriorityCount {
                highPriority.append(scored.stageWithFactors)
            }
        }

        // Maintenance: At least N highest scoring stages (best performance, stable)
        // Take from the END of the sorted list (highest scores = best performers)
        let maintenanceCount = max(
            AnalysisConstants.PracticePriority.maintenanceMinCount,
            stagesWithFactors.count - AnalysisConstants.PracticePriority.highPriorityCount - 2
        )
        for scored in sortedByPriority.reversed().prefix(maintenanceCount) {
            maintenance.append(scored.stageWithFactors)
        }

        // Medium: Everything else (middle of the pack)
        for scored in sortedByPriority {
            let sf = scored.stageWithFactors
            if !highPriority.contains(where: { $0.stage.stageCode == sf.stage.stageCode }) &&
               !maintenance.contains(where: { $0.stage.stageCode == sf.stage.stageCode }) {
                mediumPriority.append(sf)
            }
        }

        #if DEBUG
        print("\nPRIORITY DISTRIBUTION:")
        print("  HIGH (\(highPriority.count)): \(highPriority.map { $0.stage.stageCode }.joined(separator: ", "))")
        print("  MEDIUM (\(mediumPriority.count)): \(mediumPriority.map { $0.stage.stageCode }.joined(separator: ", "))")
        print("  MAINTENANCE (\(maintenance.count)): \(maintenance.map { $0.stage.stageCode }.joined(separator: ", "))")
        print("  TOTAL: \(highPriority.count + mediumPriority.count + maintenance.count)")
        #endif

        // Generate AI reasoning, theme, and strategy if enabled
        let aiContent: PracticeAIContent
        if RemoteConfigService.shared.isClaudeAIEnabled {
            print("🤖 Generating AI reasoning for practice recommendations...")
            aiContent = await generatePracticeContent(
                highPriority: highPriority,
                mediumPriority: mediumPriority,
                maintenance: maintenance,
                currentLevel: currentLevel,
                decliningCount: stagesWithFactors.filter({ $0.isDeclining }).count,
                highVarianceCount: stagesWithFactors.filter({ $0.isHighVariance }).count,
                belowLevelCount: stagesWithFactors.filter({ $0.isBelowLevel }).count
            )
        } else {
            print("🚫 Claude AI disabled - using fallback practice content")
            aiContent = PracticeAIContent(
                weeklyTheme: "Data-driven practice focus",
                practiceStrategy: "Allocate 60% practice to high priority stages, 30% to medium priority stages, and 10% to maintenance stages.",
                generationExplanation: "Priorities calculated using performance data analysis. High priority stages show the best improvement opportunities.",
                stageReasoning: [:]
            )
        }

        // Build practice stages with AI reasoning (or fallback reasoning)
        let highStages = highPriority.map { sf in
            let reason = aiContent.stageReasoning[sf.stage.stageCode] ?? generateFallbackPracticeReason(sf, priority: "high")
            return createPracticeStage(from: sf.stage, reason: reason)
        }
        let mediumStages = mediumPriority.map { sf in
            let reason = aiContent.stageReasoning[sf.stage.stageCode] ?? generateFallbackPracticeReason(sf, priority: "medium")
            return createPracticeStage(from: sf.stage, reason: reason)
        }
        let maintenanceStages = maintenance.map { sf in
            let reason = aiContent.stageReasoning[sf.stage.stageCode] ?? generateFallbackPracticeReason(sf, priority: "maintenance")
            return createPracticeStage(from: sf.stage, reason: reason)
        }

        return PracticeCard(
            weeklyTheme: aiContent.weeklyTheme,
            highPriority: highStages,
            mediumPriority: mediumStages,
            maintenance: maintenanceStages,
            practiceStrategy: aiContent.practiceStrategy,
            generationExplanation: aiContent.generationExplanation
        )
    }

    /// Build match card using Swift logic with AI-generated reasoning
    private func buildMatchCard(from analysis: CoachingAnalysis) async -> MatchCard {
        // Analyze each stage for match day - use recent average performance % directly
        struct StageReliability {
            let stage: StageAnalysis
            let recentAvgPerf: Double  // Recent average % of peak (basis for categorization)
            let trend: Double
            let consistency: Double
        }

        let reliabilityAnalysis = analysis.stageAnalyses.map { stage -> StageReliability in
            // Use performanceVsPeak which is already based on recent data (90 days or 10 matches)
            let recentAvgPerf = NSDecimalNumber(decimal: stage.performanceVsPeak).doubleValue
            let trend = NSDecimalNumber(decimal: stage.recentTrend).doubleValue
            let consistency = NSDecimalNumber(decimal: stage.consistencyScore).doubleValue

            return StageReliability(
                stage: stage,
                recentAvgPerf: recentAvgPerf,
                trend: trend,
                consistency: consistency
            )
        }

        // Sort by recent average performance % (highest to lowest)
        // Simple approach: if you've been doing well recently, bank on it
        let sortedByRecentPerformance = reliabilityAnalysis.sorted { $0.recentAvgPerf > $1.recentAvgPerf }

        #if DEBUG
        print("\n🏆 BUILDING MATCH CARD - RECENT PERFORMANCE ANALYSIS:")
        print("(Sorted by recent average %, highest to lowest)\n")
        for rel in sortedByRecentPerformance {
            print("  \(rel.stage.stageCode): \(String(format: "%.1f", rel.recentAvgPerf))%")
            print("    Consistency: ±\(String(format: "%.1f", rel.consistency))% | Trend: \(String(format: "%+.1f", rel.trend))%")
        }
        #endif

        // Categorize stages using simple distribution:
        // Top 3 = Banker (you've been doing well, bank on these)
        // Middle 2 = Execute (solid middle, just execute normally)
        // Bottom 3 = Risk (lower recent %, be cautious)
        var bankerStages: [StageReliability] = []
        var executeStages: [StageReliability] = []
        var riskStages: [StageReliability] = []

        // Top 3: Banker stages
        bankerStages = Array(sortedByRecentPerformance.prefix(3))

        // Bottom 3: Risk stages
        riskStages = Array(sortedByRecentPerformance.suffix(3))

        // Middle 2: Execute stages
        for rel in sortedByRecentPerformance {
            if !bankerStages.contains(where: { $0.stage.stageCode == rel.stage.stageCode }) &&
               !riskStages.contains(where: { $0.stage.stageCode == rel.stage.stageCode }) {
                executeStages.append(rel)
            }
        }

        #if DEBUG
        print("\nMATCH DAY CATEGORIZATION (by recent avg %):")
        print("  BANKER (\(bankerStages.count)): \(bankerStages.map { "\($0.stage.stageCode) \(String(format: "%.1f", $0.recentAvgPerf))%" }.joined(separator: ", "))")
        print("  EXECUTE (\(executeStages.count)): \(executeStages.map { "\($0.stage.stageCode) \(String(format: "%.1f", $0.recentAvgPerf))%" }.joined(separator: ", "))")
        print("  RISK (\(riskStages.count)): \(riskStages.map { "\($0.stage.stageCode) \(String(format: "%.1f", $0.recentAvgPerf))%" }.joined(separator: ", "))")
        print("  TOTAL: \(bankerStages.count + executeStages.count + riskStages.count)")
        #endif

        // Generate AI reasoning and strategy if enabled
        let aiContent: MatchAIContent
        if RemoteConfigService.shared.isClaudeAIEnabled {
            print("🤖 Generating AI reasoning for match strategy...")
            aiContent = await generateMatchContent(
                bankerStages: bankerStages,
                executeStages: executeStages,
                riskStages: riskStages,
                currentLevel: analysis.currentClassification
            )
        } else {
            print("🚫 Claude AI disabled - using fallback match content")
            aiContent = MatchAIContent(
                matchTheme: "Execute consistently and play to your strengths",
                matchStrategy: "Bank points on your strongest stages, stay solid on middle stages, and avoid mistakes on weaker stages.",
                generationExplanation: "Stages categorized by recent performance data. Analysis shows which stages to rely on vs. be cautious with.",
                stageReasoning: [:]
            )
        }

        // Build match stages with AI reasoning (or fallback reasoning)
        let bankers = bankerStages.map { rel in
            let reason = aiContent.stageReasoning[rel.stage.stageCode] ?? generateFallbackMatchReason(rel, category: "banker")
            return createBankerStage(from: rel.stage, reason: reason)
        }
        let executes = executeStages.map { rel in
            let note = aiContent.stageReasoning[rel.stage.stageCode] ?? generateFallbackMatchReason(rel, category: "execute")
            return createExecuteStage(from: rel.stage, note: note)
        }
        let risks = riskStages.map { rel in
            let caution = aiContent.stageReasoning[rel.stage.stageCode] ?? generateFallbackMatchReason(rel, category: "risk")
            return createRiskStage(from: rel.stage, caution: caution)
        }

        return MatchCard(
            matchTheme: aiContent.matchTheme,
            bankerStages: bankers,
            executeStages: executes,
            riskStages: risks,
            matchStrategy: aiContent.matchStrategy,
            generationExplanation: aiContent.generationExplanation
        )
    }

    private func createBankerStage(from stage: StageAnalysis, reason: String) -> MatchCard.BankerStage {
        let recentAvg = NSDecimalNumber(decimal: stage.performanceVsPeak).doubleValue
        let bestPerf = NSDecimalNumber(decimal: stage.bestPerformanceVsPeak).doubleValue
        return MatchCard.BankerStage(
            stageCode: stage.stageCode,
            stageName: stage.stageName,
            performance: String(format: "Recent: %.1f%% | Best: %.1f%%", recentAvg, bestPerf),
            reasoning: reason
        )
    }

    private func createExecuteStage(from stage: StageAnalysis, note: String) -> MatchCard.ExecuteStage {
        let recentAvg = NSDecimalNumber(decimal: stage.performanceVsPeak).doubleValue
        let bestPerf = NSDecimalNumber(decimal: stage.bestPerformanceVsPeak).doubleValue
        return MatchCard.ExecuteStage(
            stageCode: stage.stageCode,
            stageName: stage.stageName,
            performance: String(format: "Recent: %.1f%% | Best: %.1f%%", recentAvg, bestPerf),
            note: note
        )
    }

    private func createRiskStage(from stage: StageAnalysis, caution: String) -> MatchCard.RiskStage {
        let recentAvg = NSDecimalNumber(decimal: stage.performanceVsPeak).doubleValue
        let bestPerf = NSDecimalNumber(decimal: stage.bestPerformanceVsPeak).doubleValue
        return MatchCard.RiskStage(
            stageCode: stage.stageCode,
            stageName: stage.stageName,
            performance: String(format: "Recent: %.1f%% | Best: %.1f%%", recentAvg, bestPerf),
            caution: caution
        )
    }

    private struct MatchAIContent: Codable {
        let matchTheme: String
        let matchStrategy: String
        let generationExplanation: String
        let stageReasoning: [String: String]
    }

    private func generateMatchContent(
        bankerStages: [Any],
        executeStages: [Any],
        riskStages: [Any],
        currentLevel: ShooterClass
    ) async -> MatchAIContent {
        // Extract stage data using reflection
        func extractStageData(_ item: Any) -> (code: String, stage: StageAnalysis, recentAvgPerf: Double, trend: Double, consistency: Double)? {
            let mirror = Mirror(reflecting: item)
            guard let stageValue = mirror.children.first(where: { $0.label == "stage" })?.value as? StageAnalysis,
                  let recentAvgPerf = mirror.children.first(where: { $0.label == "recentAvgPerf" })?.value as? Double,
                  let trend = mirror.children.first(where: { $0.label == "trend" })?.value as? Double,
                  let consistency = mirror.children.first(where: { $0.label == "consistency" })?.value as? Double else {
                return nil
            }
            return (stageValue.stageCode, stageValue, recentAvgPerf, trend, consistency)
        }

        // Build prompt for AI
        var prompt = """
        Generate match day strategy based on this analysis. Current Classification: \(currentLevel.rawValue)

        MATCH DAY STRATEGY:
        - BANKER STAGES: Stages to rely on for solid, stable performance
        - EXECUTE STAGES: Average performance, just run normally
        - RISK STAGES: Stages to be cautious with, avoid mistakes

        BANKER STAGES (Rely on these for points):
        """

        for item in bankerStages {
            if let data = extractStageData(item) {
                prompt += """
                \n\(data.code) - \(data.stage.stageName):
                  - Recent Avg: \(String(format: "%.1f", data.recentAvgPerf))%
                  - Consistency: ±\(String(format: "%.1f", data.consistency))%
                  - Trend: \(String(format: "%+.1f", data.trend))%
                """
            }
        }

        prompt += "\n\nEXECUTE STAGES (Just run your normal game):"
        for item in executeStages {
            if let data = extractStageData(item) {
                prompt += """
                \n\(data.code) - \(data.stage.stageName):
                  - Recent Avg: \(String(format: "%.1f", data.recentAvgPerf))%
                  - Consistency: ±\(String(format: "%.1f", data.consistency))%
                  - Trend: \(String(format: "%+.1f", data.trend))%
                """
            }
        }

        prompt += "\n\nRISK STAGES (Be cautious, don't crash):"
        for item in riskStages {
            if let data = extractStageData(item) {
                prompt += """
                \n\(data.code) - \(data.stage.stageName):
                  - Recent Avg: \(String(format: "%.1f", data.recentAvgPerf))%
                  - Consistency: ±\(String(format: "%.1f", data.consistency))%
                  - Trend: \(String(format: "%+.1f", data.trend))%
                """
            }
        }

        prompt += """


        Generate a JSON response with:
        {
          "matchTheme": "One clear strategic focus for match day (e.g., 'Execute consistently', 'Capitalize on strengths')",
          "matchStrategy": "2-3 sentence match plan focusing on stability and execution",
          "generationExplanation": "Brief explanation of how stages were categorized (e.g., 'Stages sorted by recent average performance. Top 3 are your bankers, middle 2 to execute, bottom 3 require caution.')",
          "stageReasoning": {
            "SC-XXX": "Brief reasoning for each stage (why banker/execute/risk)"
          }
        }

        GUIDELINES:
        - matchTheme: One clear focus, not generic
        - matchStrategy: Specific to this shooter's data, focused on maximizing match score
        - generationExplanation: 1-2 sentences explaining the categorization logic used
        - stageReasoning: 1-2 sentences per stage explaining the categorization
        - Keep it COMPACT - this is for quick reference during match

        Return ONLY the JSON object.
        """

        // Call AI (if available and enabled)
        guard ClaudeAPIClient.shared.isConfigured && RemoteConfigService.shared.isClaudeAIEnabled else {
            let reason = ClaudeAPIClient.shared.isConfigured ? "Claude AI disabled" : "No API key"
            print("⚠️ \(reason), using defaults for match content")
            return MatchAIContent(
                matchTheme: "Execute consistently and play to your strengths",
                matchStrategy: "Focus on executing consistently across all stages. Bank points on your strongest stages, stay solid on middle stages, and avoid mistakes on weaker stages.",
                generationExplanation: "Stages ranked by recent average performance (last \(AnalysisConstants.recentDaysWindow) days or \(AnalysisConstants.recentMatchesThreshold) matches). Top 3 are banker stages, middle 2 for execution, bottom 3 require caution.",
                stageReasoning: [:]
            )
        }

        do {
            let response = try await CoachingService.shared.callClaudeAPI(prompt: prompt)
            let jsonString = CoachingService.shared.extractJSON(from: response)

            guard let data = jsonString.data(using: .utf8) else {
                throw NSError(domain: "MatchCardAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON to data"])
            }

            let decoded = try JSONDecoder().decode(MatchAIContent.self, from: data)
            print("✅ Match AI content generated successfully")
            return decoded

        } catch {
            print("⚠️ Failed to generate match AI content: \(error)")
            return MatchAIContent(
                matchTheme: "Execute consistently and play to your strengths",
                matchStrategy: "Focus on executing consistently across all stages. Bank points on your strongest stages, stay solid on middle stages, and avoid mistakes on weaker stages.",
                generationExplanation: "Stages ranked by recent average performance (last \(AnalysisConstants.recentDaysWindow) days or \(AnalysisConstants.recentMatchesThreshold) matches). Top 3 are banker stages, middle 2 for execution, bottom 3 require caution.",
                stageReasoning: [:]
            )
        }
    }

    private func createPracticeStage(from stage: StageAnalysis, reason: String) -> PracticeCard.PracticeStage {
        let bestPerf = NSDecimalNumber(decimal: stage.bestPerformanceVsPeak).doubleValue
        let gain = NSDecimalNumber(decimal: stage.gainToNextLevel).doubleValue
        let nextClass = stage.nextClassification.rawValue

        let gainText: String
        if stage.nextClassification == .GM && stage.bestClassification == .GM {
            gainText = String(format: "%.2f seconds to peak", abs(gain))
        } else {
            gainText = String(format: "%.2f seconds to reach %@", abs(gain), nextClass)
        }

        return PracticeCard.PracticeStage(
            stageCode: stage.stageCode,
            stageName: stage.stageName,
            currentPerformance: String(format: "%.1f%% of peak", bestPerf),
            potentialGain: gainText,
            reasoning: reason
        )
    }

    private func buildPracticeStrategy(currentLevel: ShooterClass, highPriorityCount: Int, belowLevelCount: Int) -> String {
        if belowLevelCount > 0 {
            return "Prioritize stages below your \(currentLevel.rawValue) level. Focus 60% of practice time on high priority stages to bring them up to your current classification level."
        } else {
            return "Allocate 60% of practice to high priority stages with lowest percentages. These offer the best ROI for improvement. Maintain strong stages with 10% practice time."
        }
    }

    private struct PracticeAIContent {
        let weeklyTheme: String
        let practiceStrategy: String
        let generationExplanation: String
        let stageReasoning: [String: String]
    }

    private func generatePracticeContent(
        highPriority: [Any],
        mediumPriority: [Any],
        maintenance: [Any],
        currentLevel: ShooterClass,
        decliningCount: Int,
        highVarianceCount: Int,
        belowLevelCount: Int
    ) async -> PracticeAIContent {
        // Extract stage data
        func extractStageData(_ item: Any) -> (code: String, stage: StageAnalysis, bestPerf: Double, avgPerf: Double, gap: Double, trend: Double, consistency: Double)? {
            let mirror = Mirror(reflecting: item)
            guard let stageValue = mirror.children.first(where: { $0.label == "stage" })?.value as? StageAnalysis,
                  let bestPerf = mirror.children.first(where: { $0.label == "bestPerf" })?.value as? Double,
                  let avgPerf = mirror.children.first(where: { $0.label == "avgPerf" })?.value as? Double,
                  let gap = mirror.children.first(where: { $0.label == "perfGap" })?.value as? Double,
                  let trend = mirror.children.first(where: { $0.label == "trend" })?.value as? Double,
                  let consistency = mirror.children.first(where: { $0.label == "consistency" })?.value as? Double else {
                return nil
            }
            return (stageValue.stageCode, stageValue, bestPerf, avgPerf, gap, trend, consistency)
        }

        // Build prompt for AI
        var prompt = """
        Generate practice guidance based on this analysis. Current Classification: \(currentLevel.rawValue)

        CONTEXT:
        - \(belowLevelCount) stages below shooter's level
        - \(decliningCount) declining stages (negative trend)
        - \(highVarianceCount) high variance stages (inconsistent)

        HIGH PRIORITY (60% practice time):
        """

        for item in highPriority {
            if let data = extractStageData(item) {
                prompt += """
                \n- \(data.code): Best \(String(format: "%.1f", data.bestPerf))%, Avg \(String(format: "%.1f", data.avgPerf))%, Gap \(String(format: "%.1f", data.gap))%, Trend \(String(format: "%+.1f", data.trend))%, Variance ±\(String(format: "%.1f", data.consistency))%, Class: \(data.stage.bestClassification.rawValue)
                """
            }
        }

        prompt += "\n\nMEDIUM PRIORITY (30% practice time):"
        for item in mediumPriority {
            if let data = extractStageData(item) {
                prompt += """
                \n- \(data.code): Best \(String(format: "%.1f", data.bestPerf))%, Avg \(String(format: "%.1f", data.avgPerf))%, Gap \(String(format: "%.1f", data.gap))%, Trend \(String(format: "%+.1f", data.trend))%, Variance ±\(String(format: "%.1f", data.consistency))%, Class: \(data.stage.bestClassification.rawValue)
                """
            }
        }

        prompt += "\n\nMAINTENANCE (10% practice time):"
        for item in maintenance {
            if let data = extractStageData(item) {
                prompt += """
                \n- \(data.code): Best \(String(format: "%.1f", data.bestPerf))%, Avg \(String(format: "%.1f", data.avgPerf))%, Gap \(String(format: "%.1f", data.gap))%, Trend \(String(format: "%+.1f", data.trend))%, Variance ±\(String(format: "%.1f", data.consistency))%, Class: \(data.stage.bestClassification.rawValue)
                """
            }
        }

        prompt += """


        Generate the following in JSON format:

        {
          "weeklyTheme": "A concise theme for the week (e.g., 'Rebuild declining stages', 'Push toward GM', 'Consistency focus')",
          "practiceStrategy": "2-3 sentences on the overall approach (60% high, 30% medium, 10% maintenance). Reference specific issues like declining performance, variance, or stages below level.",
          "generationExplanation": "2-3 sentences explaining how priorities were calculated using: best time %, recent trend, variance, and classification level. Mention that Swift calculated priorities and AI generated insights.",
          "stageReasoning": {
            "SC-101": "1-2 sentences explaining why this stage is in its priority bucket (below level, declining, high variance, weak, strong, improving, etc.)",
            "SC-105": "1-2 sentences...",
            ...for each stage...
          }
        }

        Make it concise, data-driven, and actionable. Return ONLY the JSON object.
        """

        #if DEBUG
        print("\n📤 PRACTICE REASONING PROMPT:")
        print(prompt)
        print(String(repeating: "=", count: 80))
        #endif

        // Check if Claude AI is enabled
        guard RemoteConfigService.shared.isClaudeAIEnabled else {
            print("⚠️ Claude AI disabled, using fallback practice content")
            return PracticeAIContent(
                weeklyTheme: "Focus on weak areas and maintain strengths",
                practiceStrategy: "Allocate 60% practice to high priority stages. Work on consistency and building foundational skills.",
                generationExplanation: "Priorities calculated using performance data analysis. High priority stages show the best improvement opportunities.",
                stageReasoning: [:]
            )
        }

        do {
            let response = try await CoachingService.shared.callClaudeAPI(prompt: prompt)

            #if DEBUG
            print("\n📥 Raw Claude Response (Practice Content):")
            print(response)
            print(String(repeating: "=", count: 80))
            #endif

            let jsonString = CoachingService.shared.extractJSON(from: response)

            if let data = jsonString.data(using: String.Encoding.utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                let weeklyTheme = json["weeklyTheme"] as? String ?? "Focus on weak areas and maintain strengths"
                let practiceStrategy = json["practiceStrategy"] as? String ?? "Allocate practice time based on priority levels."
                let generationExplanation = json["generationExplanation"] as? String ?? "Priorities calculated using performance data and AI insights."
                let stageReasoning = json["stageReasoning"] as? [String: String] ?? [:]

                #if DEBUG
                print("✅ Successfully decoded practice content:")
                print("  Weekly Theme: \(weeklyTheme)")
                print("  Strategy: \(practiceStrategy)")
                print("  Explanation: \(generationExplanation)")
                print("  Stage Reasoning Count: \(stageReasoning.count)")
                #endif

                return PracticeAIContent(
                    weeklyTheme: weeklyTheme,
                    practiceStrategy: practiceStrategy,
                    generationExplanation: generationExplanation,
                    stageReasoning: stageReasoning
                )
            } else {
                print("❌ Failed to parse JSON from practice content response")
            }
        } catch {
            print("❌ Failed to generate AI practice content: \(error)")
        }

        // Fallback
        print("⚠️ Using fallback practice content (API call failed or returned invalid JSON)")
        return PracticeAIContent(
            weeklyTheme: "Focus on weak areas and maintain strengths",
            practiceStrategy: "Allocate 60% practice to high priority stages. Work on consistency and building foundational skills.",
            generationExplanation: "Priorities calculated using best time percentages, recent performance trends, variance analysis, and current classification level.",
            stageReasoning: [:]
        )
    }

    private func loadFromCache(key: String) -> CoachingCards? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cards = try decoder.decode(CoachingCards.self, from: data)
            return cards
        } catch {
            print("🔄 Cache format outdated, will regenerate cards...")
            // Remove outdated cache file
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }

    private func saveToCache(cards: CoachingCards, key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(cards)
            try data.write(to: fileURL)
            print("💾 Saved coaching cards to cache")
        } catch {
            print("⚠️ Failed to save cards to cache: \(error)")
        }
    }
    
    // MARK: - Fallback Reasoning Methods
    
    /// Generate fallback reasoning for practice stages when AI is disabled
    private func generateFallbackPracticeReason(_ stageWithFactors: Any, priority: String) -> String {
        // Use reflection to extract data
        let mirror = Mirror(reflecting: stageWithFactors)
        guard let _ = mirror.children.first(where: { $0.label == "stage" })?.value as? StageAnalysis,
              let bestPerf = mirror.children.first(where: { $0.label == "bestPerf" })?.value as? Double,
              let trend = mirror.children.first(where: { $0.label == "trend" })?.value as? Double,
              let consistency = mirror.children.first(where: { $0.label == "consistency" })?.value as? Double else {
            return "Practice needed for improvement"
        }
        
        switch priority {
        case "high":
            if bestPerf < 70 {
                return "Lowest performance - significant improvement opportunity"
            } else if trend < -2 {
                return "Declining performance - needs immediate attention"
            } else if consistency > 8 {
                return "High variance - focus on consistency"
            } else {
                return "Below average performance - prioritize this stage"
            }
        case "medium":
            if consistency > 6 {
                return "Moderate variance - work on consistency"
            } else if trend > 2 {
                return "Improving trend - continue building momentum"
            } else {
                return "Solid foundation - moderate practice needed"
            }
        case "maintenance":
            if bestPerf > 85 {
                return "Strong performer - maintain with light practice"
            } else {
                return "Stable performance - maintain current level"
            }
        default:
            return "Continue working on this stage"
        }
    }
    
    /// Generate fallback reasoning for match stages when AI is disabled
    private func generateFallbackMatchReason(_ stageReliability: Any, category: String) -> String {
        // Use reflection to extract data
        let mirror = Mirror(reflecting: stageReliability)
        guard let _ = mirror.children.first(where: { $0.label == "stage" })?.value as? StageAnalysis,
              let recentAvgPerf = mirror.children.first(where: { $0.label == "recentAvgPerf" })?.value as? Double,
              let trend = mirror.children.first(where: { $0.label == "trend" })?.value as? Double,
              let consistency = mirror.children.first(where: { $0.label == "consistency" })?.value as? Double else {
            return "Execute your normal plan"
        }
        
        switch category {
        case "banker":
            if recentAvgPerf > 85 {
                return "Excellent recent performance - rely on this stage"
            } else if consistency < 5 {
                return "Very consistent - bank on stability"
            } else if trend > 3 {
                return "Strong improving trend - momentum is building"
            } else {
                return "Solid recent performance - dependable stage"
            }
        case "execute":
            if consistency < 6 {
                return "Steady performer - execute normally"
            } else {
                return "Average performance - stick to your plan"
            }
        case "risk":
            if recentAvgPerf < 70 {
                return "Lowest recent performance - be conservative"
            } else if consistency > 8 {
                return "High variance - focus and avoid mistakes"
            } else if trend < -3 {
                return "Recent decline - rebuild confidence"
            } else {
                return "Weaker recent performance - stay cautious"
            }
        default:
            return "Execute your plan"
        }
    }
}

