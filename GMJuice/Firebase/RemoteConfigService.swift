//
//  RemoteConfigService.swift
//  GMJuice
//
//  Firebase Remote Config — kept lean: a single SCSA kill-switch so the
//  (fragile) scsa.org scraping can be disabled remotely without an app update.
//  Peak benchmark data lives in PeakBenchmarksService.
//

import Foundation
import FirebaseCore
import FirebaseRemoteConfig
import Combine

// MARK: - Remote Config Keys

enum RemoteConfigKey: String, CaseIterable {
    case scsaDataEnabled = "SCSADataEnabled"

    var defaultValue: Any {
        switch self {
        case .scsaDataEnabled:
            return true // Default to enabled
        }
    }
}

// MARK: - Remote Config Service

final class RemoteConfigService: ObservableObject {
    static let shared = RemoteConfigService()

    private let remoteConfig: RemoteConfig

    @Published var scsaDataEnabled: Bool = true

    private init() {
        remoteConfig = RemoteConfig.remoteConfig()
        setupDefaults()
    }

    func initialize() async {
        setupDefaults()
        await fetchConfig()
        await updatePublishedValues()
    }

    private func setupDefaults() {
        var defaults: [String: NSObject] = [:]
        for key in RemoteConfigKey.allCases {
            defaults[key.rawValue] = key.defaultValue as? NSObject
        }
        remoteConfig.setDefaults(defaults)

        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings

        print("🔧 Remote Config: Initialized")
    }

    private func fetchConfig() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            switch status {
            case .successFetchedFromRemote:
                print("✅ Remote Config: Fetched from remote")
            case .successUsingPreFetchedData:
                print("✅ Remote Config: Using pre-fetched data")
            case .error:
                print("❌ Remote Config: Fetch failed")
            @unknown default:
                break
            }
        } catch {
            print("❌ Remote Config fetch failed: \(error)")
        }
    }

    @MainActor
    private func updatePublishedValues() {
        scsaDataEnabled = remoteConfig.configValue(forKey: RemoteConfigKey.scsaDataEnabled.rawValue).boolValue
        print("📱 Remote Config — SCSA Data Enabled: \(scsaDataEnabled)")
    }

    func refresh() async {
        await fetchConfig()
        await updatePublishedValues()
    }
}

// MARK: - Convenience

extension RemoteConfigService {
    var isSCSADataEnabled: Bool { scsaDataEnabled }
}
