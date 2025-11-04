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

    private init() {
        // Use app's cache directory
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = caches.appendingPathComponent("CoachingCards", isDirectory: true)

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
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
            // Check if still valid (based on Thursday expiration)
            if cached.isValid {
                let currentHash = CoachingService.shared.calculatePerformanceHash(from: analysis)
                if !cached.needsRegeneration(newHash: currentHash) {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    print("✅ Using cached coaching cards (expires: \(formatter.string(from: cached.expirationDate)))")
                    return CoachingResult(cards: cached, analysis: analysis)
                } else {
                    print("📈 Performance changed significantly, regenerating cards...")
                }
            } else {
                print("📅 Thursday refresh - regenerating coaching cards...")
            }
        }

        // Generate new cards
        print("🤖 Generating coaching cards with Claude API...")
        let cards = try await CoachingService.shared.generateCoaching(for: analysis)

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
}

