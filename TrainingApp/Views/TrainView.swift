//
//  TrainView.swift
//  TrainingApp
//
//  Created by Andre Taube on 10/11/25.
//

import SwiftUI
import Foundation

struct TrainView: View {
    // Persist the user’s selected SCSA division in user preferences
    @AppStorage("scsa_active_division") private var activeDivisionRaw: String = Division.RFPO.rawValue

    // Binding that bridges @AppStorage <-> enum
    private var selectedDivisionBinding: Binding<Division> {
        Binding(
            get: { Division(rawValue: activeDivisionRaw) ?? .RFPO },
            set: { activeDivisionRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                // Top "dropdown" for division selection
                Section {
                    Picker("Division", selection: selectedDivisionBinding) {
                        ForEach(Division.allCases) { div in
                            Text(div.displayName).tag(div)
                        }
                    }
                    .pickerStyle(.menu) // renders as a dropdown in the list
                }

                // Stages
                ForEach(AllStages) { stage in
                    NavigationLink {
                        RecordingView(stage: stage, division: selectedDivisionBinding.wrappedValue)
                    } label: {
                        HStack {
                            Text(stage.code)
                                .font(.headline)
                                .frame(width: 100, alignment: .leading)
                            Text(stage.name)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Train")
        }
    }
}
