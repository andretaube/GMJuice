//
//  CoachingCardsView.swift
//  GMJuice
//
//  Created by Claude on 11/4/25.
//

import SwiftUI
import SwiftData

struct CoachingCardsView: View {
    let divisionCode: String

    @Environment(\.modelContext) private var context
    @Query private var profiles: [ShooterProfile]

    @State private var coachingCards: CoachingCards?
    @State private var analysisData: CoachingAnalysis?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTab = 0
    @State private var loadingPhase: LoadingPhase = .analyzing
    @State private var matchCount: Int = 0
    @State private var showingMetricsInfo = false

    private var memberNumber: String {
        profiles.first?.uspsaNumber ?? ""
    }

    enum LoadingPhase {
        case analyzing
        case reviewingStages
        case calculatingTrends
        case generatingStrategy
        case finalizingCards

        var message: String {
            switch self {
            case .analyzing:
                return "Analyzing matches..."
            case .reviewingStages:
                return "Reviewing stage performance..."
            case .calculatingTrends:
                return "Calculating trends..."
            case .generatingStrategy:
                return "Generating match strategy..."
            case .finalizingCards:
                return "Finalizing coaching cards..."
            }
        }

        var icon: String {
            switch self {
            case .analyzing:
                return "chart.bar.doc.horizontal"
            case .reviewingStages:
                return "target"
            case .calculatingTrends:
                return "arrow.triangle.2.circlepath"
            case .generatingStrategy:
                return "lightbulb.fill"
            case .finalizingCards:
                return "checkmark.circle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let cards = coachingCards {
                cardsContentView(cards)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Coaching - \(divisionCode)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showingMetricsInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }

                    Button {
                        Task {
                            await loadCoachingCards(forceRefresh: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .sheet(isPresented: $showingMetricsInfo) {
            MetricsInfoView()
        }
        .task {
            await loadCoachingCards()
        }
    }

    // MARK: - Content Views

    private var loadingView: some View {
        VStack(spacing: 24) {
            // Animated thinking brain
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundStyle(.purple)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 12) {
                // Phase icon and message
                HStack(spacing: 12) {
                    Image(systemName: loadingPhase.icon)
                        .font(.title3)
                        .foregroundStyle(.purple)
                        .symbolEffect(.bounce, value: loadingPhase)

                    if loadingPhase == .analyzing && matchCount > 0 {
                        Text("Analyzing \(matchCount) matches...")
                            .font(.headline)
                    } else {
                        Text(loadingPhase.message)
                            .font(.headline)
                    }
                }

                // Progress indicator
                ProgressView()
                    .tint(.purple)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to Generate Coaching", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task {
                    await loadCoachingCards(forceRefresh: true)
                }
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Coaching Available", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Need more match data to generate coaching insights")
        }
    }

    private func cardsContentView(_ cards: CoachingCards) -> some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Card Type", selection: $selectedTab) {
                Text("Match").tag(0)
                Text("Practice").tag(1)
                Text("Analysis").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Card content
            ScrollView {
                if selectedTab == 0 {
                    MatchCardView(card: cards.matchCard)
                        .padding()
                } else if selectedTab == 1 {
                    PracticeCardView(card: cards.practiceCard)
                        .padding()
                } else if selectedTab == 2, let analysis = analysisData {
                    AnalysisTabView(analysis: analysis)
                        .padding()
                }

                // Metadata footer (only show for Match and Practice tabs)
                if selectedTab < 2 {
                    VStack(spacing: 8) {
                        Text("Analyzed on \(cards.generatedDate, format: .dateTime.month().day().year())")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Next review \(cards.expirationDate, format: .dateTime.month().day().year())")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text("Based on \(cards.analysisSummary.matchCount) matches")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadCoachingCards(forceRefresh: Bool = false) async {
        guard !memberNumber.isEmpty else {
            errorMessage = "No USPSA member number configured"
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
            loadingPhase = .analyzing
        }

        do {
            // Phase 1: Count matches
            let descriptor = FetchDescriptor<SCMatchScore>(
                predicate: #Predicate<SCMatchScore> { score in
                    score.memberNumber == memberNumber &&
                    score.divisionCode == divisionCode
                }
            )
            let scores = try context.fetch(descriptor)
            let uniqueMatches = Set(scores.map { "\($0.matchName)-\($0.scoreDate)" })

            await MainActor.run {
                matchCount = uniqueMatches.count
            }

            try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds

            // Phase 2: Reviewing stages
            await MainActor.run {
                loadingPhase = .reviewingStages
            }
            try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds

            // Phase 3: Calculating trends
            await MainActor.run {
                loadingPhase = .calculatingTrends
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Phase 4: Generating strategy (this is the actual API call)
            await MainActor.run {
                loadingPhase = .generatingStrategy
            }

            let result = try await CoachingCardCache.shared.getCoachingCards(
                memberNumber: memberNumber,
                divisionCode: divisionCode,
                context: context,
                forceRefresh: forceRefresh
            )

            // Phase 5: Finalizing
            await MainActor.run {
                loadingPhase = .finalizingCards
            }
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            await MainActor.run {
                self.coachingCards = result.cards
                self.analysisData = result.analysis
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Match Card View

struct MatchCardView: View {
    let card: MatchCard

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Match Theme - Prominent
            VStack(alignment: .leading, spacing: 8) {
                Label("Match Focus", systemImage: "target")
                    .font(.headline)
                    .foregroundStyle(.blue)

                Text(card.matchTheme)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }

            // Banker Stages - Rely on these
            VStack(alignment: .leading, spacing: 12) {
                Label("Bank On These (\(card.bankerStages.count))", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                ForEach(card.bankerStages, id: \.stageCode) { stage in
                    BankerStageRow(stage: stage)
                }
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .cornerRadius(12)

            // Execute Stages - Just execute normally
            if !card.executeStages.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Execute These (\(card.executeStages.count))", systemImage: "arrow.forward.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)

                    ForEach(card.executeStages, id: \.stageCode) { stage in
                        ExecuteStageRow(stage: stage)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }

            // Risk Stages - Extra focus needed
            VStack(alignment: .leading, spacing: 12) {
                Label("Watch These (\(card.riskStages.count))", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)

                ForEach(card.riskStages, id: \.stageCode) { stage in
                    RiskStageRow(stage: stage)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.05))
            .cornerRadius(12)

            // Match Strategy
            VStack(alignment: .leading, spacing: 8) {
                Label("Match Plan", systemImage: "flag.checkered")
                    .font(.headline)
                    .foregroundStyle(.purple)

                Text(card.matchStrategy)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(12)
            }
        }
    }
}

struct BankerStageRow: View {
    let stage: MatchCard.BankerStage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Green check indicator
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(stage.stageCode)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(stage.stageName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(stage.performance)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .fontWeight(.medium)

                Text(stage.reasoning)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExecuteStageRow: View {
    let stage: MatchCard.ExecuteStage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Execute indicator
            Image(systemName: "arrow.forward.circle.fill")
                .foregroundStyle(.blue)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(stage.stageCode)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(stage.stageName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(stage.performance)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .fontWeight(.medium)

                Text(stage.note)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RiskStageRow: View {
    let stage: MatchCard.RiskStage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Warning indicator
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(stage.stageCode)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(stage.stageName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(stage.performance)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fontWeight(.medium)

                Text(stage.caution)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Practice Card View

struct PracticeCardView: View {
    let card: PracticeCard

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Weekly Theme
            VStack(alignment: .leading, spacing: 8) {
                Label("This Week's Focus", systemImage: "calendar")
                    .font(.headline)
                    .foregroundStyle(.blue)

                Text(card.weeklyTheme)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }

            // High Priority - 60%
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("High Priority", systemImage: "flame.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Spacer()
                    Text("60% of practice")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(card.highPriority, id: \.self) { stage in
                    PracticeStageRow(stage: stage, color: .red)
                }
            }
            .padding()
            .background(Color.red.opacity(0.05))
            .cornerRadius(12)

            // Medium Priority - 30%
            if !card.mediumPriority.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Medium Priority", systemImage: "arrow.up.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("30% of practice")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(card.mediumPriority, id: \.self) { stage in
                        PracticeStageRow(stage: stage, color: .orange)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .cornerRadius(12)
            }

            // Maintenance - 10%
            if !card.maintenance.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Maintenance", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Spacer()
                        Text("10% of practice")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(card.maintenance, id: \.self) { stage in
                        PracticeStageRow(stage: stage, color: .green)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.05))
                .cornerRadius(12)
            }

            // Practice Strategy
            VStack(alignment: .leading, spacing: 8) {
                Label("Practice Strategy", systemImage: "target")
                    .font(.headline)
                    .foregroundStyle(.purple)

                Text(card.practiceStrategy)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(12)
            }
        }
    }
}

struct PracticeStageRow: View {
    let stage: PracticeCard.PracticeStage
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stage header
            HStack(spacing: 6) {
                Text(stage.stageCode)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(stage.stageName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Performance metrics
            HStack(spacing: 12) {
                Text(stage.currentPerformance)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(stage.potentialGain)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            // ROI reasoning
            Text(stage.reasoning)
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.top, 2)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Analysis Tab View

struct AnalysisTabView: View {
    let analysis: CoachingAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Key Findings Summary
            KeyFindingsView(analysis: analysis)

            // Overall Stats
            OverallStatsView(analysis: analysis)

            // Stage-by-Stage Performance
            VStack(alignment: .leading, spacing: 12) {
                Label("Stage Performance", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(.purple)

                ForEach(analysis.stageAnalyses, id: \.stageCode) { stage in
                    StagePerformanceCard(stage: stage, userLevel: analysis.currentClassification)
                }
            }
        }
    }
}

// MARK: - Key Indicators

struct KeyFindingsView: View {
    let analysis: CoachingAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Key Indicators", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 8) {
                // Classification status
                findingRow(
                    icon: "person.fill",
                    text: "Current: \(analysis.currentClassification.rawValue) class",
                    color: classificationColor(analysis.currentClassification)
                )

                // Performance trend
                let trendIcon = trendIconName(analysis.recentPerformanceDirection)
                let trendColor = trendColorValue(analysis.recentPerformanceDirection)
                findingRow(
                    icon: trendIcon,
                    text: "Overall trend: \(trendText(analysis.recentPerformanceDirection))",
                    color: trendColor
                )

                // Consistency score
                let consistencyValue = NSDecimalNumber(decimal: analysis.overallConsistency).doubleValue
                let consistencyRating = consistencyRating(consistencyValue)
                findingRow(
                    icon: "waveform.path.ecg",
                    text: "Consistency: \(consistencyRating) (±\(String(format: "%.1f", consistencyValue))%)",
                    color: consistencyColor(consistencyValue)
                )

                // Match frequency (division-specific)
                VStack(alignment: .leading, spacing: 4) {
                    findingRow(
                        icon: "calendar",
                        text: "\(analysis.divisionCode) Matches: \(analysis.temporalAnalysis.trainingFrequency.rawValue)",
                        color: frequencyColor(analysis.temporalAnalysis.trainingFrequency)
                    )

                    // Warning if division hasn't been shot recently
                    let daysSince = analysis.temporalAnalysis.daysSinceLastMatch
                    if daysSince > 90 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text("Haven't shot \(analysis.divisionCode) in \(daysSince) days")
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                        .padding(.leading, 28)
                    }
                }

                // Best stage
                if let topStrength = analysis.topStrengths.first {
                    let perfValue = NSDecimalNumber(decimal: topStrength.performanceVsPeak).doubleValue
                    findingRow(
                        icon: "trophy.fill",
                        text: "Strongest: \(topStrength.stageName) (\(String(format: "%.1f", perfValue))%)",
                        color: .green
                    )
                }

                // Weakest stage
                if let topWeakness = analysis.topWeaknesses.first {
                    let perfValue = NSDecimalNumber(decimal: topWeakness.performanceVsPeak).doubleValue
                    let deficit = 100.0 - perfValue
                    findingRow(
                        icon: "exclamationmark.triangle.fill",
                        text: "Focus on: \(topWeakness.stageName) (\(String(format: "%.1f", deficit))% below peak)",
                        color: .orange
                    )
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
        }
    }

    private func findingRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }

    private func classificationColor(_ classification: ShooterClass) -> Color {
        switch classification {
        case .GM: return .purple
        case .M: return .blue
        case .A: return .green
        case .B: return .orange
        case .C, .D, .U: return .gray
        }
    }

    private func trendIconName(_ direction: CoachingAnalysis.TrendDirection) -> String {
        switch direction {
        case .improving: return "arrow.up.circle.fill"
        case .stable: return "arrow.left.arrow.right.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        }
    }

    private func trendColorValue(_ direction: CoachingAnalysis.TrendDirection) -> Color {
        switch direction {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .red
        }
    }

    private func trendText(_ direction: CoachingAnalysis.TrendDirection) -> String {
        switch direction {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        }
    }

    private func consistencyRating(_ value: Double) -> String {
        switch value {
        case 0..<3: return "Excellent"
        case 3..<5: return "Good"
        case 5..<8: return "Fair"
        default: return "Inconsistent"
        }
    }

    private func consistencyColor(_ value: Double) -> Color {
        switch value {
        case 0..<3: return .green
        case 3..<5: return .blue
        case 5..<8: return .orange
        default: return .red
        }
    }

    private func frequencyColor(_ frequency: TemporalAnalysis.TrainingCadence) -> Color {
        switch frequency {
        case .veryFrequent: return .green
        case .regular: return .blue
        case .occasional: return .orange
        case .infrequent, .insufficient: return .red
        }
    }
}

// MARK: - Overall Stats

struct OverallStatsView: View {
    let analysis: CoachingAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Performance Summary", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(.purple)

            HStack(spacing: 16) {
                statBox(
                    title: "Matches",
                    value: "\(analysis.matchCount)",
                    icon: "flag.fill",
                    color: .blue
                )

                if let currentPct = analysis.currentPercentage {
                    let pctValue = NSDecimalNumber(decimal: currentPct).doubleValue
                    statBox(
                        title: "Current %",
                        value: String(format: "%.1f%%", pctValue),
                        icon: "percent",
                        color: .green
                    )
                }

                let daysSince = analysis.temporalAnalysis.daysSinceLastMatch
                statBox(
                    title: "Last Match",
                    value: "\(daysSince)d",
                    icon: "calendar.badge.clock",
                    color: daysSince > 60 ? .orange : .blue
                )
            }

            // Form comparison
            let currentForm = NSDecimalNumber(decimal: analysis.temporalAnalysis.currentFormAverage).doubleValue
            let historical = NSDecimalNumber(decimal: analysis.temporalAnalysis.historicalAverage).doubleValue
            let formVsHist = NSDecimalNumber(decimal: analysis.temporalAnalysis.formVsHistorical).doubleValue

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current Form")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2fs", currentForm))
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Historical Avg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2fs", historical))
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Form vs Historical")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", formVsHist))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(formVsHist < 95 ? .red : formVsHist > 105 ? .green : .blue)
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)
        }
    }

    private func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Stage Performance Card

struct StagePerformanceCard: View {
    let stage: StageAnalysis
    let userLevel: ShooterClass

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stage header with color-coded progress indicator
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        // Progress indicator dot
                        Circle()
                            .fill(progressColor)
                            .frame(width: 10, height: 10)

                        Text(stage.stageCode)
                            .font(.subheadline)
                            .fontWeight(.bold)

                        Text(stage.stageName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Match count indicator
                    Text("\(stage.matchCount) matches")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Classification badge - shows best performance level achieved
                ClassificationBadge(classification: stage.bestClassification)
            }

            // Performance metrics grid
            HStack(spacing: 12) {
                metricBox(
                    label: "Performance",
                    value: String(format: "%.1f%%", performanceValue),
                    color: performanceColor,
                    icon: "target"
                )

                metricBox(
                    label: "Consistency",
                    value: "±\(String(format: "%.1f%%", consistencyValue))",
                    color: consistencyColor,
                    icon: "waveform"
                )

                metricBox(
                    label: "Trend",
                    value: String(format: "%+.1f%%", trendValue),
                    color: trendColor,
                    icon: trendIcon
                )
            }

            // Performance bar graph
            PerformanceBarGraph(
                current: averageTimeValue,
                best: bestTimeValue,
                peak: peakTimeValue,
                performance: performanceValue
            )

            // Time details
            VStack(alignment: .leading, spacing: 4) {
                timeRow(label: "Best Time", value: String(format: "%.2fs", bestTimeValue), classification: stage.bestClassification)
                timeRow(label: "Average Time", value: String(format: "%.2fs", averageTimeValue), classification: stage.averageClassification)
                timeRow(label: "Peak Time", value: String(format: "%.2fs", peakTimeValue), classification: .GM)
            }
            .font(.caption)
        }
        .padding()
        .background(progressColor.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(progressColor.opacity(0.3), lineWidth: 2)
        )
    }

