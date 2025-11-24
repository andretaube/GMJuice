//
//  RecordingViewComponents.swift
//  GMJuice
//
//  Shared view components for RecordingView and VideoRecordingView
//

import SwiftUI
import SwiftData

// MARK: - Performance Level

enum PerformanceLevel {
    case trophy  // Above class level
    case good    // At class level
    case normal  // Below class level or incomplete
    case penalty // 30-second penalty (should flash red)
}

// MARK: - Styling Configuration

struct RecordingViewStyle {
    let textColor: Color
    let useShadow: Bool

    static let `default` = RecordingViewStyle(textColor: .primary, useShadow: false)
    static let video = RecordingViewStyle(textColor: .white, useShadow: true)
}

// MARK: - View Model Protocol

@MainActor
protocol RecordingViewModelProtocol: ObservableObject {
    var counter: Int { get }
    var stringRun: StringRun { get }
    var allRuns: [StringRun] { get }
    var connectionStatus: BLEConnectionStatus { get }

    func adjustedTime(for stringRun: StringRun) -> Decimal
    func times() -> [Decimal]
    func bestTime() -> Decimal?
    func bestFirstShot() -> Decimal?
    func worstTime() -> Decimal?
    func worstFirstShot() -> Decimal?
    func shouldFlashRed(for stringRun: StringRun) -> Bool
}

// MARK: - Left Column

struct RecordingLeftColumn<ViewModel: RecordingViewModelProtocol>: View {
    let stage: Stage
    let division: Division
    @ObservedObject var vm: ViewModel
    let style: RecordingViewStyle
    let shooter: ShooterProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("#\(vm.counter)")
                .font(.title.bold())
                .foregroundStyle(style.textColor)
                .applyShadowIf(style.useShadow)

            let time = vm.adjustedTime(for: vm.stringRun)

            RecordingInfoTitle(icon: .init(systemName: "stopwatch"),
                               label: "Current",
                               color: .orange,
                               style: style)

            if vm.stringRun.stringShots.count >= 5 {
                RecordingPercentClass(division: division, stageCode: stage.code, time: time, shooter: shooter, style: style)
            } else {
                Text("1").hidden().font(.system(.title2, weight: .bold))
            }

            Spacer().frame(height: 8)

            // Calculate best N sum for display
            let bestN = stage.strings - 1
            let bestNSum = calculateBestNSum(times: vm.times(), n: bestN)
            let bestNLabel = stage.strings == 5 ? "Best 4 of 5" : "Best 3 of 4"

            RecordingInfoTitle(icon: .init(systemName: "stopwatch"),
                               label: bestNLabel,
                               color: .purple,
                               style: style)

            if let sum = bestNSum {
                Text("Time: \(Format.formatTime(sum))")
                    .font(.system(.body, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(style.textColor)
                    .applyShadowIf(style.useShadow)
            }

            if stage.strings <= vm.allRuns.count && vm.stringRun.stringShots.count >= 5 {
                RecordingPercentClass(division: division, stageCode: stage.code, times: vm.times(), shooter: shooter, style: style)
            } else {
                Text("1").hidden().font(.system(.title2, weight: .bold))
            }
        }
        .frame(minWidth: 150, alignment: .leading)
    }
}

// MARK: - Timer Display

struct RecordingTimerDisplay<ViewModel: RecordingViewModelProtocol>: View {
    let fontSize: CGFloat
    @ObservedObject var vm: ViewModel
    let division: Division
    let stage: Stage
    let shooter: ShooterProfile?
    let style: RecordingViewStyle
    var announcer: Announcer?

    @State private var pulseAnimation: Bool = false

