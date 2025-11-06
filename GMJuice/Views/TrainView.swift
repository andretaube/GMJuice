//
//  TrainView.swift
//  GMJuice
//
//  Created by Andre Taube on 10/11/25.
//

import SwiftUI
import Foundation
import TipKit

struct TrainView: View {
    // Persist the user's selected SCSA division in user preferences
    @AppStorage("scsa_active_division") private var activeDivisionRaw: String = Division.RFPO.rawValue

    @State private var navigationPath = NavigationPath()
    @State private var tipRefreshID = UUID()
    @State private var showingTipsResetAlert = false

    // Tips
    private let divisionTip = SelectDivisionTip()
    private let timerTip = TimerButtonTip()
    private let videoTip = VideoRecordingTip()
    private let logTip = TimerLogTip()

    // Binding that bridges @AppStorage <-> enum
    private var selectedDivisionBinding: Binding<Division> {
        Binding(
            get: { Division(rawValue: activeDivisionRaw) ?? .RFPO },
            set: { activeDivisionRaw = $0.rawValue }
        )
    }

    // Replay all tutorial tips
    private func replayTips() {
        Task {
            // Reset the entire TipKit datastore to show all tips again
            try? Tips.resetDatastore()

            // Reconfigure TipKit to ensure tips display immediately
            try? Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])

            // Force view refresh by changing the ID
            await MainActor.run {
                tipRefreshID = UUID()
                showingTipsResetAlert = true
            }
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Navigation pills
                HStack(spacing: 12) {
                    NavigationLink(value: TrainNavigationPill.timerLog) {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.subheadline)
                            Text("Timer Log")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .cornerRadius(20)
                    }
                    .popoverTip(logTip, arrowEdge: .top)

                    NavigationLink(value: TrainNavigationPill.videos) {
                        HStack(spacing: 6) {
                            Image(systemName: "video.fill")
                                .font(.subheadline)
                            Text("Videos")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .cornerRadius(20)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .id(tipRefreshID)

                Divider()

                List {
                    // Top "dropdown" for division selection
                    Section {
                        Picker("Division", selection: selectedDivisionBinding) {
                            ForEach(Division.allCases) { div in
                                Text(div.displayName).tag(div)
                            }
                        }
                        .pickerStyle(.menu) // renders as a dropdown in the list
                        .popoverTip(divisionTip, arrowEdge: .top)
                    }
                    .id(tipRefreshID)

                    // Stages
                    ForEach(Array(AllStages.enumerated()), id: \.element.id) { index, stage in
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.code)
                                .font(.headline)
                            Text(stage.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 16)
                        .padding(.vertical, 8)

                        Spacer(minLength: 0)

                        // Video button
                        Button {
                            navigationPath.append(NavigationDestination.video(stage: stage, division: selectedDivisionBinding.wrappedValue))
                        } label: {
                            Image(systemName: "video.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 60)
                                .frame(maxHeight: .infinity)
                                .background(Color.red)
                        }
                        .buttonStyle(.plain)
                        .popoverTip(videoTip, arrowEdge: .trailing)
                        .opacity(index == 0 ? 1 : 1) // Show tip only on first stage

                        // Timer button
                        Button {
                            navigationPath.append(NavigationDestination.timer(stage: stage, division: selectedDivisionBinding.wrappedValue))
                        } label: {
                            Image(systemName: "timer")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 60)
                                .frame(maxHeight: .infinity)
                                .background(Color.blue)
                        }
                        .buttonStyle(.plain)
                        .popoverTip(timerTip, arrowEdge: .trailing)
                        .opacity(index == 0 ? 1 : 1) // Show tip only on first stage
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .id("\(stage.id)-\(tipRefreshID)")
                }
                }
                .navigationTitle("Train")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            replayTips()
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .alert("Tips Reset", isPresented: $showingTipsResetAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Tutorial tips have been reset. They will appear as you use the Train screen.")
            }
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
            .navigationDestination(for: TrainNavigationPill.self) { pill in
                switch pill {
                case .timerLog:
                    LogView()
                case .videos:
                    VideosView()
                }
            }
        }
    }
}

// Navigation pills destination
enum TrainNavigationPill: Hashable {
    case timerLog
    case videos
}

// Navigation helper
enum NavigationDestination: Hashable {
    case timer(stage: Stage, division: Division)
    case video(stage: Stage, division: Division)
}

#Preview {
    TrainView()
}
