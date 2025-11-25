//
//  MotivationalMessagesService.swift
//  GMJuice
//
//  Created by Claude on 11/23/25.
//

import Foundation
import FirebaseCore
import FirebaseRemoteConfig

@MainActor
public final class MotivationalMessagesService: ObservableObject {
    nonisolated static let shared = MotivationalMessagesService()
    
    private let remoteConfig = RemoteConfig.remoteConfig()
    private let configKey = "MotivationalMessages"
    
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var remoteMessages: [String]?
    
    // Thread-safe copy for synchronous access
    private nonisolated(unsafe) var _cachedMessages: [String]?
    
    /// Default fallback message when Firebase is unavailable
    private let defaultMessages: [String] = [
        "Keep practicing and stay focused!"
    ]
    
    nonisolated private init() {
        Task { @MainActor in
            configureRemoteConfig()
        }
    }
    
    private func configureRemoteConfig() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0 // For development - fetch every time
        #else
        settings.minimumFetchInterval = 604800 // Production - cache for 7 days
        #endif
        remoteConfig.configSettings = settings
        
        // Set default values from local messages
        setDefaultValues()
        
        // Load cached messages if available
        loadCachedMessages()
    }
    
    private func loadCachedMessages() {
        if let cachedData = UserDefaults.standard.data(forKey: "cached_motivational_messages"),
           let cachedMessages = try? JSONDecoder().decode([String].self, from: cachedData),
           !cachedMessages.isEmpty {
            remoteMessages = cachedMessages
            _cachedMessages = cachedMessages
            print("📱 Loaded \(cachedMessages.count) cached motivational messages")
        }
    }
    
    private func cacheMessages(_ messages: [String]) {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: "cached_motivational_messages")
            UserDefaults.standard.set(Date(), forKey: "cached_motivational_messages_date")
            print("💾 Cached \(messages.count) motivational messages")
        }
    }
    
    private func setDefaultValues() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(defaultMessages)
            let jsonString = String(data: data, encoding: .utf8) ?? "[]"
            
            remoteConfig.setDefaults([configKey: jsonString as NSObject])
        } catch {
            print("❌ Failed to set default motivational messages: \(error)")
        }
    }
    
    /// Initialize the service and fetch remote data
    func initialize() async {
        print("💪 Initializing MotivationalMessages service...")
        let result = await fetchLatestMessages()
        if let messages = result {
            print("💪 MotivationalMessages service initialized with \(messages.count) messages from Firebase")
        } else {
            print("💪 MotivationalMessages service initialized using local fallback")
        }
    }
    
    /// Fetch the latest messages from Firebase
    func fetchLatestMessages() async -> [String]? {
        await MainActor.run { isLoading = true }
        
        do {
            let status = try await remoteConfig.fetchAndActivate()
            
            switch status {
            case .successFetchedFromRemote:
                print("✅ MotivationalMessages: Fetched from remote")
            case .successUsingPreFetchedData:
                print("✅ MotivationalMessages: Using cached data")
            case .error:
                print("❌ MotivationalMessages: Fetch failed")
            @unknown default:
                print("⚠️ MotivationalMessages: Unknown fetch status")
            }
            
            // Parse the fetched data
            if let messages = parseMessagesFromConfig() {
                await MainActor.run {
                    self.remoteMessages = messages
                    self.lastUpdated = Date()
                    self._cachedMessages = messages
                }
                // Cache the messages persistently
                cacheMessages(messages)
                return messages
            }
            
        } catch {
            print("❌ MotivationalMessages fetch failed: \(error)")
        }
        
        await MainActor.run { isLoading = false }
        return nil
    }
    
    private func parseMessagesFromConfig() -> [String]? {
        let jsonString = remoteConfig.configValue(forKey: configKey).stringValue
        print("🔍 MotivationalMessages raw JSON from Firebase: '\(jsonString.prefix(200))...'")
        
        guard !jsonString.isEmpty else {
            print("⚠️ No MotivationalMessages data in Remote Config")
            return nil
        }
        
        do {
            guard let data = jsonString.data(using: .utf8) else {
                print("❌ Failed to convert JSON string to data")
                return nil
            }
            
            let decoder = JSONDecoder()
            let messages = try decoder.decode([String].self, from: data)
            print("✅ Loaded \(messages.count) motivational messages from Firebase")
            print("🎯 First few messages: \(messages.prefix(3))")
            return messages
            
        } catch {
            print("❌ Failed to parse motivational messages: \(error)")
            print("📄 Raw JSON data: \(jsonString)")
            return nil
        }
    }
    
    /// Get current messages (remote if available, fallback to default)
    nonisolated func getCurrentMessages() -> [String] {
        let messages = _cachedMessages ?? defaultMessages
        print("🔍 MotivationalMessages getCurrentMessages: using \(_cachedMessages != nil ? "remote" : "default"), count: \(messages.count)")
        return messages
    }
    
    /// Get a motivational message (random by default, or daily if requested)
    nonisolated func getMessage(isDaily: Bool = false) -> String {
        let messages = getCurrentMessages()
        
        let selectedMessage: String
        if isDaily {
            // Use current date as seed for consistent daily message
            let calendar = Calendar.current
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
            let index = (dayOfYear - 1) % messages.count
            selectedMessage = messages[index]
        } else {
            // Random message
            selectedMessage = messages.randomElement() ?? "Keep practicing and stay focused!"
        }
        
        print("🎯 MotivationalMessages: '\(selectedMessage)' (\(isDaily ? "daily" : "random"))")
        return selectedMessage
    }
    
    /// Legacy method for backward compatibility
    nonisolated func getRandomMessage() -> String {
        return getMessage(isDaily: false)
    }
    
    /// Legacy method for backward compatibility
    nonisolated func getDailyMessage() -> String {
        return getMessage(isDaily: true)
    }
    
    /// Check if remote data is available
    var hasRemoteData: Bool {
        return remoteMessages != nil
    }
    
    /// Synchronous access to cached messages for global functions
    nonisolated var syncMessages: [String] {
        return _cachedMessages ?? defaultMessages
    }
    
    /// Get status information for debugging
    var statusInfo: String {
        let messageCount = getCurrentMessages().count
        let source = remoteMessages != nil ? "Firebase" : "Local fallback"
        let lastUpdate = lastUpdated?.formatted() ?? "Never"
        
        return "Messages: \(messageCount) from \(source), Last updated: \(lastUpdate)"
    }
}

