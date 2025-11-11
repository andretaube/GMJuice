import Foundation

/// Service for processing session notes using Claude API
class ClaudeNoteService {
    private let apiClient = ClaudeAPIClient.shared
    private let modelName = "claude-3-haiku-20240307"  // Claude 3 Haiku (same as coaching)

    /// Check if API key is configured
    var isConfigured: Bool {
        apiClient.isConfigured
    }

    /// Process raw note input and extract structured content
    func processNote(rawInput: String) async throws -> NoteContent {
        let prompt = ClaudePrompts.noteExtractionPrompt(rawInput: rawInput, sections: NoteSections.all)
        let response = try await callClaudeAPI(prompt: prompt)
        return try parseNoteContent(from: response)
    }

    /// Generate prompts for missing sections
    func generatePrompts(for noteContent: NoteContent) -> [NoteSection] {
        return noteContent.missingSections()
    }

    /// Update note content with additional information
    /// - Parameters:
    ///   - content: Current note content
    ///   - input: Additional input from user
    ///   - targetCategory: Optional category to focus the update on (e.g., "mental", "equipment")
    func updateNote(content: NoteContent, withAdditionalInput input: String, targetCategory: String? = nil) async throws -> NoteContent {
        let prompt = ClaudePrompts.noteUpdatePrompt(currentContent: content, additionalInput: input, targetCategory: targetCategory)
        let response = try await callClaudeAPI(prompt: prompt)
        return try parseNoteContent(from: response)
    }

    // MARK: - Private Methods

    private func callClaudeAPI(prompt: String) async throws -> String {
        print("🌐 Making Claude API call...")
        print("   Model: \(modelName)")
        let response = try await apiClient.makeRequest(prompt: prompt, model: modelName, maxTokens: 1024)
        print("✅ Claude API call successful")
        print("   Response text length: \(response.count)")
        return response
    }

    private func parseNoteContent(from response: String) throws -> NoteContent {
        print("📊 Parsing note content...")
        print("   Response length: \(response.count)")
        print("   Response preview: \(response.prefix(200))...")

        // Extract JSON from response (may be wrapped in markdown code blocks)
        let jsonString = extractJSON(from: response)
        print("   Extracted JSON length: \(jsonString.count)")

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("❌ Failed to parse JSON from response")
            print("   JSON string: \(jsonString)")
            throw NoteParseError.parseError
        }

        print("   Parsed JSON dictionary")

        var content = NoteContent()

        // Parse sections
        if let sections = json["sections"] as? [String: String] {
            print("   Found \(sections.count) sections")
            for (key, value) in sections {
                if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    content.setContent(value, for: key)
                    print("   ✓ \(key): \(value.prefix(50))...")
                }
            }
        }

        // Parse quality ratings
        if let quality = json["quality"] as? [String: Any] {
            print("   Found quality ratings")
            for (key, value) in quality {
                if let rating = value as? Int, rating >= 1 && rating <= 5 {
                    content.setQuality(rating, for: key)
                    print("   ✓ \(key) quality: \(rating)")
                } else if value is NSNull {
                    // null is okay, means not mentioned
                    print("   ○ \(key) quality: not mentioned")
                }
            }
        }

        // Parse summary
        if let summary = json["summary"] as? String {
            content.summary = summary
            print("   ✓ Summary: \(summary)")
        }

        // Parse missing info prompts
        if let prompts = json["missingInfoPrompts"] as? [String] {
            content.missingInfoPrompts = prompts
            print("   Found \(prompts.count) missing info prompts")
            for prompt in prompts {
                print("   ❓ \(prompt)")
            }
        }

        // Parse minimal detail flag
        if let hasDetail = json["hasMinimalDetail"] as? Bool {
            content.hasMinimalDetail = hasDetail
            print("   Has minimal detail: \(hasDetail)")
        }

        print("✅ Note content parsed successfully")
        return content
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

        return text
    }
}

enum NoteParseError: LocalizedError {
    case parseError

    var errorDescription: String? {
        switch self {
        case .parseError:
            return "Failed to parse note content"
        }
    }
}