    // MARK: - Computed Properties

    private var performanceValue: Double {
        NSDecimalNumber(decimal: stage.performanceVsPeak).doubleValue
    }

    private var consistencyValue: Double {
        NSDecimalNumber(decimal: stage.consistencyScore).doubleValue
    }

    private var trendValue: Double {
        NSDecimalNumber(decimal: stage.recentTrend).doubleValue
    }

    private var averageTimeValue: Double {
        NSDecimalNumber(decimal: stage.averageTime).doubleValue
    }

    private var bestTimeValue: Double {
        NSDecimalNumber(decimal: stage.bestTime).doubleValue
    }

    private var peakTimeValue: Double {
        NSDecimalNumber(decimal: stage.peakTime).doubleValue
    }

    // MARK: - Color Logic

    private var progressColor: Color {
        // Prioritize trend over raw performance
        if trendValue > 5 {
            return .green // Strong improvement
        } else if trendValue > 2 {
            return .blue // Moderate improvement
        } else if trendValue < -5 {
            return .red // Declining
        } else if trendValue < -2 {
            return .orange // Slight decline
        } else {
            return performanceColor // Use relative performance color
        }
    }

    private var performanceColor: Color {
        // Color code relative to user's current classification level
        let userThreshold = NSDecimalNumber(decimal: userLevel.percentThreshold).doubleValue
        let nextThreshold = NSDecimalNumber(decimal: userLevel.nextClassThreshold).doubleValue

        // Determine thresholds one class below current
        let belowClass: ShooterClass = {
            switch userLevel {
            case .GM: return .M
            case .M: return .A
            case .A: return .B
            case .B: return .C
            case .C: return .D
            case .D, .U: return .U
            }
        }()
        let belowThreshold = NSDecimalNumber(decimal: belowClass.percentThreshold).doubleValue

        if performanceValue >= nextThreshold {
            return .green // At or above next class level - excellent!
        } else if performanceValue >= userThreshold {
            return .blue // Within current class range - good
        } else if performanceValue >= belowThreshold {
            return .orange // Below current class but not critically - needs work
        } else {
            return .red // More than one class below - critical
        }
    }

