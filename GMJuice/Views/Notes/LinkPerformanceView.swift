import SwiftUI
import SwiftData

struct LinkPerformanceView: View {
    @Bindable var note: SessionNote
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \StringRun.date, order: .reverse) private var allRuns: [StringRun]

    @State private var selectedRunIds: Set<UUID> = []
    @State private var matchName: String = ""
    @State private var matchDate: Date

    init(note: SessionNote) {
        self.note = note
        _matchDate = State(initialValue: note.sessionDate)
    }

    var body: some View {
        NavigationView {
            Form {
                if note.sessionType == "practice" {
                    practiceSessionsSection
                } else {
                    matchResultsSection
                }
            }
            .navigationTitle(note.sessionType == "practice" ? "Link Practice" : "Link Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLinks()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadExistingLinks()
            }
        }
    }

    // MARK: - Practice Sessions Section

    private var practiceSessionsSection: some View {
        Section {
            let nearbyRuns = findNearbyRuns()

            if nearbyRuns.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("No practice sessions found nearby")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("Practice sessions from the same day (±12 hours) will appear here for linking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(nearbyRuns) { run in
                    StringRunRow(
                        run: run,
                        isSelected: selectedRunIds.contains(run.id)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSelection(runId: run.id)
                    }
                }
            }
        } header: {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.blue)
                Text("Practice Sessions")
            }
        } footer: {
            if !findNearbyRuns().isEmpty {
                Text("Select practice strings to link with this note. Shows sessions from ±12 hours of note date.")
                    .font(.caption)
            }
        }
    }

    // MARK: - Match Results Section

    private var matchResultsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Match Name", text: $matchName)
                    .textFieldStyle(.roundedBorder)

                DatePicker(
                    "Match Date",
                    selection: $matchDate,
                    displayedComponents: .date
                )

                if !matchName.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Match info will be saved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            HStack {
                Image(systemName: "trophy")
                    .foregroundStyle(.orange)
                Text("Match Information")
            }
        } footer: {
            Text("Enter the match name and date. You can link specific stage results later when they're available.")
                .font(.caption)
        }
    }

    // MARK: - Helper Methods

    private func findNearbyRuns() -> [StringRun] {
        let calendar = Calendar.current
        let sessionDate = note.sessionDate

        // Get range: sessionDate ± 12 hours
        guard let startDate = calendar.date(byAdding: .hour, value: -12, to: sessionDate),
              let endDate = calendar.date(byAdding: .hour, value: 12, to: sessionDate) else {
            return []
        }

        // Filter runs within the time window
        return allRuns.filter { run in
            run.date >= startDate && run.date <= endDate
        }
    }

    private func loadExistingLinks() {
        // Load existing StringRun links
        selectedRunIds = Set(note.linkedStringRunIds)

        // Load existing match info
        if let name = note.linkedMatchName {
            matchName = name
        }
        if let date = note.linkedMatchDate {
            matchDate = date
        }
    }

    private func toggleSelection(runId: UUID) {
        if selectedRunIds.contains(runId) {
            selectedRunIds.remove(runId)
        } else {
            selectedRunIds.insert(runId)
        }
    }

    private func saveLinks() {
        // Save StringRun links
        note.linkedStringRunIds = Array(selectedRunIds)

        // Save match info
        if !matchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            note.linkedMatchName = matchName
            note.linkedMatchDate = matchDate
        } else {
            note.linkedMatchName = nil
            note.linkedMatchDate = nil
        }

        note.lastModifiedDate = Date()

        do {
            try modelContext.save()
            print("✅ Performance links saved")
        } catch {
            print("❌ Error saving links: \(error)")
        }
    }
}

// MARK: - String Run Row

struct StringRunRow: View {
    let run: StringRun
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .blue : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                // Stage and division
                HStack {
                    if let stage = AllStages.first(where: { $0.code == run.stageId }) {
                        Text(stage.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    if let division = Division.allCases.first(where: { $0.rawValue == run.divisionId }) {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(division.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }

                // Time and shot count
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(String(format: "%.2f", NSDecimalNumber(decimal: run.time).doubleValue))s")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(run.stringShots.count) shots")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Timestamp
                Text(run.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LinkPerformanceView(note: {
        let note = SessionNote(sessionDate: Date(), sessionType: "practice")
        return note
    }())
    .modelContainer(for: [SessionNote.self, StringRun.self], inMemory: true)
}
