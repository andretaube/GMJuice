import Foundation

/// Defines the structured sections for match notes
struct NoteSection: Identifiable, Codable {
    let id: String
    let title: String
    let prompt: String // Prompt to ask user if this section is missing
    let aiExtractionPrompt: String // Prompt for AI to use when extracting this section
    let required: Bool // Whether this should be ~80% filled for completion

    init(id: String, title: String, prompt: String, aiPrompt: String, required: Bool = true) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.aiExtractionPrompt = aiPrompt
        self.required = required
    }
}

/// Core note sections - 7 categories for shooting session notes
enum NoteSections {
    static let all: [NoteSection] = [
        NoteSection(
            id: "match_performance",
            title: "Overall Performance",
            prompt: "How did you feel about your performance overall?",
            aiPrompt: "Extract shooter's feelings and self-assessment of their performance: satisfaction level, what felt good, what felt off, overall impressions of how they shot, confidence in performance.",
            required: false
        ),
        NoteSection(
            id: "equipment",
            title: "Equipment",
            prompt: "How did your gear perform? Any issues or changes?",
            aiPrompt: "Extract equipment information: gun setup, holster, magazines, any malfunctions or issues, gear changes, how equipment performed, any problems encountered."
        ),
        NoteSection(
            id: "conditions",
            title: "Environmental Conditions",
            prompt: "What were the conditions like? (rain, cold, heat, wind, etc.)",
            aiPrompt: "Extract environmental conditions: weather (rain/sunny/cloudy), temperature (cold/hot/comfortable), wind conditions, lighting quality, any environmental challenges."
        ),
        NoteSection(
            id: "mental",
            title: "Mental State",
            prompt: "How did you feel mentally and emotionally?",
            aiPrompt: "Extract mental/emotional FEELINGS only: confidence level, nervousness/calmness, mood (happy/anxious/excited), stress level, feeling focused or distracted, mental fatigue. DO NOT include technique goals or skills to work on - those belong in 'Things to Work On'."
        ),
        NoteSection(
            id: "physical",
            title: "Physical State",
            prompt: "How did you feel physically?",
            aiPrompt: "Extract physical condition: energy level (tired/rested/energized), hunger/hydration, health status, any pain or discomfort, physical readiness, fatigue."
        ),
        NoteSection(
            id: "social",
            title: "Squad and People",
            prompt: "Who did you shoot with? How was the social experience?",
            aiPrompt: "Extract social context: who they shot with (alone/friends/squad), specific people mentioned, squad atmosphere (relaxed/competitive/supportive), social interactions, group dynamics.",
            required: false
        ),
        NoteSection(
            id: "improvement_areas",
            title: "Things to Work On",
            prompt: "What do you wish you did better? What should you practice?",
            aiPrompt: "Extract areas for improvement, practice goals, and technique focus: what didn't go well, mistakes made, skills to work on (e.g., 'focus on wide transitions', 'work on draws'), specific weaknesses noticed, what to practice next, goals for improvement, technique areas to focus on. This can include both problems AND constructive goals."
        ),
        NoteSection(
            id: "other",
            title: "Other Notes",
            prompt: "Anything else you want to remember?",
            aiPrompt: "Extract any other relevant information not covered by the other categories: miscellaneous observations, random thoughts, anything else worth noting.",
            required: false
        )
    ]

    /// Required sections for quick capture (the essentials)
    static var required: [NoteSection] {
        all.filter { $0.required }
    }

    static func section(withId id: String) -> NoteSection? {
        all.first { $0.id == id }
    }
}

/// Quality rating scale for each section (1-5)
enum QualityRating: Int, Codable {
    case poor = 1           // Significant issues/problems
    case belowAverage = 2   // Some issues/concerns
    case average = 3        // Neutral/acceptable
    case good = 4           // Above average/positive
    case excellent = 5      // Optimal/outstanding

    var description: String {
        switch self {
        case .poor: return "Poor"
        case .belowAverage: return "Below Average"
        case .average: return "Average"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }

    var emoji: String {
        switch self {
        case .poor: return "😞"
        case .belowAverage: return "😕"
        case .average: return "😐"
        case .good: return "🙂"
        case .excellent: return "😊"
        }
    }
}

/// Structured note content with quality ratings
struct NoteContent: Codable {
    var sections: [String: String] = [:]
    var quality: [String: Int] = [:] // Quality rating 1-5 for each section
    var missingInfoPrompts: [String] = [] // AI suggestions for what info to add
    var hasMinimalDetail: Bool = true // Whether note has sufficient detail
    var summary: String? // AI-generated high-level summary (e.g., "Good practice, no issues")

    func content(for sectionId: String) -> String? {
        sections[sectionId]
    }

    func qualityRating(for sectionId: String) -> QualityRating? {
        guard let rating = quality[sectionId] else { return nil }
        return QualityRating(rawValue: rating)
    }

    mutating func setContent(_ content: String, for sectionId: String) {
        sections[sectionId] = content
    }

    mutating func setQuality(_ rating: Int, for sectionId: String) {
        quality[sectionId] = rating
    }

    /// Remove a section and its quality rating
    mutating func removeSection(_ sectionId: String) {
        sections.removeValue(forKey: sectionId)
        quality.removeValue(forKey: sectionId)
    }

    /// Completion based on required sections (~80% target)
    func completionPercentage() -> Double {
        let requiredSections = NoteSections.required
        guard !requiredSections.isEmpty else { return 1.0 }

        let filledRequired = requiredSections.filter { section in
            if let content = sections[section.id], !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            return false
        }.count

        return Double(filledRequired) / Double(requiredSections.count)
    }

    /// Get missing required sections for prompting
    func missingSections() -> [NoteSection] {
        NoteSections.required.filter { section in
            if let content = sections[section.id], !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
            return true
        }
    }

    /// Calculate overall score from all quality ratings (average of non-null ratings)
    /// Returns nil if no ratings exist, otherwise returns 1.0-5.0
    func overallScore() -> Double? {
        let ratings = quality.values.compactMap { $0 }
        guard !ratings.isEmpty else { return nil }
        let sum = ratings.reduce(0, +)
        return Double(sum) / Double(ratings.count)
    }

    /// Get a display string for the overall score (e.g., "4.2/5.0" or "Good")
    func overallScoreDisplay() -> String? {
        guard let score = overallScore() else { return nil }
        return String(format: "%.1f/5.0", score)
    }

    /// Get the emoji representation for overall score
    func overallScoreEmoji() -> String? {
        guard let score = overallScore() else { return nil }
        let rounded = Int(round(score))
        return QualityRating(rawValue: rounded)?.emoji
    }
}
