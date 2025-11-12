import Foundation

// MARK: - Main Note Content Structure

/// Version 2 of note content with shooting-sport-optimized domain structure
struct NoteContentV2: Codable {
    var summary: String?
    var overallSentiment: Sentiment?

    // Domain-specific content
    var preparation: PreparationContent = PreparationContent()
    var performance: PerformanceContent = PerformanceContent()
    var external: ExternalContent = ExternalContent()
    var outcomes: OutcomesContent = OutcomesContent()

    // AI-generated metadata
    var missingCriticalInfo: [FollowUpQuestion] = []
    var completeness: Double = 0.0  // 0.0-1.0
    var estimatedSaveWorthiness: SaveWorthiness = .review

    /// Calculate overall score from all domain averages
    func overallScore() -> Double? {
        let allScores = [
            preparation.averageScore(),
            performance.averageScore(),
            external.averageScore()
        ].compactMap { $0 }

        guard !allScores.isEmpty else { return nil }
        return allScores.reduce(0, +) / Double(allScores.count)
    }

    /// Get display string for overall score
    func overallScoreDisplay() -> String? {
        guard let score = overallScore() else { return nil }
        return String(format: "%.1f/5.0", score)
    }

    /// Get emoji for overall score
    func overallScoreEmoji() -> String? {
        guard let score = overallScore() else { return nil }
        return scoreToEmoji(score)
    }

    private func scoreToEmoji(_ score: Double) -> String {
        switch score {
        case 4.5...5.0: return "😊"  // Excellent
        case 3.5..<4.5: return "🙂"  // Good
        case 2.5..<3.5: return "😐"  // Average
        case 1.5..<2.5: return "😕"  // Below average
        default: return "😞"         // Poor
        }
    }
}

// MARK: - Supporting Enums

enum Sentiment: String, Codable {
    case positive
    case neutral
    case negative
    case mixed
}

enum SaveWorthiness: String, Codable {
    case autoSave      // >80% complete, high quality
    case review        // 50-80%, show preview
    case needsMore     // <50%, prompt for more
}

// MARK: - Follow-up Question

struct FollowUpQuestion: Codable, Identifiable {
    var id: UUID
    var domain: String  // "preparation", "performance", "external", "outcomes"
    var specificField: String  // "sleepQuality", "focus", etc.
    var question: String  // Natural language prompt
    var priority: Int  // 1-3, higher = more important

    enum CodingKeys: String, CodingKey {
        case id, domain, specificField, question, priority
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.domain = try container.decode(String.self, forKey: .domain)
        self.specificField = try container.decode(String.self, forKey: .specificField)
        self.question = try container.decode(String.self, forKey: .question)
        self.priority = try container.decode(Int.self, forKey: .priority)
    }

    init(id: UUID = UUID(), domain: String, specificField: String, question: String, priority: Int) {
        self.id = id
        self.domain = domain
        self.specificField = specificField
        self.question = question
        self.priority = priority
    }
}

// MARK: - Domain: Preparation & Routine

struct PreparationContent: Codable {
    // Sleep
    var sleepQuality: Int?  // 1-5
    var sleepNotes: String = ""

    // Nutrition
    var nutritionHydration: Int?  // 1-5
    var nutritionNotes: String = ""

    // Mental prep
    var mentalPreparation: Int?  // 1-5
    var mentalPrepNotes: String = ""

    // Physical warmup
    var physicalWarmup: Int?  // 1-5
    var warmupNotes: String = ""

    // Arrival/setup
    var arrivalSetup: Int?  // 1-5
    var arrivalNotes: String = ""

    func averageScore() -> Double? {
        let scores = [sleepQuality, nutritionHydration, mentalPreparation,
                      physicalWarmup, arrivalSetup].compactMap { $0 }
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    func averageScoreDisplay() -> String? {
        guard let score = averageScore() else { return nil }
        return String(format: "%.1f", score)
    }
}

// MARK: - Domain: Performance Factors

struct PerformanceContent: Codable {
    // Focus
    var focus: Int?  // 1-5
    var focusNotes: String = ""

    // Speed/tempo
    var speed: Int?  // 1-5
    var speedNotes: String = ""

    // Accuracy
    var accuracy: Int?  // 1-5
    var accuracyNotes: String = ""

    // Consistency
    var consistency: Int?  // 1-5
    var consistencyNotes: String = ""

    // Overall feeling
    var overallFeeling: Int?  // 1-5
    var overallNotes: String = ""

    func averageScore() -> Double? {
        let scores = [focus, speed, accuracy, consistency, overallFeeling].compactMap { $0 }
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    func averageScoreDisplay() -> String? {
        guard let score = averageScore() else { return nil }
        return String(format: "%.1f", score)
    }
}

// MARK: - Domain: External Factors

struct ExternalContent: Codable {
    // Environmental
    var environmental: Int?  // 1-5
    var environmentNotes: String = ""

    // Equipment
    var equipment: Int?  // 1-5
    var equipmentNotes: String = ""

    // Social
    var social: Int?  // 1-5
    var socialNotes: String = ""

    // Time pressure
    var timePressure: Int?  // 1-5
    var timePressureNotes: String = ""

    func averageScore() -> Double? {
        let scores = [environmental, equipment, social, timePressure].compactMap { $0 }
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    func averageScoreDisplay() -> String? {
        guard let score = averageScore() else { return nil }
        return String(format: "%.1f", score)
    }
}

// MARK: - Domain: Outcomes & Learning

struct OutcomesContent: Codable {
    // Achievements
    var achievements: String = ""
    var achievementsSentiment: Sentiment?

    // Challenges
    var challenges: String = ""
    var challengesSentiment: Sentiment?

    // Lessons learned
    var lessonsLearned: String = ""

    // Next steps
    var nextSteps: String = ""

    /// Check if outcomes section has substantial content
    func hasContent() -> Bool {
        return !achievements.isEmpty || !challenges.isEmpty ||
               !lessonsLearned.isEmpty || !nextSteps.isEmpty
    }
}

// MARK: - Pattern Insights

struct PatternInsights: Codable {
    var insights: [Insight]
    var highlightNoteId: UUID?
    var generatedDate: Date = Date()

    struct Insight: Codable, Identifiable {
        var id: UUID = UUID()
        var category: String  // "preparation", "performance", "external", "learning"
        var pattern: String
        var recommendation: String
        var confidence: Double  // 0.0-1.0
    }
}

// MARK: - Capture History

struct CaptureEntry: Codable {
    var timestamp: Date
    var input: String
    var source: CaptureSource
}

enum CaptureSource: String, Codable {
    case speech
    case text
}
