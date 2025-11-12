import Foundation

/// V2 service for processing session notes using Claude API with sport-specific domains
class ClaudeNoteServiceV2 {
    private let apiClient = ClaudeAPIClient.shared
    private let modelName = "claude-3-haiku-20240307"  // Fast, cost-effective model

    /// Check if API key is configured
    var isConfigured: Bool {
        apiClient.isConfigured
    }

    // MARK: - Initial Processing

    /// Process raw note input and extract structured content
    func processNote(rawInput: String, sessionType: String) async throws -> NoteContentV2 {
        print("🤖 Processing note with V2 service...")
        print("   Session type: \(sessionType)")
        print("   Input length: \(rawInput.count)")

        let prompt = ClaudePromptsV2.initialExtractionPrompt(
            rawInput: rawInput,
            sessionType: sessionType
        )

        let response = try await callClaudeAPI(prompt: prompt)
        let content = try parseNoteContentV2(from: response)

        print("✅ Note processed successfully")
        print("   Completeness: \(Int(content.completeness * 100))%")
        print("   Save worthiness: \(content.estimatedSaveWorthiness.rawValue)")
        print("   Missing info prompts: \(content.missingCriticalInfo.count)")

        return content
    }

    // MARK: - Follow-up Processing

    /// Update note content with additional input
    /// - Parameters:
    ///   - currentContent: Current note content
    ///   - additionalInput: Additional input from user
    ///   - targetQuestion: Optional question being answered
    func updateNote(
        currentContent: NoteContentV2,
        additionalInput: String,
        targetQuestion: FollowUpQuestion? = nil
    ) async throws -> NoteContentV2 {
        print("🔄 Updating note with additional input...")
        print("   Input length: \(additionalInput.count)")
        if let question = targetQuestion {
            print("   Target: \(question.domain).\(question.specificField)")
        }

        let prompt = ClaudePromptsV2.followUpPrompt(
            currentContent: currentContent,
            additionalInput: additionalInput,
            targetQuestion: targetQuestion
        )

        let response = try await callClaudeAPI(prompt: prompt)
        let updated = try parseNoteContentV2(from: response)

        print("✅ Note updated successfully")
        print("   New completeness: \(Int(updated.completeness * 100))%")

        return updated
    }

    // MARK: - Pattern Analysis

    /// Generate pattern insights from multiple notes
    func analyzePatterns(notes: [SessionNote]) async throws -> PatternInsights {
        print("📊 Analyzing patterns across \(notes.count) notes...")

        guard notes.count >= 5 else {
            print("⚠️ Not enough notes for pattern analysis (need 5+, have \(notes.count))")
            // Return empty insights
            return PatternInsights(insights: [], highlightNoteId: nil)
        }

        let prompt = ClaudePromptsV2.patternAnalysisPrompt(notes: notes)
        let response = try await callClaudeAPI(prompt: prompt, maxTokens: 1024)
        let insights = try parsePatternInsights(from: response)

        print("✅ Pattern analysis complete")
        print("   Insights generated: \(insights.insights.count)")

        return insights
    }

    // MARK: - Private Methods

    private func callClaudeAPI(prompt: String, maxTokens: Int = 2048) async throws -> String {
        print("🌐 Making Claude API call...")
        print("   Model: \(modelName)")
        print("   Max tokens: \(maxTokens)")

        let response = try await apiClient.makeRequest(
            prompt: prompt,
            model: modelName,
            maxTokens: maxTokens
        )

        print("✅ Claude API call successful")
        print("   Response length: \(response.count) characters")

        return response
    }

    private func parseNoteContentV2(from response: String) throws -> NoteContentV2 {
        print("📊 Parsing NoteContentV2...")

        // Extract JSON from response (may be wrapped in markdown code blocks)
        let jsonString = extractJSON(from: response)
        print("   Extracted JSON length: \(jsonString.count)")

        guard let data = jsonString.data(using: .utf8) else {
            print("❌ Failed to convert JSON string to data")
            throw NoteParseError.parseError
        }

        do {
            let decoder = JSONDecoder()
            let content = try decoder.decode(NoteContentV2.self, from: data)
            print("✅ Successfully parsed NoteContentV2")
            return content
        } catch {
            print("❌ JSON decode error: \(error)")
            print("   JSON string: \(jsonString.prefix(500))")
            throw NoteParseError.parseError
        }
    }

    private func parsePatternInsights(from response: String) throws -> PatternInsights {
        print("📊 Parsing PatternInsights...")

        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            print("❌ Failed to convert JSON string to data")
            throw NoteParseError.parseError
        }

        do {
            let decoder = JSONDecoder()
            var insights = try decoder.decode(PatternInsights.self, from: data)
            insights.generatedDate = Date()  // Set generation timestamp
            print("✅ Successfully parsed PatternInsights")
            return insights
        } catch {
            print("❌ JSON decode error: \(error)")
            throw NoteParseError.parseError
        }
    }

    private func extractJSON(from text: String) -> String {
        // Remove markdown code blocks if present
        let pattern = "```json\\s*\\n(.*)\\n```"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let jsonRange = Range(match.range(at: 1), in: text) {
            return String(text[jsonRange])
        }

        // Try to find JSON object boundaries
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }

        // Return as-is if no JSON detected
        return text
    }
}

// MARK: - Error Types

enum NoteParseError: LocalizedError {
    case parseError

    var errorDescription: String? {
        switch self {
        case .parseError:
            return "Failed to parse note content from AI response"
        }
    }
}
