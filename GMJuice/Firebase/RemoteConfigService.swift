//
//  RemoteConfigService.swift
//  GMJuice
//
//  Created by Claude on 11/23/25.
//

import Foundation
import FirebaseCore
import FirebaseRemoteConfig
import Combine

// MARK: - Remote Config Keys

enum RemoteConfigKey: String, CaseIterable {
    case profileEnabled = "ProfileEnabled"
    case analysisEnabled = "AnalysisEnabled"
    case scsaDataEnabled = "SCSADataEnabled"
    case claudeAIEnabled = "ClaudeAIEnabled"
    
    var defaultValue: Any {
        switch self {
        case .profileEnabled:
            return true // Default to enabled
        case .analysisEnabled:
            return true // Default to enabled
        case .scsaDataEnabled:
            return true // Default to enabled
        case .claudeAIEnabled:
            return true // Default to enabled
        }
    }
}

// MARK: - Remote Config Service

final class RemoteConfigService: ObservableObject {
    static let shared = RemoteConfigService()
    
    private let remoteConfig: RemoteConfig
    
    // Published properties for real-time updates
    @Published var profileEnabled: Bool = true
    @Published var analysisEnabled: Bool = true
    @Published var scsaDataEnabled: Bool = true
    @Published var claudeAIEnabled: Bool = true
    
    private init() {
        remoteConfig = RemoteConfig.remoteConfig()
        setupDefaults()
    }
    
    /// Initialize Remote Config with default values and fetch latest config
    func initialize() async {
        setupDefaults()
        await fetchConfig()
        await updatePublishedValues()
    }
    
    /// Set up default values for all Remote Config keys
    private func setupDefaults() {
        var defaults: [String: NSObject] = [:]
        
        for key in RemoteConfigKey.allCases {
            defaults[key.rawValue] = key.defaultValue as? NSObject
        }
        
        remoteConfig.setDefaults(defaults)
        
        // Set fetch and cache expiration settings
        let settings = RemoteConfigSettings()
        
        #if DEBUG
        // In debug mode, fetch more frequently for testing
        settings.minimumFetchInterval = 0
        #else
        // In production, cache for 1 hour
        settings.minimumFetchInterval = 3600
        #endif
        
        remoteConfig.configSettings = settings
        
        print("🔧 Remote Config: Initialized with Firebase Remote Config")
    }
    
    /// Fetch the latest configuration from Firebase
    private func fetchConfig() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            
            switch status {
            case .successFetchedFromRemote:
                print("✅ Remote Config: Fetched from remote and activated")
            case .successUsingPreFetchedData:
                print("✅ Remote Config: Using pre-fetched data")
            case .error:
                print("❌ Remote Config: Fetch failed with error")
            @unknown default:
                print("⚠️ Remote Config: Unknown fetch status")
            }
            
        } catch {
            print("❌ Remote Config fetch failed: \(error)")
        }
    }
    
    /// Update all published properties with current Remote Config values
    @MainActor
    private func updatePublishedValues() {
        let remoteProfileEnabled = remoteConfig.configValue(forKey: RemoteConfigKey.profileEnabled.rawValue).boolValue
        let remoteAnalysisEnabled = remoteConfig.configValue(forKey: RemoteConfigKey.analysisEnabled.rawValue).boolValue
        let remoteSCSADataEnabled = remoteConfig.configValue(forKey: RemoteConfigKey.scsaDataEnabled.rawValue).boolValue
        let remoteClaudeAIEnabled = remoteConfig.configValue(forKey: RemoteConfigKey.claudeAIEnabled.rawValue).boolValue
        
        profileEnabled = remoteProfileEnabled
        scsaDataEnabled = remoteSCSADataEnabled
        claudeAIEnabled = remoteClaudeAIEnabled
        
        // Logic: If Profile is disabled, Analysis should be enabled
        // Otherwise, use the remote Analysis setting
        if !remoteProfileEnabled {
            analysisEnabled = true
        } else {
            analysisEnabled = remoteAnalysisEnabled
        }
        
        print("📱 Remote Config Values Updated:")
        print("  - Profile Enabled: \(profileEnabled)")
        print("  - Analysis Enabled: \(analysisEnabled) (remote: \(remoteAnalysisEnabled), auto-enabled due to profile: \(!remoteProfileEnabled))")
        print("  - SCSA Data Enabled: \(scsaDataEnabled)")
        print("  - Claude AI Enabled: \(claudeAIEnabled)")
    }
    
    /// Manually refresh configuration (can be called from UI)
    func refresh() async {
        await fetchConfig()
        await updatePublishedValues()
    }
    
    /// Get a specific config value (with type safety)
    func getValue<T>(for key: RemoteConfigKey, as type: T.Type) -> T? {
        let configValue = remoteConfig.configValue(forKey: key.rawValue)
        
        switch type {
        case is Bool.Type:
            return configValue.boolValue as? T
        case is String.Type:
            return configValue.stringValue as? T
        case is Int.Type:
            return Int(truncating: configValue.numberValue) as? T
        case is Double.Type:
            return configValue.numberValue.doubleValue as? T
        default:
            return nil
        }
    }
    
}

// MARK: - Convenience Methods

extension RemoteConfigService {
    /// Quick access to profile enabled status
    var isProfileEnabled: Bool {
        return profileEnabled
    }
    
    /// Quick access to analysis enabled status
    var isAnalysisEnabled: Bool {
        return analysisEnabled
    }
    
    /// Quick access to SCSA data enabled status
    var isSCSADataEnabled: Bool {
        return scsaDataEnabled
    }
    
    /// Quick access to Claude AI enabled status
    var isClaudeAIEnabled: Bool {
        return claudeAIEnabled
    }
}