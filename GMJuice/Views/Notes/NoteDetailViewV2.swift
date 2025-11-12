import SwiftUI
import SwiftData

struct NoteDetailViewV2: View {
    @Bindable var note: SessionNote
    @Environment(\.dismiss) private var dismiss

    @State private var showingLinkPerformance = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Linked performance (if any)
                if !note.linkedStringRunIds.isEmpty || note.linkedMatchName != nil {
                    linkedPerformanceSection
                }

                // Domain sections
                preparationSection
                performanceSection
                externalSection
                outcomesSection

                // Insights (if available)
                if note.hasPatternInsights {
                    insightsSection
                }
            }
            .padding()
        }
        .navigationTitle("Session Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingLinkPerformance = true }) {
                        Label("Link Performance", systemImage: "link")
                    }

                    Button(action: {}) {
                        Label("Edit Note", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive, action: {}) {
                        Label("Delete Note", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingLinkPerformance) {
            LinkPerformanceView(note: note)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Session type badge
            HStack {
                Image(systemName: note.sessionType == "match" ? "trophy.fill" : "figure.run")
                    .foregroundStyle(note.sessionType == "match" ? .orange : .blue)
                Text(note.sessionType == "match" ? "Match" : "Practice")
                    .fontWeight(.semibold)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(note.sessionDate.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            // Summary
            if let summary = note.processedContentV2.summary {
                Text(summary)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Overall score card
            if let scoreDisplay = note.processedContentV2.overallScoreDisplay(),
               let scoreEmoji = note.processedContentV2.overallScoreEmoji() {
                HStack(spacing: 15) {
                    Text(scoreEmoji)
                        .font(.system(size: 48))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(scoreDisplay)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Overall Score")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color(.systemGray6), Color(.systemGray5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
            }
        }
    }

    // MARK: - Linked Performance Section

    private var linkedPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundStyle(.blue)
                Text("Linked Performance")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                if !note.linkedStringRunIds.isEmpty {
                    HStack {
                        Image(systemName: "target")
                            .foregroundStyle(.blue)
                        Text("\(note.linkedStringRunIds.count) practice string(s)")
                            .font(.subheadline)
                    }
                }

                if let matchName = note.linkedMatchName,
                   let matchDate = note.linkedMatchDate {
                    HStack {
                        Image(systemName: "trophy")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text(matchName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(matchDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.08))
            .cornerRadius(12)
        }
    }

    // MARK: - Domain Sections

    private var preparationSection: some View {
        let prep = note.processedContentV2.preparation

        return DomainCard(
            title: "Preparation & Routine",
            icon: "moon.stars.fill",
            color: .purple,
            averageScore: prep.averageScoreDisplay()
        ) {
            FactorRow(title: "Sleep Quality", score: prep.sleepQuality, notes: prep.sleepNotes)
            FactorRow(title: "Nutrition & Hydration", score: prep.nutritionHydration, notes: prep.nutritionNotes)
            FactorRow(title: "Mental Preparation", score: prep.mentalPreparation, notes: prep.mentalPrepNotes)
            FactorRow(title: "Physical Warmup", score: prep.physicalWarmup, notes: prep.warmupNotes)
            FactorRow(title: "Arrival & Setup", score: prep.arrivalSetup, notes: prep.arrivalNotes)
        }
    }

    private var performanceSection: some View {
        let perf = note.processedContentV2.performance

        return DomainCard(
            title: "Performance Factors",
            icon: "target",
            color: .blue,
            averageScore: perf.averageScoreDisplay()
        ) {
            FactorRow(title: "Focus & Concentration", score: perf.focus, notes: perf.focusNotes)
            FactorRow(title: "Speed & Tempo", score: perf.speed, notes: perf.speedNotes)
            FactorRow(title: "Accuracy & Precision", score: perf.accuracy, notes: perf.accuracyNotes)
            FactorRow(title: "Consistency", score: perf.consistency, notes: perf.consistencyNotes)
            FactorRow(title: "Overall Feeling", score: perf.overallFeeling, notes: perf.overallNotes)
        }
    }

    private var externalSection: some View {
        let ext = note.processedContentV2.external

        return DomainCard(
            title: "External Factors",
            icon: "cloud.sun.fill",
            color: .cyan,
            averageScore: ext.averageScoreDisplay()
        ) {
            FactorRow(title: "Environmental Conditions", score: ext.environmental, notes: ext.environmentNotes)
            FactorRow(title: "Equipment Status", score: ext.equipment, notes: ext.equipmentNotes)
            FactorRow(title: "Social Environment", score: ext.social, notes: ext.socialNotes)
            FactorRow(title: "Time Pressure", score: ext.timePressure, notes: ext.timePressureNotes)
        }
    }

    private var outcomesSection: some View {
        let outcomes = note.processedContentV2.outcomes

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("Outcomes & Learning")
                    .font(.headline)
            }

            if !outcomes.achievements.isEmpty {
                OutcomeCard(
                    title: "Achievements & Highlights",
                    icon: "trophy.fill",
                    color: .green,
                    content: outcomes.achievements,
                    sentiment: outcomes.achievementsSentiment
                )
            }

            if !outcomes.challenges.isEmpty {
                OutcomeCard(
                    title: "Challenges & Difficulties",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    content: outcomes.challenges,
                    sentiment: outcomes.challengesSentiment
                )
            }

            if !outcomes.lessonsLearned.isEmpty {
                OutcomeCard(
                    title: "Key Lessons Learned",
                    icon: "lightbulb.fill",
                    color: .yellow,
                    content: outcomes.lessonsLearned,
                    sentiment: nil
                )
            }

            if !outcomes.nextSteps.isEmpty {
                OutcomeCard(
                    title: "Next Steps & Focus Areas",
                    icon: "arrow.right.circle.fill",
                    color: .blue,
                    content: outcomes.nextSteps,
                    sentiment: nil
                )
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.pink)
                Text("AI Insights")
                    .font(.headline)
            }

            if let insights = note.insights {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(insights.insights) { insight in
                        InsightRow(insight: insight)
                    }
                }
            } else {
                Text("No insights available yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .padding()
        .background(Color.pink.opacity(0.08))
        .cornerRadius(16)
    }
}

// MARK: - Supporting Views

struct DomainCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let averageScore: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                Spacer()
                if let score = averageScore {
                    Text(score)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(color)
                }
            }

            content
        }
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(16)
    }
}

