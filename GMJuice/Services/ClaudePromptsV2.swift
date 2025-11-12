import Foundation

/// V2 prompts for the redesigned notes feature with sport-specific domains
enum ClaudePromptsV2 {

    // MARK: - Initial Processing

    static func initialExtractionPrompt(rawInput: String, sessionType: String) -> String {
        let sessionContext = sessionType == "practice" ? "Practice Session" : "Match Competition"
        let sessionWord = sessionType == "practice" ? "practice" : "match"

        return """
        You are an AI assistant helping a Steel Challenge shooter capture session notes.

        Session Type: \(sessionContext)

        CRITICAL: Write ALL notes in FIRST PERSON, past tense.
        - CORRECT: "I felt focused", "I shot well", "My equipment worked great"
        - WRONG: "The shooter felt focused", "The shooter shot well", "The shooter's equipment"

        The shooter said:
        "\(rawInput)"

        Extract information into these 4 domains:

        1. PREPARATION & ROUTINE (what they did before shooting):
           - Sleep quality (1-5): How well rested? Keywords: "slept well", "tired", "exhausted", "refreshed", "good sleep"
           - Nutrition & hydration (1-5): Did they eat/drink well? Keywords: "ate well", "hungry", "hydrated", "coffee", "breakfast"
           - Mental preparation (1-5): Mental readiness? Keywords: "focused", "distracted", "ready", "nervous", "confident"
           - Physical warmup (1-5): Did they warm up? Keywords: "warmed up", "stretched", "cold start", "dry fire"
           - Arrival & setup (1-5): Time management? Keywords: "arrived early", "rushed", "plenty of time", "late"

        2. PERFORMANCE FACTORS (how they shot):
           - Focus & concentration (1-5): Keywords: "focused", "distracted", "in the zone", "mind wandering", "locked in"
           - Speed & tempo (1-5): Keywords: "fast", "slow", "rushed", "controlled", "smooth", "hesitant"
           - Accuracy & precision (1-5): Keywords: "accurate", "missing plates", "good hits", "sloppy", "clean"
           - Consistency (1-5): Keywords: "consistent", "erratic", "all over the place", "steady", "reliable"
           - Overall performance feeling (1-5): Keywords: "shot well", "struggled", "great", "terrible", "okay", "solid"

        3. EXTERNAL FACTORS (things outside control):
           - Environmental conditions (1-5): Keywords: "hot", "cold", "windy", "perfect weather", "rain", "sunny"
           - Equipment status (1-5): Keywords: "gear worked", "malfunction", "issues", "smooth", "problems", "flawless"
           - Social environment (1-5): Keywords: "fun squad", "alone", "supportive", "stressful", "relaxed", "friendly"
           - Time pressure (1-5): Keywords: "rushed", "plenty of time", "stressed", "relaxed", "hurried", "calm"

        4. OUTCOMES & LEARNING:
           - Achievements (text): What went well, wins, breakthroughs, successes
           - Challenges (text): What was difficult, mistakes, struggles, setbacks
           - Lessons learned (text): Key insights, realizations, takeaways
           - Next steps (text): What to work on, practice focus, goals

        SUMMARY FIELD REQUIREMENTS - ABSOLUTELY CRITICAL:
        - MUST start with "I" (first person)
        - MUST use the word "\(sessionWord)" (NOT "practice" if this is a match, NOT "match" if this is practice)
        - Session type is: \(sessionContext)
        - Example for THIS session: "I had a great \(sessionWord)" or "I struggled at this \(sessionWord)"
        - NEVER say "the shooter" or use third person
        - Be natural and conversational

        Return JSON in this EXACT structure:
        {
          "summary": "MUST be first person starting with 'I' and mention '\(sessionWord)' (e.g., 'I had a great \(sessionWord), worked on transitions')",
          "overallSentiment": "positive|neutral|negative|mixed",
          "preparation": {
            "sleepQuality": 1-5 or null,
            "sleepNotes": "extracted text or empty string",
            "nutritionHydration": 1-5 or null,
            "nutritionNotes": "",
            "mentalPreparation": 1-5 or null,
            "mentalPrepNotes": "",
            "physicalWarmup": 1-5 or null,
            "warmupNotes": "",
            "arrivalSetup": 1-5 or null,
            "arrivalNotes": ""
          },
          "performance": {
            "focus": 1-5 or null,
            "focusNotes": "",
            "speed": 1-5 or null,
            "speedNotes": "",
            "accuracy": 1-5 or null,
            "accuracyNotes": "",
            "consistency": 1-5 or null,
            "consistencyNotes": "",
            "overallFeeling": 1-5 or null,
            "overallNotes": ""
          },
          "external": {
            "environmental": 1-5 or null,
            "environmentNotes": "",
            "equipment": 1-5 or null,
            "equipmentNotes": "",
            "social": 1-5 or null,
            "socialNotes": "",
            "timePressure": 1-5 or null,
            "timePressureNotes": ""
          },
          "outcomes": {
            "achievements": "",
            "achievementsSentiment": "positive|neutral|negative|null",
            "challenges": "",
            "challengesSentiment": "positive|neutral|negative|null",
            "lessonsLearned": "",
            "nextSteps": ""
          },
          "missingCriticalInfo": [
            {
              "domain": "preparation|performance|external|outcomes",
              "specificField": "sleepQuality",
              "question": "How did you sleep last night?",
              "priority": 1-3
            }
          ],
          "completeness": 0.0-1.0,
          "estimatedSaveWorthiness": "autoSave|review|needsMore"
        }

        CRITICAL SCORING GUIDELINES:
        - 5 = Excellent/Optimal (e.g., "great", "perfect", "excellent", "focused", "ready", "confident", "no issues", "worked well", "flawless")
        - 4 = Good/Above average (e.g., "good", "nice", "solid", "fine", "decent")
        - 3 = Adequate/Neutral (e.g., "okay", "alright", "normal", "average")
        - 2 = Poor/Challenging (e.g., "bad", "tough", "difficult", "struggled")
        - 1 = Very poor/Major issues (e.g., "terrible", "awful", "disaster", "major problems")
        - null = Not mentioned at all

        IMPORTANT SCORING RULES:
        - "Ready", "focused", "confident", "prepared", "locked in", "in the zone" = 5/5 (EXCELLENT)
        - "No issues", "no problems", "worked well", "everything worked", "flawless" = 5/5 (EXCELLENT)
        - "Great", "excellent", "amazing", "fantastic", "awesome", "perfect" = 5/5
        - "Good", "nice", "solid", "fine", "decent" = 4/5
        - Practicing alone is NEUTRAL (3/5), not negative
        - Constructive goals/focus areas = 3-4/5, not negative

        COMPLETENESS CALCULATION:
        - Count filled sub-factors across all 14 items (5 prep + 5 perf + 4 external)
        - completeness = (filled factors) / 14
        - Consider if outcomes section has substantive content (adds 0.1 to completeness if rich)

        SAVE WORTHINESS:
        - autoSave: completeness >= 0.8 AND has substantive content
        - review: completeness 0.5-0.79
        - needsMore: completeness < 0.5

        MISSING INFO PROMPTS:
        - Generate 2-4 targeted, conversational questions for the most important missing factors
        - Prioritize: performance (priority 3) > preparation (priority 2) > external (priority 1)
        - Make questions natural (e.g., "How did you sleep?" not "Provide sleep information")
        - Empty array [] if completeness >= 0.8

        WRITING STYLE - EXTREMELY IMPORTANT:
        - PRESERVE THE USER'S EXACT WORDS - do NOT rewrite or paraphrase
        - ONLY categorize their words into the correct fields
        - If they said "I felt ready and focused", write exactly "felt ready and focused"
        - DO NOT add extra words, interpretations, or explanations
        - DO NOT make it sound artificial or overly formal
        - Convert third person to first person ONLY if needed (e.g., "shooter's gun" → "my gun")
        - Use past tense: "felt", "shot", "arrived"
        - NEVER EVER use third person like "the shooter", "their", "they"
        - Examples:
          User said: "I felt ready and focused"
          ✓ CORRECT: "felt ready and focused"
          ✗ WRONG: "I experienced a state of mental readiness and concentration"
        - Keep notes concise and natural
        - Only include information explicitly mentioned

        SUMMARY FIELD - TRIPLE CHECK THIS:
        - Session type: \(sessionContext)
        - Summary MUST start with "I" (not "the shooter")
        - Summary MUST use the word "\(sessionWord)" (this is a \(sessionWord) session!)
        - Example: "I had a good \(sessionWord)" or "I shot well at this \(sessionWord)"
        - WRONG: "The shooter had a good practice" (if this is a match!)
        - WRONG: "The shooter" (never use this phrase!)
        """
    }