    var body: some View {
        let performanceLevel = getPerformanceLevel()
        let adjustedTime = vm.adjustedTime(for: vm.stringRun)

        Text(Format.formatTime(adjustedTime))
            .monospacedDigit()
            .font(.system(size: fontSize, weight: .bold))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .foregroundStyle(timerColor(for: performanceLevel, style: style))
            .shadow(color: shadowColor(for: performanceLevel, style: style), radius: performanceLevel == .trophy ? 20 : (performanceLevel == .good ? 10 : (performanceLevel == .penalty ? 20 : 0)))
            .scaleEffect((performanceLevel == .trophy || performanceLevel == .penalty) && pulseAnimation ? 1.05 : 1.0)
            .onChange(of: vm.stringRun.stringShots.count) { old, new in
                if new >= 5 {
                    if performanceLevel == .trophy {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulseAnimation = true
                        }
                        announcer?.playTrophySound()
                    } else if performanceLevel == .penalty {
                        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                            pulseAnimation = true
                        }
                    }
                } else {
                    pulseAnimation = false
                }
            }
    }

    private func getPerformanceLevel() -> PerformanceLevel {
        guard vm.stringRun.stringShots.count >= 5 else {
            return .normal
        }

        if vm.shouldFlashRed(for: vm.stringRun) {
            return .penalty
        }

        guard let classification = shooter?.classification(for: division) else {
            return .normal
        }

        let time = vm.adjustedTime(for: vm.stringRun)
        let pct = CurrentPeakBenchmarks.percent(division: division, stageCode: stage.code, time: time)
        let threshold = classification.percentThreshold
        let nextClassThreshold = classification.nextClassThreshold

        if pct >= nextClassThreshold {
            return .trophy
        } else if pct >= threshold {
            return .good
        } else {
            return .normal
        }
    }

    private func timerColor(for level: PerformanceLevel, style: RecordingViewStyle) -> Color {
        switch level {
        case .trophy:
            return .yellow
        case .good:
            return .green
        case .normal:
            return style.textColor
        case .penalty:
            return .red
        }
    }

    private func shadowColor(for level: PerformanceLevel, style: RecordingViewStyle) -> Color {
        switch level {
        case .trophy:
            return .yellow.opacity(0.8)
        case .good:
            return .green.opacity(0.6)
        case .normal:
            return style.useShadow ? .black.opacity(0.8) : .clear
        case .penalty:
            return .red.opacity(0.8)
        }
    }
}

// MARK: - Right Column

struct RecordingRightColumn<ViewModel: RecordingViewModelProtocol>: View {
    @ObservedObject var vm: ViewModel
    let style: RecordingViewStyle
    let extraContent: AnyView?

    init(vm: ViewModel, style: RecordingViewStyle, @ViewBuilder extraContent: () -> some View = { EmptyView() }) {
        self.vm = vm
        self.style = style
        self.extraContent = AnyView(extraContent())
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 12) {
                extraContent
                RecordingTimerConnectionStatus(connectionStatus: vm.connectionStatus, style: style)
            }

