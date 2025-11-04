import SwiftUI
import SwiftData

struct ShooterProfileView: View {
    @Environment(\.modelContext) private var context
    // We always want exactly one profile; fetch "all" and then ensure one.
    @Query private var profiles: [ShooterProfile]

    @State private var saveTask: Task<Void, Never>?
    @StateObject private var scraper = SCWebScraper.shared
    @State private var showingError = false
    @State private var errorMessage = ""
    @AppStorage("scsa_auto_sync_enabled") private var autoSyncEnabled = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        let p = ensureProfile()
        @Bindable var profile = p

        NavigationStack {
            Form {
                Section {
                    TextField("SCSA Member Number", text: $profile.uspsaNumber)
                        .textContentType(.username)
                        .autocapitalization(.allCharacters)
                        .onChange(of: profile.uspsaNumber) { _, _ in
                            debouncedSave()
                        }

                    if !profile.uspsaNumber.isEmpty {
                        Toggle("Keep my info up to date automatically", isOn: $autoSyncEnabled)
                            .font(.subheadline)

                        if autoSyncEnabled, let lastSync = scraper.lastSyncDate {
                            Text("Last synced: \(lastSync, format: .relative(presentation: .named))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else if autoSyncEnabled {
                            Text("Never synced")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("SCSA Member")
                } footer: {
                    if !profile.uspsaNumber.isEmpty && autoSyncEnabled {
                        Text("Your classification data will sync automatically when you open the app. SCSA updates scores on Wednesdays.")
                            .font(.caption2)
                    }
                }

                Section("Divisions & Class") {
                    ForEach(sortedDivisions(profile: profile), id: \.self) { div in
                        DivisionRow(
                            division: div,
                            // Pass the optional DivisionProfile for this division
                            dp: profile.profile(for: div),
                            ensure: {
                                let r = profile.ensureProfile(for: div)
                                debouncedSave()
                                return r
                            },
                            remove: {
                                profile.removeDivision(div)
                                debouncedSave()
                            },
                            saveNow: { saveNow() }
                        )
                    }
                }

                if !profile.uspsaNumber.isEmpty {
                    Section {
                        Button {
                            Task {
                                await syncClassificationData(profile: profile)
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if scraper.isScraping {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                }
                                Text("Refresh my data")
                                    .font(.caption)
                                Spacer()
                            }
                        }
                        .disabled(scraper.isScraping)
                    }
                }

                // Delete All Data Section
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete All My Data")
                        }
                    }
                } header: {
                    Text("Danger Zone")
                        .foregroundStyle(.red)
                } footer: {
                    Text("This will permanently remove all your training data, videos, match scores, and settings from the app.")
                        .font(.caption)
                }
            }
            .navigationTitle("Shooter Profile")
            .confirmationDialog(
                "Delete All Data?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("I understand - Delete Everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete all your data?\n\nThis will permanently remove:\n• All training runs and shots\n• All videos\n• All match scores and classifications\n• All settings and preferences\n\nThis action cannot be undone.")
            }
            .alert("Sync Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // Sync classification data from SCSA website
    private func syncClassificationData(profile: ShooterProfile) async {
        guard !profile.uspsaNumber.isEmpty else {
            errorMessage = "Please enter your SCSA member number first"
            showingError = true
            return
        }

        do {
            try await scraper.syncClassificationData(memberNumber: profile.uspsaNumber, context: context)
        } catch let error as NSError where error.code == 404 {
            // Use the specific error message from the scraper
            errorMessage = error.localizedDescription
            showingError = true
        } catch let error as NSError where error.code == 403 {
            errorMessage = "Access denied by SCSA website. This is usually temporary. Please try again in a few minutes."
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    // Delete all data from the app
    private func deleteAllData() {
        do {
            // Delete all SwiftData models
            try context.delete(model: StringRun.self)  // Cascade will delete StringShots
            try context.delete(model: ShooterProfile.self)  // Cascade will delete DivisionProfiles
            try context.delete(model: SCMatchScore.self)
            try context.save()

            // Delete all video files
            deleteAllVideos()

            // Clear all UserDefaults preferences
            clearAllUserDefaults()

            // Cancel all pending notifications
            NotificationManager.shared.cancelAllNotifications()

            print("✅ All data deleted successfully")
        } catch {
            errorMessage = "Failed to delete data: \(error.localizedDescription)"
            showingError = true
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

    // Ensure single instance; also clean up accidental duplicates
    @MainActor
    private func ensureProfile() -> ShooterProfile {
        if let first = profiles.first {
            if profiles.count > 1 {
                for extra in profiles.dropFirst() { context.delete(extra) }
                do { try context.save() } catch { print("Cleanup save failed: \(error)") }
            }
            return first
        }
        let created = ShooterProfile()
        context.insert(created)
        do { try context.save() } catch { print("Initial save failed: \(error)") }
        return created
    }

    // Debounced save
    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            saveNow()
        }
    }

    private func saveNow() {
        do { try context.save() } catch { print("Save failed: \(error)") }
    }

    // Sort divisions: show ones with classifications first, highest first
    private func sortedDivisions(profile: ShooterProfile) -> [Division] {
        let allDivisions = Division.allCases

        return allDivisions.sorted { div1, div2 in
            let dp1 = profile.profile(for: div1)
            let dp2 = profile.profile(for: div2)

            // If one has a profile and the other doesn't, show the one with profile first
            if dp1 != nil && dp2 == nil {
                return true
            }
            if dp1 == nil && dp2 != nil {
                return false
            }

            // If both have profiles, sort by classification (higher rank first)
            if let p1 = dp1, let p2 = dp2 {
                return p1.classification > p2.classification
            }

            // If neither has a profile, maintain original order
            return false
        }
    }
}

private struct DivisionRow: View {
    @Environment(\.modelContext) private var context

    let division: Division
    // Optional model instance for this division
    var dp: DivisionProfile?
    let ensure: () -> DivisionProfile
    let remove: () -> Void
    let saveNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(division.displayName, isOn: Binding(
                get: { dp != nil },
                set: { isOn in
                    if isOn {
                        _ = ensure()
                    } else {
                        remove()
                    }
                    saveNow()
                }
            ))

            if let bound = dp {
                // Bind to the concrete model
                @Bindable var b = bound
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Class")
                        Spacer()
                        Picker("", selection: $b.classification) {
                            ForEach(ShooterClass.allCases) { cls in
                                Text(cls.rawValue.uppercased()).tag(cls)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 320)
                    }

                    // Show classification data from SCSA if available
                    if let currentPct = bound.currentPercentage {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                Text("\(NSDecimalNumber(decimal: currentPct).doubleValue, specifier: "%.2f")%")
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)

                            if let highPct = bound.highPercentage {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                    Text("\(NSDecimalNumber(decimal: highPct).doubleValue, specifier: "%.2f")%")
                                }
                                .font(.caption)
                                .foregroundStyle(.orange)
                            }

                            if let date = bound.classificationDate {
                                Text(date, format: Date.FormatStyle().month(.abbreviated).day().year())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let schema = Schema(versionedSchema: Schema004.self)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    return NavigationStack {
        ShooterProfileView()
    }
    .modelContainer(container)
}
