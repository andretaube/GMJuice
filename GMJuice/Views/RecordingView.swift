import SwiftUI
import Combine
import SwiftData
import UIKit

struct RecordingView<ViewModel: RecordingViewModelProtocol>: View {
    let stage: Stage
    let division: Division

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @ObservedObject private var announcer = Announcer.shared
    @ObservedObject private var recordingManager = RecordingManager.shared

    @ObservedObject var vm: ViewModel
    @State private var autoAnnounceTask: Task<Void, Never>?
    @State private var lastAnnouncedShotCount = 0
    @State private var previousConnectionStatus: BLEConnectionStatus = .Disconnected
    

    @Query private var shooterProfiles: [ShooterProfile]
    private var shooter: ShooterProfile? {
        shooterProfiles.first
    }
    

    @MainActor
    init(stage: Stage, division: Division, vm: ViewModel) {
        self.stage = stage
        self.division = division
        self.vm = vm
    }

    var body: some View {
        GeometryReader { geometry in
            // Rotate the entire content 90 degrees to simulate landscape while in portrait
            VStack(spacing: 0) {
                // Custom top navigation bar
                HStack {
                    // Left: Done button
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    // Center: Stage and division info
                    VStack(spacing: 2) {
                        Text(stage.name)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                        Text("\(stage.code) • \(division.rawValue)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Right: Timer status
                    RecordingTimerConnectionStatus(connectionStatus: vm.connectionStatus, style: .default)
                        .imageScale(.large)
                        .frame(width: 110, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                // Main content area
                HStack(spacing: 0) {
                    RecordingLeftColumn(stage: stage, division: division, vm: vm, style: .default, shooter: shooter)
                    VStack(spacing: 8) {
                        RecordingTimerDisplay(fontSize: 160, vm: vm, division: division, stage: stage, shooter: shooter, style: .default, announcer: announcer)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)

                        // Hit/miss indicators right after time
                        RecordingTargetIndicators(stage: stage, missedTargets: vm.stringRun.missedTargets, onToggleMiss: toggleTargetMiss, style: .default)
                    }
                    .frame(maxWidth: .infinity)
                    // Custom right column without timer status
                    VStack(alignment: .trailing, spacing: 2) {
                        if let bestTime = vm.bestTime() {
                            RecordingInfoTitle(icon: .init(systemName: "thermometer.high"), label: "Fastest", color: .green, style: .default)
                            Text("Time: \(Format.formatTime(bestTime))")
                                .font(.system(.body, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }
                        if let bestFirstShot = vm.bestFirstShot() {
                            Text("1st: \(Format.formatTime(bestFirstShot))")
                                .font(.system(.body, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }

                        Spacer().frame(height: 15)

                        if vm.counter > 1 {
                            if let worstTime = vm.worstTime() {
                                RecordingInfoTitle(icon: .init(systemName: "thermometer.low"), label: "Slowest", color: .red, style: .default)
                                Text("Time: \(Format.formatTime(worstTime))")
                                    .font(.system(.body, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }
                            if let worstFirstShot = vm.worstFirstShot() {
                                Text("1st: \(Format.formatTime(worstFirstShot))")
                                    .font(.system(.body, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .frame(minWidth: 150, alignment: .trailing)
                }
                .frame(maxHeight: .infinity)
                
                // Shots and splits at the bottom
                RecordingShotsAndSplits(vm: vm, style: .default)
                    .frame(height: 120)
                    .padding(.bottom, 8)
            }
            .frame(width: geometry.size.height, height: geometry.size.width)
            .rotationEffect(.degrees(90))
            .position(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: [])
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden(true)
        .onChange(of: recordingManager.stringCounter) { _, _ in
            // Reset announcement tracking when a new string starts
            lastAnnouncedShotCount = 0
        }
        .onChange(of: recordingManager.shotCount) { old, new in
            // Only trigger when reaching or exceeding 5 shots for the first time
            if new >= 5 && new != lastAnnouncedShotCount {
                lastAnnouncedShotCount = new

                // Cancel any pending announcement
                autoAnnounceTask?.cancel()

                // Capture current string to avoid race condition
                guard let stringToAnnounce = recordingManager.currentString else {
                    return
                }

                // Schedule new announcement
                autoAnnounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)

                    guard !Task.isCancelled else { return }

                    let adjustedTime = stringToAnnounce.adjustedTime

                    // Calculate classification for this time
                    let pct = CurrentPeakBenchmarks.percent(division: division, stageCode: stage.code, time: adjustedTime)
                    let shooterClass = ShooterClass.shooterClass(percentage: pct)

                    print("📢 Auto-announcing time: \(adjustedTime) (\(shooterClass.rawValue))")
                    announcer.speak(text: "\(Format.formatTime(adjustedTime)), \(shooterClass.spokenName)")
                }
            }
        }
        .onChange(of: vm.connectionStatus) { oldStatus, newStatus in
            // Announce when timer connects (but not on initial connection or reconnections)
            if newStatus == .Connected && previousConnectionStatus != .Connected {
                print("📢 Timer connected")
                announcer.speak(text: "Timer connected")
            }
            previousConnectionStatus = newStatus
        }
        .onAppear() {
            // Reset announcement tracking
            lastAnnouncedShotCount = 0

            // Set initial connection status (no announcement on first appear)
            previousConnectionStatus = vm.connectionStatus

            // Start recording session
            recordingManager.startSession(stageId: stage.code, divisionId: division.rawValue, modelContext: modelContext)

            UIApplication.shared.isIdleTimerDisabled = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if vm.connectionStatus != .Connected {
                    Announcer.shared.speak(text: "Timer is not connected")
                } else {
                    Announcer.shared.speak(text: "\(stage.name), \(division)")
                }
            }
        }
        .onDisappear() {
            // Cancel pending announcement
            autoAnnounceTask?.cancel()

            // End recording session
            recordingManager.endSession()

            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    // MARK: - Target Hit/Miss Toggle

    private func toggleTargetMiss(_ target: Int) {
        // Delegate to RecordingManager for proper model mutation
        recordingManager.toggleTargetMiss(target)

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Cancel any current announcement and announce adjusted time with classification after 1 second
        Announcer.shared.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let adjustedTime = vm.adjustedTime(for: vm.stringRun)

            // Calculate classification for this time
            let pct = CurrentPeakBenchmarks.percent(division: division, stageCode: stage.code, time: adjustedTime)
            let shooterClass = ShooterClass.shooterClass(percentage: pct)

            Announcer.shared.speak(text: "\(Format.formatTime(adjustedTime)), \(shooterClass.spokenName)")
        }
    }

}