struct FactorRow: View {
    let title: String
    let score: Int?
    let notes: String

    var body: some View {
        if score != nil || !notes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if let score = score {
                        ScoreBadge(score: score)
                    }
                }

                if !notes.isEmpty {
                    Text(notes)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct ScoreBadge: View {
    let score: Int

    var emoji: String {
        switch score {
        case 5: return "😊"
        case 4: return "🙂"
        case 3: return "😐"
        case 2: return "😕"
        default: return "😞"
        }
    }

    var color: Color {
        switch score {
        case 5: return .green
        case 4: return .blue
        case 3: return .yellow
        case 2: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.body)
            Text("\(score)/5")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

struct OutcomeCard: View {
    let title: String
    let icon: String
    let color: Color
    let content: String
    let sentiment: Sentiment?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if let sentiment = sentiment {
                    SentimentBadge(sentiment: sentiment)
                }
            }

            Text(content)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}

struct SentimentBadge: View {
    let sentiment: Sentiment

    var icon: String {
        switch sentiment {
        case .positive: return "hand.thumbsup.fill"
        case .negative: return "hand.thumbsdown.fill"
        case .neutral: return "minus.circle.fill"
        case .mixed: return "plusminus.circle.fill"
        }
    }

    var color: Color {
        switch sentiment {
        case .positive: return .green
        case .negative: return .red
        case .neutral: return .gray
        case .mixed: return .orange
        }
    }

    var body: some View {
        Image(systemName: icon)
            .foregroundStyle(color)
            .font(.caption)
    }
}

struct InsightRow: View {
    let insight: PatternInsights.Insight

    var categoryIcon: String {
        switch insight.category {
        case "preparation": return "moon.stars.fill"
        case "performance": return "target"
        case "external": return "cloud.sun.fill"
        case "learning": return "lightbulb.fill"
        default: return "star.fill"
        }
    }

    var categoryColor: Color {
        switch insight.category {
        case "preparation": return .purple
        case "performance": return .blue
        case "external": return .cyan
        case "learning": return .yellow
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: categoryIcon)
                    .foregroundStyle(categoryColor)
                Text(insight.category.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(categoryColor)
                Spacer()
                ConfidenceBadge(confidence: insight.confidence)
            }

            Text(insight.pattern)
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(insight.recommendation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(categoryColor.opacity(0.08))
        .cornerRadius(12)
    }
}

struct ConfidenceBadge: View {
    let confidence: Double

    var label: String {
        if confidence >= 0.8 {
            return "High"
        } else if confidence >= 0.6 {
            return "Medium"
        } else {
            return "Low"
        }
    }

    var color: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .blue
        } else {
            return .orange
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

#Preview {
    NavigationStack {
        NoteDetailViewV2(note: {
            let note = SessionNote(sessionDate: Date(), sessionType: "practice")
            var content = NoteContentV2()
            content.summary = "Great practice session"
            content.preparation.sleepQuality = 5
            content.preparation.sleepNotes = "Slept well, 8 hours"
            content.performance.focus = 4
            content.performance.focusNotes = "Mostly focused, a bit distracted"
            note.processedContentV2 = content
            return note
        }())
    }
}
