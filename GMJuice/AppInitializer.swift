//
//  AppInitializer.swift
//  GMJuice
//
//  Created by Andre Taube on 10/8/25.
//


import SwiftUI
import SwiftData

@MainActor
final class AppInitializer: ObservableObject {
    @Published var isReady = false

    func start(modelContext: ModelContext) {
        // Kick off your startup work
        Task {
            // Initialize Firebase Remote Config
            await RemoteConfigService.shared.initialize()

            // Initialize Peak Benchmarks from Firebase
            await PeakBenchmarksService.shared.initialize()

            // Request notification permissions
            await NotificationManager.shared.requestPermission()
            await NotificationManager.shared.checkAuthorizationStatus()

            // Auto-sync SCSA data if enabled
            await autoSyncSCSA(modelContext: modelContext)

            // Update Crashlytics with user stats for debugging
            updateCrashlyticsUserStats(modelContext: modelContext)

            withAnimation(.easeInOut(duration: 0.35)) {
                self.isReady = true
            }
        }
    }

    private func autoSyncSCSA(modelContext: ModelContext) async {
        // Check if SCSA data is enabled via Remote Config
        guard RemoteConfigService.shared.isSCSADataEnabled else {
            print("🚫 SCSA auto-sync disabled via Remote Config")
            return
        }
        
        // Check if auto-sync is enabled
        let autoSyncEnabled = UserDefaults.standard.bool(forKey: "scsa_auto_sync_enabled")
        guard autoSyncEnabled else {
            return
        }

        // Get shooter profile and member number
        let descriptor = FetchDescriptor<ShooterProfile>()
        guard let profile = try? modelContext.fetch(descriptor).first,
              !profile.uspsaNumber.isEmpty else {
            return
        }

        // Auto-sync if needed
        do {
            if SCWebScraper.shared.shouldSync() {
                try await SCWebScraper.shared.syncClassificationData(
                    memberNumber: profile.uspsaNumber,
                    context: modelContext
                )
            }
        } catch {
            print("⚠️ Auto-sync failed: \(error.localizedDescription)")
        }
    }

    private func updateCrashlyticsUserStats(modelContext: ModelContext) {
        do {
            // Count log entries (StringRuns)
            let runsDescriptor = FetchDescriptor<StringRun>()
            let runs = try modelContext.fetch(runsDescriptor)
            let logEntryCount = runs.count

            // Count unique divisions used
            let divisionsUsed = Set(runs.map { $0.divisionId }).count

            // Count unique stages used
            let stagesUsed = Set(runs.map { $0.stageId }).count

            // Send to Crashlytics
            AnalyticsService.shared.setUserStats(
                logEntryCount: logEntryCount,
                divisionsUsed: divisionsUsed,
                stagesUsed: stagesUsed
            )

            print("📊 Crashlytics stats updated: \(logEntryCount) logs, \(divisionsUsed) divisions, \(stagesUsed) stages")
        } catch {
            print("⚠️ Failed to update Crashlytics stats: \(error)")
        }
    }
}
