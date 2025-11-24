import Foundation

/// Shared client for making requests to Claude API
/// Used by CoachingService
class ClaudeAPIClient {
    static let shared = ClaudeAPIClient()

    private let apiURL = "https://api.anthropic.com/v1/messages"
    private let anthropicVersion = "2023-06-01"
    let apiKey: String?

    private init() {
        self.apiKey = Self.loadAPIKey()
    }

    /// Load API key from Info.plist
    private static func loadAPIKey() -> String? {
        // Try environment variable first
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            return envKey
        }

        // Then try Info.plist
        if let key = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String,
           !key.isEmpty,
           !key.hasPrefix("$") {
            return key
        }

        return nil
    }

    /// Check if API key is configured
    var isConfigured: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    /// Make a request to Claude API
    /// - Parameters:
    ///   - prompt: The user prompt to send
    ///   - model: The Claude model to use (e.g., "claude-3-5-sonnet-20240620")
    ///   - maxTokens: Maximum tokens for the response
    /// - Returns: The text response from Claude
    func makeRequest(prompt: String, model: String, maxTokens: Int = 1024) async throws -> String {
        // Check if Claude AI is enabled via Remote Config
        guard RemoteConfigService.shared.isClaudeAIEnabled else {
            print("🚫 Claude AI is disabled via Remote Config")
            throw ClaudeAPIError.serviceDisabled
        }
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw ClaudeAPIError.noAPIKey
        }

        guard let url = URL(string: apiURL) else {
            throw ClaudeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Claude API Error (\(httpResponse.statusCode)): \(errorBody)")
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Parse Claude API response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw ClaudeAPIError.invalidResponse
        }

        return text
    }
}

enum ClaudeAPIError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case serviceDisabled

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Anthropic API key not configured. Please add ANTHROPIC_API_KEY to Info.plist."
        case .invalidURL:
            return "Invalid Claude API URL"
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let code, let message):
            return "Claude API error (\(code)): \(message)"
        case .serviceDisabled:
            return "Claude AI service is currently disabled"
        }
    }
}