            if let bestTime = vm.bestTime() {
                RecordingInfoTitle(icon: .init(systemName: "thermometer.high"), label: "Fastest", color: .green, style: style)
                Text("Time: \(Format.formatTime(bestTime))")
                    .font(.system(.body, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(style.textColor)
                    .applyShadowIf(style.useShadow)
            }
            if let bestFirstShot = vm.bestFirstShot() {
                Text("1st: \(Format.formatTime(bestFirstShot))")
                    .font(.system(.body, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(style.textColor)
                    .applyShadowIf(style.useShadow)
            }

            Spacer().frame(height: 15)

            if vm.counter > 1 {
                if let worstTime = vm.worstTime() {
                    RecordingInfoTitle(icon: .init(systemName: "thermometer.low"), label: "Slowest", color: .red, style: style)
                    Text("Time: \(Format.formatTime(worstTime))")
                        .font(.system(.body, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(style.textColor)
                        .applyShadowIf(style.useShadow)
                }
                if let worstFirstShot = vm.worstFirstShot() {
                    Text("1st: \(Format.formatTime(worstFirstShot))")
                        .font(.system(.body, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(style.textColor)
                        .applyShadowIf(style.useShadow)
                }
            }
        }
        .frame(minWidth: 150, alignment: .trailing)
    }
}

// MARK: - Shots and Splits

struct RecordingShotsAndSplits<ViewModel: RecordingViewModelProtocol>: View {
    @ObservedObject var vm: ViewModel
    let style: RecordingViewStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RecordingInfoTitle(icon: .init(systemName: "list.number"), label: "Shots / Splits", color: .blue, style: style)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(vm.stringRun.orderedStringShots) { shot in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(Format.formatTime(shot.now))")
                                .font(.title2.bold())
                                .monospacedDigit()
                                .foregroundStyle(style.textColor)
                                .applyShadowIf(style.useShadow)

                            Text("\(Format.formatTime(shot.split))")
                                .font(.headline)
                                .monospacedDigit()
                                .foregroundStyle(style.textColor)
                                .applyShadowIf(style.useShadow)
                        }
                        .padding(.horizontal, 4)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1")
                            .hidden()
                            .font(.title2.bold())
                            .monospacedDigit()

                        Text("1")
                            .hidden()
                            .font(.headline)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
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

        let width: CGFloat = {
            switch plateType {
            case .round10:
                return 24
            case .round12:
                return 28
            case .square:
                return 24
            }
        }()

        let height: CGFloat = {
            switch plateType {
            case .round10:
                return 24
            case .round12:
                return 28
            case .square:
                return 30
            }
        }()

        let fontSize: CGFloat = {
            switch plateType {
            case .round10:
                return 14
            case .round12:
                return 16
            case .square:
                return 14
            }
        }()

        let isStopPlate = (target == 5)
        let displayText = isStopPlate ? "S" : "\(target)"

        return Button {
            onToggleMiss(target)
        } label: {
            ZStack {
                if plateType == .square {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isMissed ? Color.red : Color.green)
                        .overlay {
                            if isStopPlate {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.red, lineWidth: 2)
                            }
                        }
                } else {
                    Circle()
                        .fill(isMissed ? Color.red : Color.green)
                        .overlay {
                            if isStopPlate {
                                Circle()
                                    .stroke(Color.red, lineWidth: 2)
                            }
                        }
                }

                Text(displayText)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: width, height: height)
            .applyShadowIf(style.useShadow)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helper Views

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

struct RecordingPercentClass: View {
    let division: Division
    let stageCode: String
    let time: Decimal?
    let times: [Decimal]?
    let shooter: ShooterProfile?
    let style: RecordingViewStyle

    init(division: Division, stageCode: String, time: Decimal, shooter: ShooterProfile?, style: RecordingViewStyle) {
        self.division = division
        self.stageCode = stageCode
        self.time = time
        self.times = nil
        self.shooter = shooter
        self.style = style
    }

    init(division: Division, stageCode: String, times: [Decimal], shooter: ShooterProfile?, style: RecordingViewStyle) {
        self.division = division
        self.stageCode = stageCode
        self.time = nil
        self.times = times
        self.shooter = shooter
        self.style = style
    }

    var body: some View {
        let pct = if let time = time {
            CurrentPeakBenchmarks.percent(division: division, stageCode: stageCode, time: time)
        } else if let times = times {
            CurrentPeakBenchmarks.percent(division: division, stageCode: stageCode, times: times)
        } else {
            Decimal(0)
        }

        let percentDouble = NSDecimalNumber(decimal: pct).doubleValue
        let shooterClass = ShooterClass.shooterClass(percentage: pct)

        HStack {
            Text(String(format: "%.0f%% (%@)", percentDouble, shooterClass.rawValue))
                .font(.system(.body, weight: .bold))
                .foregroundStyle(style.textColor)
                .applyShadowIf(style.useShadow)
            if let classification = shooter?.classification(for: division) {
                RecordingStringReward(percent: pct, shooterClass: classification, style: style)
                    .imageScale(.small)
            }
        }
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

struct RecordingStringReward: View {
    let percent: Decimal
    let shooterClass: ShooterClass
    let style: RecordingViewStyle

    var body: some View {
        let threshold = shooterClass.percentThreshold
        let nextClassThreshold = shooterClass.nextClassThreshold

        if percent >= nextClassThreshold {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)
                .applyShadowIf(style.useShadow)
        } else if percent >= threshold {
            Image(systemName: "hand.thumbsup.fill")
                .foregroundStyle(.green)
                .applyShadowIf(style.useShadow)
        } else {
            Image(systemName: "hand.thumbsdown.fill")
                .foregroundStyle(.red)
                .applyShadowIf(style.useShadow)
        }
    }
}

// MARK: - Helper Functions

/// Calculate the sum of best N times from the most recent M times
/// This matches the classification logic in CurrentPeakBenchmarks.percent()
/// For example: take most recent 5 runs, find best 4, sum them
private func calculateBestNSum(times: [Decimal], n: Int) -> Decimal? {
    let validTimes = times.filter { $0 > 0 }

    // We need n+1 runs to calculate best n (excluding the slowest)
    let m = n + 1
    guard validTimes.count >= m else { return nil }

    // Take most recent m runs
    let recentM = Array(validTimes.suffix(m))

    // Find the slowest of these recent runs
    guard let slowest = recentM.max() else { return nil }

    // Sum all recent runs minus the slowest = best n of recent m
    return recentM.reduce(0, +) - slowest
}

// MARK: - View Extensions

extension View {
    @ViewBuilder
    func applyShadowIf(_ condition: Bool) -> some View {
        if condition {
            self.shadow(color: .black, radius: 2)
        } else {
            self
        }
    }
}