    private var consistencyColor: Color {
        switch consistencyValue {
        case 0..<3: return .green
        case 3..<5: return .blue
        case 5..<8: return .orange
        default: return .red
        }
    }

    private var trendColor: Color {
        if trendValue > 2 {
            return .green
        } else if trendValue < -2 {
            return .red
        } else {
            return .blue
        }
    }

    private var trendIcon: String {
        if trendValue > 2 {
            return "arrow.up"
        } else if trendValue < -2 {
            return "arrow.down"
        } else {
            return "minus"
        }
    }

    // MARK: - Helper Views

    private func metricBox(label: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }

    private func timeRow(label: String, value: String, classification: ShooterClass) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
            Text("(\(classification.rawValue))")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Classification Badge

struct ClassificationBadge: View {
    let classification: ShooterClass

    var body: some View {
        Text(classification.rawValue)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .cornerRadius(6)
    }

    private var badgeColor: Color {
        switch classification {
        case .GM: return .purple
        case .M: return .blue
        case .A: return .green
        case .B: return .orange
        case .C: return .yellow
        case .D, .U: return .gray
        }
    }
}

// MARK: - Performance Bar Graph

struct PerformanceBarGraph: View {
    let current: Double
    let best: Double
    let peak: Double
    let performance: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Performance vs Peak")
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background (peak time)
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: geometry.size.width, height: 20)

