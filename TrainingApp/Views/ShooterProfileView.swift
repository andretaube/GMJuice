import SwiftUI
import SwiftData

struct ShooterProfileView: View {
    @Environment(\.modelContext) private var context
    // We always want exactly one profile; fetch “all” and then ensure one.
    @Query private var profiles: [ShooterProfile]

    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        let p = ensureProfile()
        @Bindable var profile = p

        Form {
            Section("Membership") {
                TextField("USPSA Number (e.g., A12345)", text: $profile.uspsaNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: profile.uspsaNumber, initial: false) {
                        debouncedSave()
                    }
            }

            Section("Divisions & Class") {
                ForEach(Array(Division.allCases), id: \.self) { div in
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
        }
        .navigationTitle("Shooter Profile")
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
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
