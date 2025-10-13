//
//  ShooterProfileView.swift
//  TrainingApp
//
//  Created by Andre Taube on 10/11/25.
//

import SwiftUI
import SwiftData

struct ShooterProfileView: View {
    @Environment(\.modelContext) private var context
    @Query var profiles: [ShooterProfile]

    @State private var profile: ShooterProfile?

    init() {
        _profiles = Query(sort: [])
    }

    var body: some View {
        Form {
            Section("Membership") {
                TextField("USPSA Number (e.g., A12345)", text: Binding(
                    get: { profile?.uspsaNumber ?? "" },
                    set: { new in
                        profile?.uspsaNumber = new
                        autosave()
                    }
                ))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            }

            Section("Divisions & Class") {
                ForEach(Division.allCases) { div in
                    DivisionRow(
                        division: div,
                        dp: Binding(
                            get: { profile?.profile(for: div) },
                            set: { _ in /* handled inside row */ }
                        ),
                        ensure: {
                            let result = profile?.ensureProfile(for: div)
                            autosave()
                            return result
                        },
                        remove: {
                            profile?.removeDivision(div)
                            autosave()
                        }
                    )
                }
            }

            Section("Defaults") {
                Picker("Default Division", selection: Binding(
                    get: { profile?.defaultDivision ?? profile?.divisions.first?.division },
                    set: { newValue in
                        profile?.defaultDivision = newValue
                        autosave()
                    }
                )) {
                    Text("—").tag(Division?.none)
                    ForEach(profile?.divisions.map(\.division) ?? [], id: \.self) { d in
                        Text(d.rawValue).tag(Division?.some(d))
                    }
                }
            }
        }
        .navigationTitle("Shooter Profile")
        .onAppear {
            if let existing = profiles.first {
                profile = existing
            } else {
                let p = ShooterProfile()
                context.insert(p)           // create-on-first-run
                try? context.save()
                profile = p
            }
        }
    }

    // MARK: - Helpers

    private func autosave() {
        // If this is a brand-new profile not yet inserted, insert it first
        if let p = profile, !profiles.contains(where: { $0 === p }) {
            context.insert(p)
        }
        try? context.save()
    }
}

private struct DivisionRow: View {
    @Environment(\.modelContext) private var context

    let division: Division
    @Binding var dp: DivisionProfile?
    let ensure: () -> DivisionProfile?
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(division.displayName, isOn: Binding(
                    get: { dp != nil },
                    set: { isOn in
                        if isOn {
                            _ = ensure()
                        } else {
                            remove()
                        }
                        save()
                    }
                ))
            }
            if let bound = dp {
                HStack {
                    Text("Class")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { bound.classification },
                        set: { newValue in
                            bound.classification = newValue
                            save()
                        }
                    )) {
                        ForEach(ShooterClass.allCases, id: \.self) { cls in
                            Text(cls.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)
                }
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func save() {
        try? context.save()
    }
}