                    // Best time bar
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: geometry.size.width * CGFloat(best / current), height: 20)

                    // Performance bar (average time relative to peak)
                    Rectangle()
                        .fill(performanceBarColor)
                        .frame(width: geometry.size.width * CGFloat(peak / current), height: 20)

                    // Labels
                    HStack {
                        Text(String(format: "%.2fs", current))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.leading, 4)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0)
                        Spacer()
                        Text(String(format: "%.1f%%", performance))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.trailing, 4)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0)
                    }
                }
            }
            .frame(height: 20)
            .cornerRadius(4)

            // Legend
            HStack(spacing: 12) {
                legendItem(color: performanceBarColor, label: "Your Avg")
                legendItem(color: .green.opacity(0.3), label: "Your Best")
                legendItem(color: .gray.opacity(0.2), label: "GM Peak")
            }
            .font(.caption2)
        }
    }

    private var performanceBarColor: Color {
        switch performance {
        case 85...: return .green
        case 75..<85: return .blue
        case 65..<75: return .orange
        default: return .red
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 12, height: 8)
                .cornerRadius(2)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Metrics Info View

struct MetricsInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Introduction
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Understanding Your Metrics")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("These metrics analyze your Steel Challenge performance data to help you train smarter and compete better.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Performance Summary Section
                    metricSection(
                        title: "Performance Summary",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .purple,
                        metrics: [
                            MetricExplanation(
                                name: "Matches",
                                description: "Total number of unique matches analyzed for this division.",
                                example: "15 matches"
                            ),
                            MetricExplanation(
                                name: "Current %",
                                description: "Your current classification percentage based on SCSA scoring. This is calculated from your classification scores across all 8 stages.",
                                example: "82.5% (B Class)"
                            ),
                            MetricExplanation(
                                name: "Last Match",
                                description: "Days since your most recent match. If this exceeds 60 days, you may experience rustiness.",
                                example: "23d"
                            ),
                            MetricExplanation(
                                name: "Current Form",
                                description: "Your average stage time across your last 3 matches. This shows how you're performing right now.",
                                example: "15.0s (recent form)"
                            ),
                            MetricExplanation(
                                name: "Historical Average",
                                description: "Your average stage time across ALL matches ever. This is your overall baseline performance.",
                                example: "15.5s (all-time)"
                            ),
                            MetricExplanation(
                                name: "Form vs Historical",
                                description: "Percentage comparing your current form to your historical baseline.\n\n• >100% = You're shooting faster than your all-time average (good form!)\n• =100% = You're at your normal baseline\n• <100% = You're shooting slower than average (possibly rusty)",
                                example: "103.3% (shooting 3.3% faster than baseline)"
                            )
                        ]
                    )

                    Divider()

                    // Stage Performance Section
                    metricSection(
                        title: "Stage Performance Metrics",
                        icon: "target",
                        color: .blue,
                        metrics: [
                            MetricExplanation(
                                name: "Performance",
                                description: "Your average performance as a percentage of the GM peak time for this stage.\n\n• 85%+ = Excellent (at or above your class level)\n• 75-85% = Good\n• 65-75% = Fair\n• <65% = Needs improvement",
                                example: "78.5% (B Class level)"
                            ),
                            MetricExplanation(
                                name: "Consistency",
                                description: "Variation in your times (coefficient of variation). Lower is better.\n\n• 0-3% = Excellent (very consistent)\n• 3-5% = Good\n• 5-8% = Fair\n• >8% = Inconsistent (high variance)",
                                example: "±4.2% (good consistency)"
                            ),
                            MetricExplanation(
                                name: "Trend",
                                description: "Recent performance direction comparing first half vs second half of your matches.\n\n• Positive (+) = Getting faster (improving)\n• Near zero = Stable performance\n• Negative (-) = Getting slower (declining)",
                                example: "+5.2% (strong improvement)"
                            ),
                            MetricExplanation(
                                name: "Best Time",
                                description: "Your fastest time ever on this stage. Shows your peak capability and the classification level achieved.",
                                example: "14.2s (A Class)"
                            ),
                            MetricExplanation(
                                name: "Average Time",
                                description: "Your mean time across all matches on this stage. This is your typical performance level.",
                                example: "15.1s (B Class)"
                            ),
                            MetricExplanation(
                                name: "Peak Time",
                                description: "The GM (Grand Master) benchmark time for this stage in your division. This is the target to compare against.",
                                example: "12.5s (GM)"
                            )
                        ]
                    )

                    Divider()

                    // Additional Metrics Section
                    metricSection(
                        title: "Additional Analysis",
                        icon: "calendar.badge.clock",
                        color: .green,
                        metrics: [
                            MetricExplanation(
                                name: "Training Frequency",
                                description: "Your typical training cadence for THIS DIVISION based on gaps between matches in this division only.\n\n• Weekly or more = Very frequent\n• Bi-weekly to monthly = Regular\n• Every 1-3 months = Occasional\n• 3+ months = Infrequent\n\nA warning appears if you haven't shot this division in 90+ days.",
                                example: "RFPO Matches: Regular (avg 21 days)"
                            ),
                            MetricExplanation(
                                name: "Overall Consistency",
                                description: "Your average consistency score across all 8 stages. Lower is better. This indicates how predictable your performance is.",
                                example: "±4.8% (good overall consistency)"
                            ),
                            MetricExplanation(
                                name: "Recent Performance Direction",
                                description: "Your overall trend across all stages and matches.\n\n• Improving = Getting faster\n• Stable = Maintaining performance\n• Declining = Getting slower",
                                example: "Improving"
                            )
                        ]
                    )

                    Divider()

                    // Color Coding Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Color Coding", systemImage: "paintpalette")
                            .font(.headline)
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 8) {
                            colorLegendItem(color: .green, label: "Excellent / Improving")
                            colorLegendItem(color: .blue, label: "Good / Stable")
                            colorLegendItem(color: .orange, label: "Fair / Attention Needed")
                            colorLegendItem(color: .red, label: "Needs Work / Declining")
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    // Footer
                    Text("💡 Tip: These metrics update automatically every Thursday when SCSA data is refreshed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Metrics Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func metricSection(title: String, icon: String, color: Color, metrics: [MetricExplanation]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(metrics) { metric in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(metric.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(metric.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let example = metric.example {
                            Text("Example: \(example)")
                                .font(.caption)
                                .italic()
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }

    private func colorLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
            Text(label)
                .font(.subheadline)
        }
    }
}

struct MetricExplanation: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let example: String?

    init(name: String, description: String, example: String? = nil) {
        self.name = name
        self.description = description
        self.example = example
    }
}
