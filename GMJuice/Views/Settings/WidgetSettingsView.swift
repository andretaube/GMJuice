//
//  WidgetSettingsView.swift
//  GMJuice
//
//  Created by Claude on 11/6/25.
//

import SwiftUI
import SwiftData
import WidgetKit

struct WidgetSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var availableDivisions: [Division] = []
    @State private var selectedDivisions: Set<String> = []
    @State private var rotationInterval: WidgetRotationInterval = .every15Minutes
    @State private var stageDisplayMode: StageDisplayMode = .classification

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Home screen widgets display your classification data at a glance without opening the app.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("To add a widget:")
                            .font(.callout)
                            .fontWeight(.semibold)

                        Text("1. Long-press on your home screen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("2. Tap the \"+\" button in the top corner")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("3. Search for \"GMJuice\"")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("4. Select your preferred widget size")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("5. Tap \"Add Widget\"")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    Text("Configure which divisions and data to display in your widgets below.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About Widgets")
            }

            Section {
                if availableDivisions.isEmpty {
                    Text("No divisions with match data")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableDivisions, id: \.rawValue) { division in
                        Toggle(isOn: binding(for: division)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(division.rawValue)
                                    .font(.headline)
                                Text(division.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !selectedDivisions.isEmpty {
                        Button("Select All") {
                            selectedDivisions = Set(availableDivisions.map { $0.rawValue })
                            saveSettings()
                        }
                        .foregroundStyle(.blue)

                        Button("Clear All") {
                            selectedDivisions.removeAll()
                            saveSettings()
                        }
                        .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("Divisions to Display")
            } footer: {
                if selectedDivisions.isEmpty {
                    Text("All divisions with data will be shown")
                } else {
                    Text("\(selectedDivisions.count) division(s) selected")
                }
            }

            Section {
                Picker("Rotate Divisions", selection: $rotationInterval) {
                    ForEach(WidgetRotationInterval.allCases, id: \.self) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .onChange(of: rotationInterval) { _, _ in
                    saveSettings()
                }
            } header: {
                Text("Rotation")
            } footer: {
                Text("How often to switch between selected divisions in the widget")
            }

            Section {
                Picker("Display Mode", selection: $stageDisplayMode) {
                    ForEach(StageDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .onChange(of: stageDisplayMode) { _, _ in
                    saveSettings()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Class:")
                            .foregroundStyle(.secondary)
                        Text("Shows GM, M, A, B, C, etc.")
                    }
                    HStack {
                        Text("Percent:")
                            .foregroundStyle(.secondary)
                        Text("Shows 97.50%, 89.25%, etc.")
                    }
                    HStack {
                        Text("Time:")
                            .foregroundStyle(.secondary)
                        Text("Shows 8.95s, 7.65s, etc.")
                    }
                    HStack {
                        Text("All:")
                            .foregroundStyle(.secondary)
                        Text("Rotates between all three every few seconds")
                    }
                }
                .font(.caption)
            } header: {
                Text("Stage Performance Display")
            } footer: {
                Text("Green border indicates your best stage, red indicates your worst")
            }
        }
        .navigationTitle("Widget Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAvailableDivisions()
            loadSettings()
        }
    }

    private func binding(for division: Division) -> Binding<Bool> {
        Binding(
            get: { selectedDivisions.contains(division.rawValue) },
            set: { isSelected in
                if isSelected {
                    selectedDivisions.insert(division.rawValue)
                } else {
                    selectedDivisions.remove(division.rawValue)
                }
                saveSettings()
            }
        )
    }

    private func loadAvailableDivisions() {
        do {
            // Fetch divisions that have match data
            let scoresDescriptor = FetchDescriptor<MatchScore>()
            let allScores = try modelContext.fetch(scoresDescriptor)

            let divisionCodes = Set(allScores.map { $0.divisionCode })
            availableDivisions = Division.allCases.filter { divisionCodes.contains($0.rawValue) }
                .sorted { $0.rawValue < $1.rawValue }
        } catch {
            print("Error loading divisions: \(error)")
        }
    }

    private func loadSettings() {
        let settings = WidgetSettings.shared
        let savedDivisions = settings.selectedDivisions
        selectedDivisions = Set(savedDivisions)
        rotationInterval = settings.rotationInterval
        stageDisplayMode = settings.stageDisplayMode
    }

    private func saveSettings() {
        let settings = WidgetSettings.shared
        settings.selectedDivisions = Array(selectedDivisions)
        settings.rotationInterval = rotationInterval
        settings.stageDisplayMode = stageDisplayMode

        // Trigger widget reload
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    let schema = Schema(versionedSchema: Schema004.self)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: [config])

    return NavigationStack {
        WidgetSettingsView()
    }
    .modelContainer(container)
}
