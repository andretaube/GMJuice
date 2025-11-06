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

        var marks: [CoachMark] = []

        // Always show division picker tip first
        marks.append(CoachMark(
            title: "Choose Your Division",
            message: "Select which USPSA division you're training with. This determines the GM benchmark times used for performance tracking.",
            highlightFrame: divisionFrame,
            calloutPosition: .bottom
        ))

        // If no timer is saved, show connection tip in settings
        let hasTimerSaved = UserDefaults.standard.string(forKey: "ble_saved_uuid") != nil
        if !hasTimerSaved {
            marks.append(CoachMark(
                title: "Connect Your Timer",
                message: "Go to Settings to connect your AMG timer via Bluetooth. Once connected, you can automatically track your shot times and splits.",
                highlightFrame: divisionFrame, // Use same frame as division since settings isn't visible
                calloutPosition: .bottom
            ))
        }

        // Timer button tip
        marks.append(CoachMark(
            title: "Start Training with Timer",
            message: hasTimerSaved
                ? "When your timer is connected, you'll see your shots, splits, and performance history automatically recorded for each training run."
                : "After connecting your timer in Settings, tap here to start recording your training runs with automatic shot and split timing.",
            highlightFrame: timerButtonFrame,
            calloutPosition: .top
        ))

        // Video button tip
        marks.append(CoachMark(
            title: "Record Your Training",
            message: "Record video of your runs with a professional overlay showing shot times, splits, classification score, and performance metrics. Perfect for reviewing technique and tracking progress.",
            highlightFrame: videoButtonFrame,
            calloutPosition: .top
        ))

        // Timer Log tip
        marks.append(CoachMark(
            title: "View Your Training History",
            message: "Access all your recorded runs organized by date and stage. Review times and track improvement.",
            highlightFrame: timerLogFrame,
            calloutPosition: .bottom
        ))

        // Videos Log tip
        marks.append(CoachMark(
            title: "Browse Your Videos",
            message: "View all your recorded training videos in one place. Review your form and technique across all stages.",
            highlightFrame: videosLogFrame,
            calloutPosition: .bottom
        ))

        // Final motivational tip (use division frame since no specific UI to highlight)
        let motivationalMessage = MotivationalMessages.randomElement() ?? "Go train!"
        marks.append(CoachMark(
            title: "Now Go Train!",
            message: motivationalMessage,
            highlightFrame: divisionFrame,
            calloutPosition: .bottom
        ))

        return marks
    }

    var body: some View {
        ZStack {
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
                    .trackFrame(named: "timerLog")

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
                    .trackFrame(named: "videosLog")

                    Spacer()
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
                        .trackFrame(named: index == 0 ? "videoButton" : "")

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
                        .trackFrame(named: index == 0 ? "timerButton" : "")
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                }
                .navigationTitle("Train")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
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
            }
            .sheet(isPresented: $showingTutorial) {
                TrainTutorialView()
            }
            .onPreferenceChange(FramePreferenceKey.self) { frames in
                trackedFrames = frames

                // Show coach marks on first visit once frames are available
                if !hasSeenCoachMarks && !showingCoachMarks && !frames.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingCoachMarks = true
                        hasSeenCoachMarks = true
                    }
                }
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

// MARK: - Tutorial View

struct TrainTutorialView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Division Selection
                    TutorialCard(
                        icon: "list.bullet",
                        iconColor: .blue,
                        title: "Choose Your Division",
                        description: "Select which USPSA division you're training with. This determines the GM benchmark times used for performance tracking."
                    )

                    // BLE Connection
                    let hasTimerSaved = UserDefaults.standard.string(forKey: "ble_saved_uuid") != nil
                    if !hasTimerSaved {
                        TutorialCard(
                            icon: "antenna.radiowaves.left.and.right",
                            iconColor: .orange,
                            title: "Connect Your Timer",
                            description: "Go to Settings to connect your AMG timer via Bluetooth. Once connected, you can automatically track your shot times and splits."
                        )
                    }

                    // Timer Button
                    TutorialCard(
                        icon: "timer",
                        iconColor: .blue,
                        title: "Start Training with Timer",
                        description: hasTimerSaved
                            ? "When your timer is connected, you'll see your shots, splits, and performance history automatically recorded for each training run."
                            : "After connecting your timer in Settings, tap here to start recording your training runs with automatic shot and split timing."
                    )

                    // Video Button
                    TutorialCard(
                        icon: "video.fill",
                        iconColor: .red,
                        title: "Record Your Training",
                        description: "Record video of your runs to review technique and track progress over time."
                    )

                    // Timer Log
                    TutorialCard(
                        icon: "list.bullet.rectangle",
                        iconColor: .blue,
                        title: "View Your Training History",
                        description: "Access all your recorded runs organized by date and stage. Review times and track improvement."
                    )

                    // Videos Log
                    TutorialCard(
                        icon: "video.fill",
                        iconColor: .red,
                        title: "Browse Your Videos",
                        description: "View all your recorded training videos in one place. Review your form and technique across all stages."
                    )
                }
                .padding()
            }
            .navigationTitle("How to Use Train")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TutorialCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    TrainView()
}