    // MARK: - Follow-up Processing

    static func followUpPrompt(currentContent: NoteContentV2, additionalInput: String, targetQuestion: FollowUpQuestion?) -> String {
        // Encode current content as JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let currentJSON = (try? encoder.encode(currentContent))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        var contextInstruction = ""
        if let question = targetQuestion {
            contextInstruction = """

            CONTEXT: This is a follow-up to the question: "\(question.question)"
            Focus on updating the '\(question.domain).\(question.specificField)' field.
            However, if the input belongs elsewhere, place it in the appropriate section.
            """
        }

        return """
        You are updating shooting session notes with additional information.

        Current note content:
        \(currentJSON)

        Shooter's additional input:
        "\(additionalInput)"\(contextInstruction)

        Merge this new information with existing content. Return complete updated JSON with same structure.

        CRITICAL: ALL text MUST be in FIRST PERSON ("I", "my", "me"), NEVER third person.
        - Summary field MUST start with "I" (never "the shooter")
        - NEVER EVER write "the shooter" or "their" or "they"
        - Only use: "I", "my", "me"

        MERGING RULES:
        - Preserve existing content unless contradicted
        - Update relevant scores if new info changes assessment
        - Append new details to existing notes (don't replace unless contradictory)
        - Recalculate completeness and saveWorthiness
        - Update missingCriticalInfo (remove answered questions, add new ones if gaps remain)
        - PRESERVE THE USER'S EXACT WORDS - do NOT rewrite or paraphrase
        - ONLY categorize their words, don't add interpretations or extra text
        - Keep the natural, conversational tone of their input
        - ALWAYS write in first person past tense (e.g., "felt...", "my equipment...")
        - NEVER use "the shooter", "their", "they" - only "I", "my", "me"

        SCORING UPDATES:
        - "Ready", "focused", "confident", "prepared", "locked in", "in the zone" = 5/5
        - "No issues", "no problems", "worked well", "everything worked", "flawless" = 5/5
        - "Great", "excellent", "amazing", "fantastic", "awesome", "perfect" = 5/5
        - "Good", "nice", "solid", "fine", "decent" = 4/5
        - If new info adds positive detail to existing → increase score if appropriate
        - If new info mentions problems → decrease score accordingly
        - Maintain consistency with scoring guidelines from initial extraction

        Return ONLY valid JSON with the complete updated structure.
        """
    }