#if DEBUG
extension MotivationalMessagesService {
    
    /// Generate formatted JSON for Firebase Console setup
    func generateFirebaseJSON() -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(defaultMessages)
            return String(data: data, encoding: .utf8)
        } catch {
            print("❌ Failed to generate JSON: \(error)")
            return nil
        }
    }
    
    /// Debug function to print JSON for Firebase setup
    func uploadCurrentMessages() async -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(defaultMessages)
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📤 MotivationalMessages JSON for Firebase Remote Config:")
                print("Key: \(configKey)")
                print("Value:")
                print(jsonString)
                print("\n🔧 Copy this JSON to Firebase Console > Remote Config > \(configKey)")
                return true
            }
            
        } catch {
            print("❌ Failed to encode motivational messages: \(error)")
        }
        
        return false
    }
    
    /// Debug function to compare local vs remote messages
    func debugCompareMessages() {
        print("🔍 MotivationalMessages Status:")
        print("  • Remote data available: \(remoteMessages != nil)")
        print("  • Last updated: \(lastUpdated?.formatted() ?? "Never")")
        print("  • Using: \(remoteMessages != nil ? "Remote Firebase data" : "Local fallback data")")
        
        let current = getCurrentMessages()
        print("  • Total messages: \(current.count)")
        
        if !current.isEmpty {
            print("  • Sample messages:")
            for (index, message) in current.prefix(3).enumerated() {
                print("    \(index + 1). \(message)")
            }
        }
        
        print("  • Random message: \"\(getRandomMessage())\"")
        print("  • Today's message: \"\(getDailyMessage())\"")
    }
}
#endif

/// Global access to current motivational messages (Firebase remote data with local fallback)
@MainActor
public var CurrentMotivationalMessages: MotivationalMessagesService {
    return MotivationalMessagesService.shared
}