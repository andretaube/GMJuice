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
    @AppStorage("hasSeenTrainCoachMarks") private var hasSeenCoachMarks = false

    @State private var navigationPath = NavigationPath()
    @State private var showingTutorial = false
    @State private var showingCoachMarks = false
    @State private var trackedFrames: [String: CGRect] = [:]
    @EnvironmentObject private var bleManager: BLEManager
    
    private let analytics = AnalyticsService.shared

    // Binding that bridges @AppStorage <-> enum
    private var selectedDivisionBinding: Binding<Division> {
        Binding(
            get: { Division(rawValue: activeDivisionRaw) ?? .RFPO },
            set: { activeDivisionRaw = $0.rawValue }
        )
    }

    // Create coach marks from tracked frames
    private func createCoachMarks() -> [CoachMark]? {
        guard let divisionFrame = trackedFrames["divisionPicker"],
              let timerButtonFrame = trackedFrames["timerButton"],
              let videoButtonFrame = trackedFrames["videoButton"],
              let timerLogFrame = trackedFrames["timerLog"],
              let videosLogFrame = trackedFrames["videosLog"] else {
            return nil
        }

        return TrainViewHelp.createCoachMarks(
            divisionFrame: divisionFrame,
            timerButtonFrame: timerButtonFrame,
            videoButtonFrame: videoButtonFrame,
            timerLogFrame: timerLogFrame,
            videosLogFrame: videosLogFrame
        )
    }

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {
                VStack(spacing: 0) {
                // Navigation pills
                HStack(spacing: 12) {
                    NavigationLink(value: TrainNavigationPill.timerLog) {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Training Log")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .trackFrame(named: "timerLog")

                    NavigationLink(value: TrainNavigationPill.videos) {
                        HStack(spacing: 8) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Videos")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .trackFrame(named: "videosLog")
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))

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
                        .trackFrame(named: "divisionPicker")
                    }

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

                        HStack(spacing: 8) {
                            // Timer button (now first)
                            Button {
                                analytics.trackStageSelection(stage: stage.code, division: selectedDivisionBinding.wrappedValue.rawValue, mode: "timer")
                                navigationPath.append(NavigationDestination.timer(stage: stage, division: selectedDivisionBinding.wrappedValue))
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "timer")
                                        .font(.title3)
                                    Text("Timer")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                                .frame(width: 100, height: 60)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .trackFrame(named: index == 0 ? "timerButton" : "")

                            // Video button (now second)
                            Button {
                                analytics.trackStageSelection(stage: stage.code, division: selectedDivisionBinding.wrappedValue.rawValue, mode: "video")
                                navigationPath.append(NavigationDestination.video(stage: stage, division: selectedDivisionBinding.wrappedValue))
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "video.fill")
                                        .font(.title3)
                                    Text("Video")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                                .frame(width: 100, height: 60)
                                .background(Color.red)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .trackFrame(named: index == 0 ? "videoButton" : "")
                        }
                        .padding(.trailing, 16)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
                }
                .navigationTitle("Train")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            analytics.trackFeatureUsed("help_tutorial")
                            
                            // Show coach marks if frames are available, otherwise fallback to tutorial sheet
                            if createCoachMarks() != nil {
                                showingCoachMarks = true
                            } else {
                                showingTutorial = true
                            }
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .onAppear {
                    analytics.trackScreen("TrainView")
                    analytics.setDivisionProperty(selectedDivisionBinding.wrappedValue.rawValue)
                }
            }
            .sheet(isPresented: $showingTutorial) {
                TrainTutorialView()
            }
            .onPreferenceChange(FramePreferenceKey.self) { frames in
                trackedFrames = frames
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

        // Coach marks overlay at the top level
        if showingCoachMarks, let marks = createCoachMarks() {
            CoachMarkOverlay(isPresented: $showingCoachMarks, marks: marks)
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
