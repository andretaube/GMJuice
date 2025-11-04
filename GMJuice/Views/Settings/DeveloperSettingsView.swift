#if DEBUG
import SwiftUI
import SwiftData

struct DeveloperSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirmation = false
    @State private var showingGenerateSheet = false
    @State private var deleteStatus: String?

    @Query private var allRuns: [StringRun]
    @Query private var allProfiles: [ShooterProfile]
    @Query private var allMatchScores: [SCMatchScore]

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Debug Mode Only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Current Data") {
                HStack {
                    Text("String Runs")
                    Spacer()
                    Text("\(allRuns.count)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Shooter Profiles")
                    Spacer()
                    Text("\(allProfiles.count)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("SC Match Scores")
                    Spacer()
                    Text("\(allMatchScores.count)")
                        .foregroundColor(.secondary)
                }
            }

            Section("Test Data Generation") {
                Button {
                    showingGenerateSheet = true
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.blue)
                        Text("Generate Test Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .sheet(isPresented: $showingGenerateSheet) {
                    GenerateTestDataView()
                }
            }

            Section("SCSA Integration") {
                NavigationLink {
                    SCSADebugView()
                } label: {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.purple)
                        Text("Test SCSA Scraper")
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete All Data")
                    }
                }
                .confirmationDialog(
                    "Delete All Data?",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Everything", role: .destructive) {
                        deleteAllData()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete:\n• All training runs and shots\n• All shooter profiles and classifications\n• All match scores\n• All videos\n• All preferences and settings\n• All pending notifications\n\nThis cannot be undone.")
                }

                if let status = deleteStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Warning: This will delete ALL data from the app, including real training runs and videos.")
            }
        }
        .navigationTitle("Developer Tools")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deleteAllData() {
        do {
            // Delete all SwiftData models
            try modelContext.delete(model: StringRun.self)  // Cascade will delete StringShots
            try modelContext.delete(model: ShooterProfile.self)  // Cascade will delete DivisionProfiles
            try modelContext.delete(model: SCMatchScore.self)
            try modelContext.save()

            // Delete all video files
            deleteAllVideos()

            // Clear all UserDefaults preferences
            clearAllUserDefaults()

            // Cancel all pending notifications
            NotificationManager.shared.cancelAllNotifications()

            deleteStatus = "✓ All data deleted"

            // Clear status after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                deleteStatus = nil
            }
        } catch {
            deleteStatus = "❌ Error: \(error.localizedDescription)"
        }
    }

    private func clearAllUserDefaults() {
        let defaults = UserDefaults.standard

        // BLE settings
        defaults.removeObject(forKey: "ble_saved_uuid")
        defaults.removeObject(forKey: "ble_saved_name")

        // Announcer settings
        defaults.removeObject(forKey: "announcer_enabled")
        defaults.removeObject(forKey: "announcer_speak_on_silent")
        defaults.removeObject(forKey: "announcer_voice_identifier")

        // Notification settings
        defaults.removeObject(forKey: "weekly_notification_enabled")
        defaults.removeObject(forKey: "weekly_notification_day")
        defaults.removeObject(forKey: "weekly_notification_hour")
        defaults.removeObject(forKey: "daily_notification_enabled")
        defaults.removeObject(forKey: "daily_notification_hour")
        defaults.removeObject(forKey: "daily_notification_days")

        // SCSA/USPSA settings
        defaults.removeObject(forKey: "scsa_auto_sync_enabled")
        defaults.removeObject(forKey: "scsa_last_sync")
        defaults.removeObject(forKey: "uspsa_api_key")
        defaults.removeObject(forKey: "uspsa_last_sync")

        // App settings
        defaults.removeObject(forKey: "scsa_active_division")
        defaults.removeObject(forKey: "appearanceMode")
        defaults.removeObject(forKey: "hasAcceptedTerms")
        defaults.removeObject(forKey: "termsAcceptedDate")
        defaults.removeObject(forKey: "hasSeenSCSAOnboarding")

        print("✅ Cleared all UserDefaults preferences")
    }

    private func deleteAllVideos() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ Documents directory not found")
            return
        }

        let videosDirectory = documentsPath.appendingPathComponent("Videos")

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: videosDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            var deletedCount = 0
            for fileURL in fileURLs {
                if fileURL.pathExtension == "mov" || fileURL.pathExtension == "mp4" {
                    try FileManager.default.removeItem(at: fileURL)
                    deletedCount += 1
                }
            }

            print("✅ Deleted \(deletedCount) video(s)")
        } catch {
            print("⚠️ Error deleting videos: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperSettingsView()
            .modelContainer(for: [StringRun.self, ShooterProfile.self])
    }
}
#endif
