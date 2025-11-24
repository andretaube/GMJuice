//
//  USPSANumberSheet.swift
//  GMJuice
//
//  Created by Claude on 11/8/25.
//

import SwiftUI
import SwiftData

struct USPSANumberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @StateObject private var scraper = SCWebScraper.shared
    @StateObject private var remoteConfig = RemoteConfigService.shared

    @Bindable var profile: ShooterProfile
    let isEditable: Bool
    var onUnfollow: (() -> Void)?

    @State private var editedNumber: String = ""
    @State private var isRefreshing = false
    @State private var showingError = false
    @State private var errorMessage: String?

    init(profile: ShooterProfile, isEditable: Bool = true, onUnfollow: (() -> Void)? = nil) {
        self.profile = profile
        self.isEditable = isEditable
        self.onUnfollow = onUnfollow
        _editedNumber = State(initialValue: profile.uspsaNumber)
    }

    private var lastSyncText: String {
        guard let lastSync = profile.lastSyncDate else {
            return "Never synced"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
    }

    private var canRefresh: Bool {
        #if DEBUG
        // In debug mode, always allow refresh
        return !isRefreshing && !profile.uspsaNumber.isEmpty
        #else
        // In production, only allow refresh once per hour
        guard !isRefreshing && !profile.uspsaNumber.isEmpty else {
            return false
        }

        // Check last manual refresh time
        let lastRefreshKey = "last_manual_refresh_\(profile.uspsaNumber)"
        if let lastRefresh = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date {
            let hoursSinceLastRefresh = Date().timeIntervalSince(lastRefresh) / 3600
            return hoursSinceLastRefresh >= 1.0
        }

        // Never manually refreshed, allow it
        return true
        #endif
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isEditable {
                        TextField("SCSA Member Number", text: $editedNumber)
                            .textContentType(.username)
                            .autocapitalization(.allCharacters)
                            .disabled(isRefreshing)
                    } else {
                        HStack {
                            Text("SCSA Member Number")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(profile.uspsaNumber)
                                .fontWeight(.medium)
                        }
                    }
                } header: {
                    Text("Profile")
                } footer: {
                    if isEditable {
                        Text("Your SCSA member number is used to sync your classification data")
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text(lastSyncText)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if remoteConfig.isSCSADataEnabled {
                            if isRefreshing {
                                ProgressView()
                            } else {
                                Button(action: refreshProfile) {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                                .disabled(!canRefresh)
                            }
                        }
                    }
                } header: {
                    Text("Sync Status")
                } footer: {
                    if remoteConfig.isSCSADataEnabled {
                        #if DEBUG
                        Text("Profile data is automatically refreshed every 24 hours")
                        #else
                        Text("Profile data is automatically refreshed every 24 hours. Manual refresh is limited to once per hour.")
                        #endif
                    } else {
                        Text("SCSA data refresh is currently not available, please check again later")
                            .foregroundStyle(.orange)
                    }
                }

                // Division visibility toggles
                if !profile.divisions.isEmpty {
                    Section {
                        ForEach(profile.divisions.sorted(by: { $0.division.rawValue < $1.division.rawValue }), id: \.division) { divProfile in
                            Toggle(isOn: Binding(
                                get: { divProfile.isVisible },
                                set: { newValue in
                                    divProfile.isVisible = newValue
                                    do {
                                        try context.save()
                                    } catch {
                                        print("Error saving division visibility: \(error)")
                                    }
                                }
                            )) {
                                HStack {
                                    Text(divProfile.division.rawValue)
                                        .fontWeight(.medium)
                                    if let classification = divProfile.classification.rawValue as String?, classification != "U" {
                                        Text("(\(classification))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Visible Divisions")
                    } footer: {
                        Text("Choose which divisions to show in your profile and comparisons")
                    }
                }

                // Unfollow section - only show when viewing someone else's profile
                if !isEditable, let onUnfollow = onUnfollow {
                    Section {
                        Button(role: .destructive) {
                            dismiss()
                            onUnfollow()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Unfollow", systemImage: "person.fill.xmark")
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("Remove this shooter from your following list. This will delete their profile and all saved data.")
                    }
                }
            }
            .navigationTitle(isEditable ? "Edit Profile" : "Profile Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                    .disabled(isRefreshing)
                }

                if isEditable {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveProfile()
                        }
                        .disabled(editedNumber.trimmingCharacters(in: .whitespaces).isEmpty || isRefreshing)
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func saveProfile() {
        let trimmedNumber = editedNumber.trimmingCharacters(in: .whitespaces)

        guard !trimmedNumber.isEmpty else {
            return
        }

        // If number hasn't changed, just dismiss
        if trimmedNumber == profile.uspsaNumber {
            dismiss()
            return
        }

        // Update the profile
        profile.uspsaNumber = trimmedNumber

        // Save context
        do {
            try context.save()

            // Also update UserDefaults if this is the current user
            if UserDefaults.standard.currentUserUSPSANumber == profile.uspsaNumber || UserDefaults.standard.currentUserUSPSANumber == nil {
                UserDefaults.standard.currentUserUSPSANumber = trimmedNumber
            }

            // Sync data before dismissing
            isRefreshing = true

            Task {
                do {
                    // Check if SCSA data is enabled via Remote Config
                    guard RemoteConfigService.shared.isSCSADataEnabled else {
                        await MainActor.run {
                            errorMessage = "SCSA data import is currently disabled"
                            showingError = true
                            isRefreshing = false
                        }
                        return
                    }
                    
                    print("🔄 Syncing profile data for new USPSA number: \(trimmedNumber)")
                    try await scraper.syncClassificationData(memberNumber: trimmedNumber, context: context)

                    await MainActor.run {
                        print("✅ Successfully synced profile data")
                        isRefreshing = false
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        print("❌ Error syncing profile: \(error)")
                        errorMessage = "Failed to sync profile data: \(error.localizedDescription)"
                        showingError = true
                        isRefreshing = false
                        // Don't dismiss on error - let user see the error and try again
                    }
                }
            }
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func refreshProfile() {
        guard !profile.uspsaNumber.isEmpty else { return }

        isRefreshing = true

        // Record the manual refresh timestamp
        let lastRefreshKey = "last_manual_refresh_\(profile.uspsaNumber)"
        UserDefaults.standard.set(Date(), forKey: lastRefreshKey)

        Task {
            do {
                // Check if SCSA data is enabled via Remote Config
                guard RemoteConfigService.shared.isSCSADataEnabled else {
                    await MainActor.run {
                        errorMessage = "SCSA data refresh is currently disabled"
                        showingError = true
                        isRefreshing = false
                    }
                    return
                }
                
                print("🔄 Refreshing profile for: \(profile.uspsaNumber)")
                try await scraper.syncClassificationData(memberNumber: profile.uspsaNumber, context: context)

                await MainActor.run {
                    print("✅ Successfully refreshed profile: \(profile.uspsaNumber)")
                    isRefreshing = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Error refreshing profile: \(error)")
                    errorMessage = "Failed to refresh profile: \(error.localizedDescription)"
                    showingError = true
                    isRefreshing = false
                }
            }
        }
    }
}
