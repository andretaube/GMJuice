//
//  RootTabs.swift
//  GMJuice
//
//  Created by Andre Taube on 10/6/25.
//


import SwiftUI
import SwiftData

struct RootTabs: View {
    @Environment(\.modelContext) private var context
    @Query private var allProfiles: [ShooterProfile]
    @StateObject private var scraper = SCWebScraper.shared

    var body: some View {
        TabView {
            TrainView()
                .tabItem {
                    Label("Train", systemImage: "target")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }

            CoachingHomeView()
                .tabItem {
                    Label("Analysis", systemImage: "chart.bar.xaxis")
                }

            SettingsMainView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onAppear {
            // Auto-sync current user's profile if needed (24 hour threshold)
            checkAndAutoSyncCurrentUser()
        }
    }

    private func checkAndAutoSyncCurrentUser() {
        guard let currentUserNumber = UserDefaults.standard.currentUserUSPSANumber,
              !currentUserNumber.isEmpty else {
            return
        }

        guard let currentUserProfile = allProfiles.first(where: { $0.uspsaNumber == currentUserNumber }) else {
            return
        }

        // Check if we need to refresh
        guard let lastSync = currentUserProfile.lastSyncDate else {
            // Never synced, refresh now
            performAutoSync(for: currentUserNumber)
            return
        }

        let hoursSinceLastSync = Date().timeIntervalSince(lastSync) / 3600
        if hoursSinceLastSync >= 24 {
            performAutoSync(for: currentUserNumber)
        }
    }

    private func performAutoSync(for uspsaNumber: String) {
        Task {
            do {
                try await scraper.syncClassificationData(memberNumber: uspsaNumber, context: context)
            } catch {
                print("❌ Auto-sync failed for \(uspsaNumber): \(error)")
            }
        }
    }
}
