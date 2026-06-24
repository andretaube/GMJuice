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

    @MainActor
    init(stage: Stage, division: Division, vm: ViewModel) {
        self.stage = stage
        self.division = division
        self.vm = vm
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                topBar
                HStack(alignment: .top, spacing: 14) {
                    CurrentSetColumn(vm: vm, stage: stage, division: division)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 10) {
                        centerTimer
                        RecordingTargetIndicators(stage: stage, missedTargets: vm.currentString?.missedTargets ?? [], onToggleMiss: toggleTargetMiss, style: .default)
                    }
                    .frame(maxWidth: .infinity)

                    StageHistoryColumn(vm: vm, division: division)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 18)
                .frame(maxHeight: .infinity)

                ShotsSplitsBar(vm: vm)
                    .frame(height: 92)
            }
            .frame(width: geometry.size.height, height: geometry.size.width)
            .background(Color.gmScreen)
            .rotationEffect(.degrees(90))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gmScreen.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden(true)
        .onChange(of: recordingManager.stringIndex) { _, _ in
            lastAnnouncedShotCount = 0
        }
        .onChange(of: recordingManager.shotCount) { _, new in
            if new >= 5 && new != lastAnnouncedShotCount {
                lastAnnouncedShotCount = new
                autoAnnounceTask?.cancel()
                guard let stringToAnnounce = recordingManager.currentString else { return }
                autoAnnounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    let t = stringToAnnounce.adjustedTime
                    let (_, cls) = stringPercentAndClass(division: division, stageCode: stage.code, time: t)
                    announcer.speak(text: "\(Format.formatTime(t)), \(cls.spokenName)")
                }
            }
        }
        .onChange(of: recordingManager.completedStages.count) { _, _ in
            guard let stage = recordingManager.completedStages.last else { return }
            let (_, cls) = setPercentAndClass(division: division, stageCode: stage.stageId, times: stage.strings.map { $0.adjustedTime })
            announcer.speak(text: "Stage \(Format.formatTime(stage.bestNTime)), \(cls.spokenName)")
        }
        .onChange(of: vm.connectionStatus) { _, newStatus in
            if newStatus == .Connected && previousConnectionStatus != .Connected {
                announcer.speak(text: "Timer connected")
            }
            previousConnectionStatus = newStatus
        }
        .onAppear {
            lastAnnouncedShotCount = 0
            previousConnectionStatus = vm.connectionStatus
            recordingManager.startSession(stageId: stage.code, divisionId: division.rawValue, modelContext: modelContext)
            UIApplication.shared.isIdleTimerDisabled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if vm.connectionStatus != .Connected {
                    Announcer.shared.speak(text: "Timer is not connected")
                } else {
                    Announcer.shared.speak(text: "\(stage.name), \(division.rawValue)")
                }
            }
        }
        .onDisappear {
            autoAnnounceTask?.cancel()
            recordingManager.endSession()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button("✕ End") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.gmAmber)
                .frame(width: 90, alignment: .leading)

            Spacer()

            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Text("SET").font(.system(size: 15, weight: .bold)).tracking(1.5).foregroundStyle(Color.gmInk)
                    Text("\(currentStringNumber)/\(vm.setSize)").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.gmAmber).monospacedDigit()
                }
                Text("\(stage.code) · \(stage.name) · \(division.rawValue)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.gmInk2)
            }

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(vm.connectionStatus == .Connected ? Color.gmGreen : Color.gmRed)
                    .frame(width: 7, height: 7)
                Image(systemName: "timer").foregroundStyle(Color.gmInk2)
            }
            .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.gmLine).frame(height: 1) }
    }

    private var currentStringNumber: Int {
        max(min(vm.currentSet.count + 1, vm.setSize), 1)
    }

    // MARK: - Center timer

    private var centerTimer: some View {
        VStack(spacing: 4) {
            if let total = vm.stageTotal() {
                GMLabel("Stage · best \(vm.countedStrings) of \(vm.setSize)").foregroundStyle(Color.gmAmber)
                Text(Format.formatTime(total))
                    .font(.system(size: 80, weight: .heavy)).monospacedDigit()
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .foregroundStyle(Color.gmAmber)
                    .shadow(color: Color.gmAmber.opacity(0.35), radius: 18)
                let (pct, cls) = setPercentAndClass(division: division, stageCode: stage.code, times: vm.displayedSetStrings.map { $0.adjustedTime })
                GMClassBadge(cls: cls, percent: NSDecimalNumber(decimal: pct).intValue)
            } else if let s = vm.currentString {
                let t = vm.adjustedTime(for: s)
                let penalty = vm.shouldFlashRed(for: s)
                GMLabel("String \(currentStringNumber)")
                Text(Format.formatTime(t))
                    .font(.system(size: 92, weight: .heavy)).monospacedDigit()
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .foregroundStyle(penalty ? Color.gmRed : Color.gmInk)
                if let first = s.stringShots.first?.first, first > 0 {
                    Text("1st \(Format.formatTime(first)) · \(s.stringShots.count) shots")
                        .font(.system(size: 14)).monospacedDigit()
                        .foregroundStyle(Color.gmInk2)
                }
            } else {
                GMLabel("Ready").foregroundStyle(Color.gmGreen)
                Text("0.00")
                    .font(.system(size: 80, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(Color.gmInk3)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Target toggle

    private func toggleTargetMiss(_ target: Int) {
        recordingManager.toggleTargetMiss(target)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Announcer.shared.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let s = recordingManager.currentString else { return }
            let t = s.adjustedTime
            let (_, cls) = stringPercentAndClass(division: division, stageCode: stage.code, time: t)
            Announcer.shared.speak(text: "\(Format.formatTime(t)), \(cls.spokenName)")
        }
    }
}

// MARK: - Current set (left)

private struct CurrentSetColumn<ViewModel: RecordingViewModelProtocol>: View {
    @ObservedObject var vm: ViewModel
    let stage: Stage
    let division: Division

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GMLabel("Current set")

            let strings = vm.displayedSetStrings
            let worst = vm.worstIndex()
            ForEach(Array(strings.enumerated()), id: \.offset) { idx, run in
                let t = vm.adjustedTime(for: run)
                let (pct, cls) = stringPercentAndClass(division: division, stageCode: stage.code, time: t)
                let isWorst = idx == worst
                HStack(spacing: 8) {
                    Text("\(idx + 1)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.gmInk3).frame(width: 14)
                    Text(Format.formatTime(t)).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(isWorst ? Color.gmRed : Color.gmInk)
                    Spacer(minLength: 0)
                    Text(isWorst && strings.count >= vm.setSize ? "drop" : "\(cls.rawValue) \(NSDecimalNumber(decimal: pct).intValue)%")
                        .font(.system(size: 11)).monospacedDigit()
                        .foregroundStyle(isWorst ? Color.gmRed : Color.gmInk3)
                }
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(isWorst ? Color.gmRed.opacity(0.08) : Color.gmPanel2)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isWorst ? Color.gmRed.opacity(0.5) : Color.gmLine, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if strings.count < vm.setSize {
                ForEach(strings.count..<vm.setSize, id: \.self) { i in
                    HStack(spacing: 8) {
                        Text("\(i + 1)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.gmInk3).frame(width: 14)
                        Text("—").foregroundStyle(Color.gmInk3)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .opacity(0.35)
                }
            }
        }
        .frame(minWidth: 150, alignment: .leading)
    }
}

// MARK: - Stage history (right)

private struct StageHistoryColumn<ViewModel: RecordingViewModelProtocol>: View {
    @ObservedObject var vm: ViewModel
    let division: Division

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            GMLabel("Last \(min(vm.completedStages.count, 5)) stages")

            VStack(spacing: 0) {
                ForEach(Array(vm.completedStages.suffix(5).reversed().enumerated()), id: \.offset) { idx, stageRun in
                    let peak = CurrentPeakBenchmarks.get(division: division, stageCode: stageRun.stageId)?.peakTime ?? 0
                    let pct: Int = (peak > 0 && stageRun.bestNTime > 0) ? NSDecimalNumber(decimal: peak / stageRun.bestNTime * 100).intValue : 0
                    let cls = ShooterClass.shooterClass(percentage: Decimal(pct))
                    HStack(spacing: 8) {
                        Text(Format.formatTime(stageRun.bestNTime)).font(.system(size: 14, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(idx == 0 ? Color.gmGreen : Color.gmInk)
                        GMClassBadge(cls: cls, percent: pct)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 7)
                    if idx < min(vm.completedStages.count, 5) - 1 { Divider().overlay(Color.gmLine) }
                }
                if vm.completedStages.isEmpty {
                    Text("—").foregroundStyle(Color.gmInk3).font(.caption).padding(8)
                }
            }
            .background(Color.gmPanel)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gmLine, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(minWidth: 150, alignment: .trailing)
    }
}

// MARK: - Shots / splits (bottom)

private struct ShotsSplitsBar<ViewModel: RecordingViewModelProtocol>: View {
    @ObservedObject var vm: ViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GMLabel("Shots / splits").padding(.horizontal, 18)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array((vm.currentString?.stringShots ?? []).enumerated()), id: \.offset) { i, shot in
                        VStack(spacing: 2) {
                            Text("\(i + 1)").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.gmInk3)
                            Text(Format.formatTime(shot.now)).font(.system(size: 17, weight: .bold)).monospacedDigit().foregroundStyle(Color.gmInk)
                            Text(Format.formatTime(shot.split)).font(.system(size: 12)).monospacedDigit().foregroundStyle(Color.gmInk3)
                        }
                        .frame(minWidth: 64)
                        .padding(.vertical, 2)
                        Divider().overlay(Color.gmLine)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
        .padding(.top, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gmPanel2)
        .overlay(alignment: .top) { Rectangle().fill(Color.gmLine).frame(height: 1) }
    }
}
