//
//  TrainView.swift
//  GMJuice
//
//  Created by Andre Taube on 10/11/25.
//

import SwiftUI
import Foundation

struct TrainView: View {
    // Persist the user's selected SCSA division in user preferences
    @AppStorage("scsa_active_division") private var activeDivisionRaw: String = Division.RFPO.rawValue

    @State private var navigationPath = NavigationPath()

    // Binding that bridges @AppStorage <-> enum
    private var selectedDivisionBinding: Binding<Division> {
        Binding(
            get: { Division(rawValue: activeDivisionRaw) ?? .RFPO },
            set: { activeDivisionRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.code)
                                .font(.headline)
                            Text(stage.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        // Video button
                        Button {
                            navigationPath.append(NavigationDestination.video(stage: stage, division: selectedDivisionBinding.wrappedValue))
                        } label: {
                            Image(systemName: "video.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                                .frame(width: 44, height: 44)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        // Timer button
                        Button {
                            navigationPath.append(NavigationDestination.timer(stage: stage, division: selectedDivisionBinding.wrappedValue))
                        } label: {
                            Image(systemName: "timer")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .navigationTitle("Train")
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .timer(let stage, let division):
                    RecordingView(
                        stage: stage,
                        division: division,
                        vm: RecordingViewModel(stageId: stage.code, divisionId: division.id)
                    )
                case .video(let stage, let division):
                    VideoRecordingView(stage: stage, division: division)
                }
            }
        }
    }
}

// Navigation helper
enum NavigationDestination: Hashable {
    case timer(stage: Stage, division: Division)
    case video(stage: Stage, division: Division)
}

#Preview {
    TrainView()
}
