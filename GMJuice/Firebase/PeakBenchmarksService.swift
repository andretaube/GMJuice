//
//  PeakBenchmarksService.swift
//  GMJuice
//
//  Firebase service for managing PeakBenchmarks data remotely
//

import Foundation
import FirebaseCore
import FirebaseRemoteConfig

/// Service for managing PeakBenchmarks data in Firebase Remote Config
class PeakBenchmarksService: ObservableObject {
    static let shared = PeakBenchmarksService()
    
    private let remoteConfig = RemoteConfig.remoteConfig()
    private let configKey = "PeakData"
    
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var remoteBenchmarks: PeakTable?
    
    private init() {
        configureRemoteConfig()
    }
    
    private func configureRemoteConfig() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0 // For development - fetch every time
        #else
        settings.minimumFetchInterval = 86400 // Production - check daily
        #endif
        remoteConfig.configSettings = settings
        
        // Set default values from local PeakBenchmarks
        setDefaultValues()
        
        // Load cached benchmarks if available
        loadCachedBenchmarks()
    }
    
    private func loadCachedBenchmarks() {
        if let cachedData = UserDefaults.standard.data(forKey: "cached_peak_benchmarks"),
           let cachedBenchmarks = try? JSONDecoder().decode(PeakTable.self, from: cachedData) {
            remoteBenchmarks = cachedBenchmarks
            print("📊 Loaded cached PeakBenchmarks data")
        }
    }
    
    private func cacheBenchmarks(_ benchmarks: PeakTable) {
        if let data = try? JSONEncoder().encode(benchmarks) {
            UserDefaults.standard.set(data, forKey: "cached_peak_benchmarks")
            UserDefaults.standard.set(Date(), forKey: "cached_peak_benchmarks_date")
            print("💾 Cached PeakBenchmarks data")
        }
    }
    
    private func setDefaultValues() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(PeakBenchmarks)
            let jsonString = String(data: data, encoding: .utf8) ?? "{}"
            
            remoteConfig.setDefaults([configKey: jsonString as NSObject])
        } catch {
            print("❌ Failed to set default PeakBenchmarks: \(error)")
        }
    }
    
    /// Initialize the service and fetch remote data
    func initialize() async {
        print("🏆 Initializing PeakBenchmarks service...")
        let _ = await fetchLatestBenchmarks()
        print("🏆 PeakBenchmarks service initialized")
    }
    
    /// Fetch the latest PeakBenchmarks from Firebase
    func fetchLatestBenchmarks() async -> PeakTable? {
        await MainActor.run { isLoading = true }
        
        do {
            let status = try await remoteConfig.fetchAndActivate()
            
            switch status {
            case .successFetchedFromRemote:
                print("✅ PeakBenchmarks: Fetched from remote")
            case .successUsingPreFetchedData:
                print("✅ PeakBenchmarks: Using cached data")
            case .error:
                print("❌ PeakBenchmarks: Fetch failed")
                await MainActor.run { isLoading = false }
                return nil
            @unknown default:
                print("⚠️ PeakBenchmarks: Unknown fetch status")
            }
            
            let benchmarks = parseBenchmarksFromConfig()
            
            await MainActor.run {
                self.remoteBenchmarks = benchmarks
                self.lastUpdated = Date()
                self.isLoading = false
            }
            
            // Cache the benchmarks if successfully parsed
            if let benchmarks = benchmarks {
                cacheBenchmarks(benchmarks)
            }
            
            return benchmarks
            
        } catch {
            print("❌ PeakBenchmarks fetch failed: \(error)")
            await MainActor.run { isLoading = false }
            return nil
        }
    }
    
    private func parseBenchmarksFromConfig() -> PeakTable? {
        let jsonString = remoteConfig.configValue(forKey: configKey).stringValue
        guard !jsonString.isEmpty else {
            print("⚠️ No PeakBenchmarks data in Remote Config")
            return nil
        }
        
        do {
            let data = Data(jsonString.utf8)
            let decoder = JSONDecoder()
            let benchmarks = try decoder.decode(PeakTable.self, from: data)
            print("✅ Successfully parsed PeakBenchmarks from Remote Config")
            return benchmarks
        } catch {
            print("❌ Failed to parse PeakBenchmarks: \(error)")
            return nil
        }
    }
    
    /// Get current benchmarks (remote if available, local fallback)
    func getCurrentBenchmarks() -> PeakTable {
        return remoteBenchmarks ?? PeakBenchmarks
    }
    
    /// Check if remote data is available
    var hasRemoteData: Bool {
        return remoteBenchmarks != nil
    }
    
    /// Get data age for display purposes
    var dataAge: String? {
        guard let lastUpdated = lastUpdated else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
}

// MARK: - Upload Utility (for development/admin use)

#if DEBUG
extension PeakBenchmarksService {
    
    /// Upload current local PeakBenchmarks to Firebase Remote Config
    /// Note: This requires Firebase Console access to publish the data
    func uploadCurrentBenchmarks() async -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(PeakBenchmarks)
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📤 PeakBenchmarks JSON for Firebase Remote Config:")
                print("Key: \(configKey)")
                print("Value:")
                print(jsonString)
                print("\n🔧 Copy this JSON to Firebase Console > Remote Config > \(configKey)")
                return true
            }
            
        } catch {
            print("❌ Failed to encode PeakBenchmarks: \(error)")
        }
        
        return false
    }
    
    /// Generate formatted JSON for easy copying to Firebase Console
    func generateFirebaseJSON() -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(PeakBenchmarks)
            return String(data: data, encoding: .utf8)
        } catch {
            print("❌ Failed to generate JSON: \(error)")
            return nil
        }
    }
    
    /// Debug function to compare local vs remote benchmarks
    func debugCompareBenchmarks() {
        print("🔍 PeakBenchmarks Status:")
        print("  • Remote data available: \(hasRemoteData)")
        print("  • Last updated: \(dataAge ?? "Never")")
        print("  • Using: \(hasRemoteData ? "Remote Firebase data" : "Local fallback data")")
        
        let current = getCurrentBenchmarks()
        
        // Count total benchmarks across all divisions
        var totalCount = 0
        for division in Division.allCases {
            for stage in AllStages {
                if current.get(division: division, stageCode: stage.code) != nil {
                    totalCount += 1
                }
            }
        }
        print("  • Total benchmarks: \(totalCount)")
        
        // Show sample of data
        print("  • Sample benchmarks:")
        let sampleStages = Array(AllStages.prefix(3))
        let sampleDivisions = Array(Division.allCases.prefix(2))
        
        for stage in sampleStages {
            for division in sampleDivisions {
                if let benchmark = current.get(division: division, stageCode: stage.code) {
                    print("    - \(stage.code) \(division.rawValue): \(benchmark.peakTime)s")
                }
            }
        }
    }
}
#endif