//
//  RecordingViewComponents.swift
//  GMJuice
//
//  Shared protocol + reusable components for the set-based RecordingView.
//

import SwiftUI
import SwiftData

// MARK: - Styling

struct RecordingViewStyle {
    let textColor: Color
    let useShadow: Bool
    static let `default` = RecordingViewStyle(textColor: .primary, useShadow: false)
}

// MARK: - View Model Protocol

@MainActor
protocol RecordingViewModelProtocol: ObservableObject {
    var connectionStatus: BLEConnectionStatus { get }
    var currentString: StringRun? { get }
    var currentSet: [StringRun] { get }
    var completedStages: [StageRun] { get }
    var setSize: Int { get }
    var stringIndex: Int { get }
    var setIsComplete: Bool { get }
    var shotCount: Int { get }
    var displayedSetStrings: [StringRun] { get }
    var countedStrings: Int { get }
    func worstIndex() -> Int?
    func stageTotal() -> Decimal?
    func adjustedTime(for run: StringRun) -> Decimal
    func shouldFlashRed(for run: StringRun) -> Bool
}

// MARK: - Performance helpers

/// Percentage and classification for a single string time (vs the per-string benchmark).
func stringPercentAndClass(division: Division, stageCode: String, time: Decimal) -> (Decimal, ShooterClass) {
    let pct = CurrentPeakBenchmarks.percent(division: division, stageCode: stageCode, time: time)
    return (pct, ShooterClass.shooterClass(percentage: pct))
}

/// Percentage and classification for a completed set (best N-1), vs the full stage benchmark.
func setPercentAndClass(division: Division, stageCode: String, times: [Decimal]) -> (Decimal, ShooterClass) {
    let pct = CurrentPeakBenchmarks.percent(division: division, stageCode: stageCode, times: times)
    return (pct, ShooterClass.shooterClass(percentage: pct))
}

// MARK: - Reusable small views

struct RecordingInfoTitle: View {
    let icon: Image
    let label: String
    let color: Color
    let style: RecordingViewStyle

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(style.textColor)
            icon
                .foregroundStyle(color)
                .imageScale(.medium)
        }
        .applyShadowIf(style.useShadow)
    }
}

struct RecordingTimerConnectionStatus: View {
    let connectionStatus: BLEConnectionStatus
    let style: RecordingViewStyle

    var body: some View {
        Image(systemName: "timer")
            .foregroundColor(
                connectionStatus == .Connected ? .green :
                connectionStatus == .Disconnected ? .red :
                connectionStatus == .Connecting ? .orange : .gray
            )
            .applyShadowIf(style.useShadow)
    }
}

// MARK: - Target Indicators

struct RecordingTargetIndicators: View {
    let stage: Stage
    let missedTargets: [Int]
    let onToggleMiss: (Int) -> Void
    let style: RecordingViewStyle

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                ForEach(Array(stage.targetLayout.enumerated()), id: \.offset) { index, position in
                    targetButton(for: index + 1, plateType: position.plateType)
                        .position(
                            x: CGFloat(position.x) * width,
                            y: CGFloat(1.0 - position.y) * height
                        )
                }
            }
        }
        .frame(width: 200, height: 60)
    }

    private func targetButton(for target: Int, plateType: PlateType) -> some View {
        let isMissed = missedTargets.contains(target)
        let size: CGFloat = plateType == .round12 ? 28 : 24
        let isStopPlate = (target == 5)
        let displayText = isStopPlate ? "S" : "\(target)"

        return Button {
            onToggleMiss(target)
        } label: {
            ZStack {
                if plateType == .square {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isMissed ? Color.red : Color.green)
                        .overlay { if isStopPlate { RoundedRectangle(cornerRadius: 4).stroke(Color.red, lineWidth: 2) } }
                } else {
                    Circle()
                        .fill(isMissed ? Color.red : Color.green)
                        .overlay { if isStopPlate { Circle().stroke(Color.red, lineWidth: 2) } }
                }
                Text(displayText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: plateType == .square ? 30 : size)
            .applyShadowIf(style.useShadow)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View extension

extension View {
    @ViewBuilder
    func applyShadowIf(_ condition: Bool) -> some View {
        if condition { self.shadow(color: .black, radius: 2) } else { self }
    }
}