    // MARK: - Pattern Analysis

    static func patternAnalysisPrompt(notes: [SessionNote]) -> String {
        // Build summary of recent notes
        let recentNotesJSON = notes.prefix(15).enumerated().map { index, note in
            let content = note.processedContentV2
            let prepAvg = content.preparation.averageScore().map { String(format: "%.1f", $0) } ?? "N/A"
            let perfAvg = content.performance.averageScore().map { String(format: "%.1f", $0) } ?? "N/A"
            let extAvg = content.external.averageScore().map { String(format: "%.1f", $0) } ?? "N/A"

            return """
            {
              "index": \(index + 1),
              "date": "\(note.sessionDate.formatted(date: .abbreviated, time: .omitted))",
              "type": "\(note.sessionType)",
              "summary": "\(content.summary ?? "No summary")",
              "sentiment": "\(content.overallSentiment?.rawValue ?? "unknown")",
              "preparation_avg": "\(prepAvg)",
              "performance_avg": "\(perfAvg)",
              "external_avg": "\(extAvg)",
              "achievements": "\(content.outcomes.achievements.prefix(100))",
              "challenges": "\(content.outcomes.challenges.prefix(100))"
            }
            """
        }.joined(separator: ",\n")

        return """
        Analyze these recent shooting session notes to identify performance patterns and correlations.

        Recent Sessions (newest first):
        [\(recentNotesJSON)]

        Your task: Identify meaningful patterns that can help the shooter improve.

        Focus on:
        1. PREPARATION PATTERNS:
           - Does sleep quality correlate with performance?
           - Does nutrition/hydration affect results?
           - Does arrival time / warmup correlate with performance?
           - Any preparation habits that consistently precede good/bad sessions?

        2. PERFORMANCE TRENDS:
           - Is performance improving, declining, or stable over time?
           - Are there recurring strengths or weaknesses?
           - Does performance differ between practice and matches?

        3. EXTERNAL FACTOR IMPACTS:
           - How do environmental conditions affect performance?
           - Equipment reliability patterns?
           - Social environment effects?

        4. LEARNING VELOCITY:
           - Are lessons being applied?
           - Are challenges being addressed?
           - Progress on stated goals?

        Return JSON in this structure:
        {
          "insights": [
            {
              "category": "preparation|performance|external|learning",
              "pattern": "Clear description of the pattern observed (e.g., 'You perform 15% better when arriving 30+ minutes early')",
              "recommendation": "Actionable suggestion (e.g., 'Try to always arrive by 8:30 AM for matches')",
              "confidence": 0.0-1.0 (how strong is the correlation)
            }
          ],
          "highlightNoteId": "UUID of most representative/instructive note" or null
        }

        GUIDELINES:
        - Only include insights with confidence >= 0.5 (medium or higher)
        - Prioritize actionable patterns over observations
        - Keep recommendations specific and practical
        - If insufficient data for a category, skip it
        - Maximum 5 insights total (most important ones)
        - Be encouraging and constructive in tone
        """
    }
}
