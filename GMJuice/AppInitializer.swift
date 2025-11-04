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
            // Simulate work: config, auth, DB migrations, warm caches, etc.
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Request notification permissions
            await NotificationManager.shared.requestPermission()
            await NotificationManager.shared.checkAuthorizationStatus()

            // Auto-sync SCSA data if enabled
            await autoSyncSCSA(modelContext: modelContext)

            withAnimation(.easeInOut(duration: 0.35)) {
                self.isReady = true
            }
        }
    }

    private func autoSyncSCSA(modelContext: ModelContext) async {
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
}
