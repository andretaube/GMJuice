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
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }

            TrainView()
                .tabItem {
                    Label("Train", systemImage: "target")
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
            print("🚀 ========== APP STARTED ==========")
            print("🚀 Total ShooterProfiles in database: \(allProfiles.count)")
            for (index, profile) in allProfiles.enumerated() {
                print("🚀 Profile #\(index + 1): USPSA# \(profile.uspsaNumber)")
                print("   - Divisions: \(profile.divisions.map { $0.division.rawValue }.joined(separator: ", "))")
                print("   - Match scores: \(profile.matchScores.count)")
            }
            print("🚀 Current user USPSA#: \(UserDefaults.standard.currentUserUSPSANumber ?? "none")")

            // Show followed shooters (all profiles except current user, excluding empty profiles)
            let currentUser = UserDefaults.standard.currentUserUSPSANumber
            let followedProfiles = allProfiles.filter { profile in
                !profile.uspsaNumber.isEmpty && profile.uspsaNumber != currentUser
            }
            print("🚀 Followed shooters: \(followedProfiles.map { $0.uspsaNumber })")
            print("🚀 ===================================")

            // Auto-sync current user's profile if needed (24 hour threshold)
            checkAndAutoSyncCurrentUser()
        }
    }

    private func checkAndAutoSyncCurrentUser() {
        guard let currentUserNumber = UserDefaults.standard.currentUserUSPSANumber,
              !currentUserNumber.isEmpty else {
            print("⏭️ No current user set, skipping auto-sync")
            return
        }

        guard let currentUserProfile = allProfiles.first(where: { $0.uspsaNumber == currentUserNumber }) else {
            print("⏭️ Current user profile not found, skipping auto-sync")
            return
        }

        // Check if we need to refresh
        guard let lastSync = currentUserProfile.lastSyncDate else {
            // Never synced, refresh now
            print("🔄 Auto-syncing current user profile (never synced): \(currentUserNumber)")
            performAutoSync(for: currentUserNumber)
            return
        }

        let hoursSinceLastSync = Date().timeIntervalSince(lastSync) / 3600
        if hoursSinceLastSync >= 24 {
            print("🔄 Auto-syncing current user profile (last synced \(String(format: "%.1f", hoursSinceLastSync)) hours ago): \(currentUserNumber)")
            performAutoSync(for: currentUserNumber)
        } else {
            print("⏭️ Skipping auto-sync for current user (last synced \(String(format: "%.1f", hoursSinceLastSync)) hours ago): \(currentUserNumber)")
        }
    }

    private func performAutoSync(for uspsaNumber: String) {
        Task {
            do {
                try await scraper.syncClassificationData(memberNumber: uspsaNumber, context: context)
                print("✅ Auto-sync completed for: \(uspsaNumber)")
            } catch {
                print("❌ Auto-sync failed for \(uspsaNumber): \(error)")
            }
        }
    }
}
