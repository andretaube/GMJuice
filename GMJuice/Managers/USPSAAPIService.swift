//
//  USPSAAPIService.swift
//  GMJuice
//
//  Created by Claude on 11/3/25.
//

import Foundation
import SwiftData

/// Service for fetching match data from USPSA API
///
/// ## Authentication
/// The USPSA API requires authentication. To use this service:
/// 1. Install a network packet sniffer (e.g., Storm Sniffer on iOS)
/// 2. Install MITM certificate to decrypt HTTPS traffic
/// 3. Open the official USPSA mobile app and capture requests
/// 4. Extract the API key from the captured request headers
/// 5. Set the `apiKey` property or store in UserDefaults with key "uspsa_api_key"
///
/// ## API Endpoints
/// - Classification: `GET /api/app/classification/{memberNumber}`
/// - Classifiers: `GET /api/app/classifiers/{memberNumber}`
@MainActor
class USPSAAPIService: ObservableObject {
    static let shared = USPSAAPIService()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var lastError: String?

    private let baseURL = "https://api.uspsa.org/api/app"
    private var apiKey: String? {
        UserDefaults.standard.string(forKey: "uspsa_api_key")
    }

    private init() {
        self.lastSyncDate = UserDefaults.standard.object(forKey: "uspsa_last_sync") as? Date
    }

    // MARK: - Public Methods

    /// Syncs match data for the given member number
    func syncMatchData(memberNumber: String, context: ModelContext) async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw USPSAAPIError.missingAPIKey
        }

        guard !memberNumber.isEmpty else {
            throw USPSAAPIError.invalidMemberNumber
        }

        isSyncing = true
        lastError = nil

        defer {
            isSyncing = false
        }

        do {
            // Fetch classification data
            let classificationData = try await fetchClassification(memberNumber: memberNumber)

            // Fetch classifier scores
            let classifierData = try await fetchClassifiers(memberNumber: memberNumber)

            // Process and store the data
            try await processAndStoreData(
                classificationData: classificationData,
                classifierData: classifierData,
                memberNumber: memberNumber,
                context: context
            )

            // Update last sync date
            let now = Date()
            lastSyncDate = now
            UserDefaults.standard.set(now, forKey: "uspsa_last_sync")

        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Private Methods

    private func fetchClassification(memberNumber: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/classification/\(memberNumber)") else {
            throw USPSAAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey = apiKey {
            // Add authentication header - exact format needs to be determined from packet capture
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw USPSAAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw USPSAAPIError.unauthorized
        case 404:
            throw USPSAAPIError.memberNotFound
        default:
            throw USPSAAPIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func fetchClassifiers(memberNumber: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/classifiers/\(memberNumber)") else {
            throw USPSAAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey = apiKey {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw USPSAAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw USPSAAPIError.unauthorized
        case 404:
            throw USPSAAPIError.memberNotFound
        default:
            throw USPSAAPIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func processAndStoreData(
        classificationData: Data,
        classifierData: Data,
        memberNumber: String,
        context: ModelContext
    ) async throws {
        // TODO: Implement parsing once we know the actual JSON structure
        // For now, we'll just log the responses

        // Example of what the implementation might look like:
        /*
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Parse classification data
        let classifications = try decoder.decode([ClassificationResponse].self, from: classificationData)

        // Parse classifier data
        let classifiers = try decoder.decode([ClassifierResponse].self, from: classifierData)

        // Delete existing data for this member to avoid duplicates
        let existingMatches = try context.fetch(
            FetchDescriptor<USPSAMatch>(predicate: #Predicate { $0.memberNumber == memberNumber })
        )
        for match in existingMatches {
            context.delete(match)
        }

        // Store new data...
        for classification in classifications {
            // Create USPSAMatch objects
            // Create USPSAStageScore objects
            // Insert into context
        }

        for classifier in classifiers {
            // Create USPSAClassifierScore objects
            // Insert into context
        }

        try context.save()
        */

        print("Classification data: \(String(data: classificationData, encoding: .utf8) ?? "invalid")")
        print("Classifier data: \(String(data: classifierData, encoding: .utf8) ?? "invalid")")
    }

    // MARK: - API Key Management

    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "uspsa_api_key")
    }

    func clearAPIKey() {
        UserDefaults.standard.removeObject(forKey: "uspsa_api_key")
    }

    func hasAPIKey() -> Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }
}

// MARK: - Error Types

enum USPSAAPIError: LocalizedError {
    case missingAPIKey
    case invalidMemberNumber
    case invalidURL
    case invalidResponse
    case unauthorized
    case memberNotFound
    case httpError(statusCode: Int)
    case parsingError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "USPSA API key not configured. Please add your API key in settings."
        case .invalidMemberNumber:
            return "Invalid USPSA member number."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Invalid response from USPSA API."
        case .unauthorized:
            return "Unauthorized. Please check your API key."
        case .memberNotFound:
            return "Member number not found."
        case .httpError(let statusCode):
            return "HTTP error \(statusCode)"
        case .parsingError(let message):
            return "Error parsing API response: \(message)"
        }
    }
}

// MARK: - Response Models (Placeholder)
// These will need to be updated once we know the actual API response structure

struct ClassificationResponse: Codable {
    // TODO: Add actual fields from API response
    let memberNumber: String?
    let division: String?
    let classification: String?
}

struct ClassifierResponse: Codable {
    // TODO: Add actual fields from API response
    let classifierId: String?
    let date: Date?
    let hitFactor: Double?
}
