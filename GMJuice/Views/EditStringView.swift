//
//  EditStringView.swift
//  GMJuice
//
//  String editor for modifying shots, hits/misses, and time
//

import SwiftUI
import SwiftData

struct EditStringView: View {
    let run: StringRun

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var editableTime: String = ""
    @FocusState private var isTimeFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                // Time adjustment section
                Section {
                    HStack {
                        Text("Total Time:")
                            .font(.headline)

                        TextField("Time", text: $editableTime)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.title2.bold())
                            .monospacedDigit()
                            .focused($isTimeFieldFocused)
                    }
                } header: {
                    Text("Time")
                } footer: {
                    Text("Enter time in seconds (e.g., 2.45)")
                }

                // Targets section
                Section {
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { target in
                            targetButton(for: target)
                        }
                    }
                } header: {
                    Text("Targets")
                } footer: {
                    Text("Tap targets to mark as hit or miss")
                }

                // Shots section
                Section {
                    ForEach(run.orderedStringShots) { shot in
                        shotRow(for: shot)
                    }
                } header: {
                    Text("Shots (\(run.stringShots.count))")
                } footer: {
                    if run.stringShots.count > 5 {
                        Text("You can delete makeup shots by swiping left")
                    }
                }
            }
            .navigationTitle("Edit String")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveTimeChange()
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isTimeFieldFocused = false
                    }
                }
            }
            .onAppear {
                editableTime = "\(run.time)"
            }
        }
    }

    @ViewBuilder
    private func shotRow(for shot: StringShot) -> some View {
        HStack(spacing: 16) {
            // Shot number
            let shotIndex = run.orderedStringShots.firstIndex(where: { $0.id == shot.id }) ?? 0
            Text("#\(shotIndex + 1)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            // Times
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Time:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Format.formatTime(shot.now))
                        .font(.headline)
                        .monospacedDigit()
                }

                HStack {
                    Text("Split:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Format.formatTime(shot.split))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if run.stringShots.count > 5 {
                Button(role: .destructive) {
                    deleteShot(shot)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func targetButton(for target: Int) -> some View {
        let isMissed = run.missedTargets.contains(target)
        let isStopPlate = target == 5

        return Button {
            toggleTargetMiss(target)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isMissed ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: isStopPlate ? 28 : 20))
                    .foregroundColor(isMissed ? .red : .green)

                Text(isStopPlate ? "Stop" : "\(target)")
                    .font(isStopPlate ? .caption.bold() : .caption2)
            }
            .frame(width: isStopPlate ? 60 : 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isMissed ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isMissed ? Color.red : Color.green, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func toggleTargetMiss(_ target: Int) {
        // Toggle target in missedTargets array
        if let index = run.missedTargets.firstIndex(of: target) {
            // Target was marked as miss, mark as hit
            run.missedTargets.remove(at: index)
        } else {
            // Target was marked as hit, mark as miss
            run.missedTargets.append(target)
        }

        do {
            try modelContext.save()
            let status = run.missedTargets.contains(target) ? "MISS" : "HIT"
            print("✓ Toggled target \(target) to \(status)")
        } catch {
            print("❌ Failed to save: \(error)")
        }
    }

    private func deleteShot(_ shot: StringShot) {
        withAnimation {
            run.stringShots.removeAll { $0.id == shot.id }

            do {
                try modelContext.save()
                print("✓ Deleted shot \(shot.now)s")
            } catch {
                print("❌ Failed to delete shot: \(error)")
            }
        }
    }

    private func saveTimeChange() {
        if let newTime = Decimal(string: editableTime) {
            run.time = newTime

            do {
                try modelContext.save()
                print("✓ Updated time to \(newTime)s")
            } catch {
                print("❌ Failed to save time: \(error)")
            }
        }
    }
}

#Preview {
    let container: ModelContainer = {
        let schema = Schema(versionedSchema: Schema004.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])

        let run = StringRun(stageId: "SC-101", divisionId: "RFPO")
        run.time = 2.45
        run.missedTargets = [3]  // Missed target 3
        run.stringShots = [
            StringShot(now: 0.45, split: 0.45, first: 0.45),
            StringShot(now: 0.92, split: 0.47, first: 0.45),
            StringShot(now: 1.38, split: 0.46, first: 0.45),
            StringShot(now: 1.84, split: 0.46, first: 0.45),
            StringShot(now: 2.45, split: 0.61, first: 0.45),
        ]

        container.mainContext.insert(run)
        return container
    }()

    let run = StringRun(stageId: "SC-101", divisionId: "RFPO")

    EditStringView(run: run)
        .modelContainer(container)
}
