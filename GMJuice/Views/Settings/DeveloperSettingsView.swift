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
                    Text("This will permanently delete all StringRuns, shots, and profiles. This cannot be undone.")
                }

                if let status = deleteStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Warning: This will delete ALL data from the app, including real training runs.")
            }
        }
        .navigationTitle("Developer Tools")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deleteAllData() {
        do {
            // Delete all StringRuns (cascade will delete StringShots)
            try modelContext.delete(model: StringRun.self)
            try modelContext.delete(model: ShooterProfile.self)
            try modelContext.save()

            deleteStatus = "✓ All data deleted"

            // Clear status after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                deleteStatus = nil
            }
        } catch {
            deleteStatus = "❌ Error: \(error.localizedDescription)"
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
