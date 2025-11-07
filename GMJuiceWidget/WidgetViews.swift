//
//  WidgetViews.swift
//  GMJuiceWidget
//
//  Created by Claude on 11/6/25.
//

import SwiftUI
import WidgetKit

struct PerformanceWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: PerformanceEntry

    var body: some View {
        if let stats = entry.divisionStats {
            switch family {
            case .systemMedium:
                MediumWidgetView(stats: stats)
            case .systemLarge:
                LargeWidgetView(stats: stats, showPercentage: entry.showPercentage, stageDisplayMode: entry.stageDisplayMode)
            default:
                MediumWidgetView(stats: stats)
            }
        } else {
            NoDataView()
        }
    }
}

// MARK: - Medium Widget (2x1)

struct MediumWidgetView: View {
    let stats: PerformanceEntry.DivisionStats

    var body: some View {
        VStack(spacing: 8) {
            // Header - Classification and division
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                Text(stats.classification.rawValue)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(classificationColor(stats.classification))
                Text("·")
                    .foregroundStyle(.secondary)
                Text(stats.division.rawValue)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Main stats - 3 boxes
            HStack(spacing: 6) {
                // Time box
                VStack(spacing: 2) {
                    Text("Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", NSDecimalNumber(decimal: stats.totalTime).doubleValue))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.green.opacity(0.1))
                .cornerRadius(8)

                // Percent box
                VStack(spacing: 2) {
                    Text("Percent")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", NSDecimalNumber(decimal: stats.percentage).doubleValue))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(performanceColor(for: stats.percentage))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(performanceColor(for: stats.percentage).opacity(0.1))
                .cornerRadius(8)

                // Last match box
                if let days = stats.daysSinceLastMatch {
                    VStack(spacing: 2) {
                        Text("Last Match")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(days) \(days == 1 ? "day" : "days")")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(daysSinceMatchColor(days: days))
                            .monospacedDigit()
                        Text("ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(daysSinceMatchColor(days: days).opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private func classificationColor(_ classification: ShooterClass) -> Color {
        switch classification {
        case .GM: return .yellow
        case .M: return .purple
        case .A: return .green
        case .B: return .blue
        case .C: return .orange
        default: return .gray
        }
    }

    private func performanceColor(for percentage: Decimal) -> Color {
        let perf = NSDecimalNumber(decimal: percentage).doubleValue
        switch perf {
        case 95...: return .green
        case 85..<95: return .blue
        case 75..<85: return .orange
        default: return .red
        }
    }

    private func daysSinceMatchColor(days: Int) -> Color {
        switch days {
        case 0...7: return .green
        case 8...30: return .blue
        case 31...60: return .orange
        default: return .red
        }
    }
}

// MARK: - Large Widget (2x2)

struct LargeWidgetView: View {
    let stats: PerformanceEntry.DivisionStats
    let showPercentage: Bool
    let stageDisplayMode: StageDisplayMode

    var body: some View {
        VStack(spacing: 8) {
            // Header
            headerView

            // Main stats
            HStack(spacing: 6) {
                // Time box
                VStack(spacing: 2) {
                    Text("Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", NSDecimalNumber(decimal: stats.totalTime).doubleValue))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.green.opacity(0.1))
                .cornerRadius(8)

                // Percent box
                VStack(spacing: 2) {
                    Text("Percent")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", NSDecimalNumber(decimal: stats.percentage).doubleValue))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(performanceColor(for: stats.percentage))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(performanceColor(for: stats.percentage).opacity(0.1))
                .cornerRadius(8)

                // Last match box
                if let days = stats.daysSinceLastMatch {
                    VStack(spacing: 2) {
                        Text("Last Match")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(days) \(days == 1 ? "day" : "days")")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(daysSinceMatchColor(days: days))
                            .monospacedDigit()
                        Text("ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(daysSinceMatchColor(days: days).opacity(0.1))
                    .cornerRadius(8)
                }
            }

            Spacer()

            // Classification scores - 2 rows of 4 stages
            if !stats.stageScores.isEmpty {
                VStack(spacing: 4) {
                    // Show first 4 stages
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { index in
                            if index < stats.stageScores.count {
                                let stage = stats.stageScores[index]
                                StageScoreBox(
                                    stage: stage,
                                    showPercentage: showPercentage,
                                    displayMode: stageDisplayMode,
                                    isBest: stats.bestStageCode == stage.stageCode,
                                    isWorst: stats.worstStageCode == stage.stageCode
                                )
                            } else {
                                Color.clear
                            }
                        }
                    }

                    // Show next 4 stages if available
                    if stats.stageScores.count > 4 {
                        HStack(spacing: 4) {
                            ForEach(4..<8, id: \.self) { index in
                                if index < stats.stageScores.count {
                                    let stage = stats.stageScores[index]
                                    StageScoreBox(
                                        stage: stage,
                                        showPercentage: showPercentage,
                                        displayMode: stageDisplayMode,
                                        isBest: stats.bestStageCode == stage.stageCode,
                                        isWorst: stats.worstStageCode == stage.stageCode
                                    )
                                } else {
                                    Color.clear
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
            Text(stats.classification.rawValue)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(classificationColor(stats.classification))
            Text("·")
                .foregroundStyle(.secondary)
            Text(stats.division.rawValue)
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()

            Link(destination: URL(string: "gmjuice://settings/widget")!) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    private func classificationColor(_ classification: ShooterClass) -> Color {
        switch classification {
        case .GM: return .yellow
        case .M: return .purple
        case .A: return .green
        case .B: return .blue
        case .C: return .orange
        default: return .gray
        }
    }

    private func performanceColor(for percentage: Decimal) -> Color {
        let perf = NSDecimalNumber(decimal: percentage).doubleValue
        switch perf {
        case 95...: return .green
        case 85..<95: return .blue
        case 75..<85: return .orange
        default: return .red
        }
    }

    private func daysSinceMatchColor(days: Int) -> Color {
        switch days {
        case 0...7: return .green
        case 8...30: return .blue
        case 31...60: return .orange
        default: return .red
        }
    }
}

// MARK: - Stat Box Component (matching Analysis view style)

struct StatBox: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Stage Score Box (for large widget)

struct StageScoreBox: View {
    let stage: PerformanceEntry.StageScore
    let showPercentage: Bool
    let displayMode: StageDisplayMode
    let isBest: Bool
    let isWorst: Bool

    var body: some View {
        VStack(spacing: 2) {
            // Main value based on display mode
            Group {
                switch displayMode {
                case .classification, .all:
                    if showPercentage {
                        Text(String(format: "%.2f%%", NSDecimalNumber(decimal: stage.percentage).doubleValue))
                            .font(.system(size: 16, weight: .bold))
                            .monospacedDigit()
                    } else {
                        Text(classification.rawValue)
                            .font(.system(size: 18, weight: .bold))
                    }
                case .percentage:
                    Text(String(format: "%.2f%%", NSDecimalNumber(decimal: stage.percentage).doubleValue))
                        .font(.system(size: 16, weight: .bold))
                        .monospacedDigit()
                case .time:
                    Text(String(format: "%.2fs", NSDecimalNumber(decimal: stage.time).doubleValue))
                        .font(.system(size: 16, weight: .bold))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(classificationColor)

            // Stage name
            Text(stageName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Stage code
            Text(stage.stageCode)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .background(classificationColor.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: isBest || isWorst ? 2 : 0)
        )
    }

    private var borderColor: Color {
        if isBest {
            return .green
        } else if isWorst {
            return .red
        } else {
            return .clear
        }
    }

    private var classification: ShooterClass {
        ShooterClass.shooterClass(percentage: stage.percentage)
    }

    private var stageName: String {
        switch stage.stageCode {
        case "SC-101": return "5 To Go"
        case "SC-102": return "Showdown"
        case "SC-103": return "Smoke & Hope"
        case "SC-104": return "Outer Limits"
        case "SC-105": return "Accelerator"
        case "SC-106": return "Pendulum"
        case "SC-107": return "Speed Option"
        case "SC-108": return "Roundabout"
        default: return ""
        }
    }

    private var classificationColor: Color {
        switch classification {
        case .GM: return .yellow
        case .M: return .purple
        case .A: return .green
        case .B: return .blue
        case .C: return .orange
        default: return .gray
        }
    }
}

// MARK: - No Data View

struct NoDataView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Match Data")
                .font(.headline)
            Text("Compete in matches to see your classification progress")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// MARK: - Previews

#Preview("Medium - GM Performance", as: .systemMedium) {
    GMJuiceWidget()
} timeline: {
    PerformanceEntry(
        date: Date(),
        divisionStats: PerformanceEntry.DivisionStats(
            division: .RFPO,
            classification: .GM,
            totalTime: 71.25,
            percentage: 97,
            daysSinceLastMatch: 7,
            totalStages: 8,
            stageScores: [],
            bestStageCode: nil,
            worstStageCode: nil,
            lastMatchName: nil,
            bestRecentStages: []
        ),
        showPercentage: false,
        stageDisplayMode: .classification
    )
}

#Preview("Medium - A Class", as: .systemMedium) {
    GMJuiceWidget()
} timeline: {
    PerformanceEntry(
        date: Date(),
        divisionStats: PerformanceEntry.DivisionStats(
            division: .CO,
            classification: .A,
            totalTime: 92.50,
            percentage: 78,
            daysSinceLastMatch: 14,
            totalStages: 8,
            stageScores: [],
            bestStageCode: nil,
            worstStageCode: nil,
            lastMatchName: nil,
            bestRecentStages: []
        ),
        showPercentage: false,
        stageDisplayMode: .classification
    )
}

#Preview("Large - Master Class", as: .systemLarge) {
    GMJuiceWidget()
} timeline: {
    PerformanceEntry(
        date: Date(),
        divisionStats: PerformanceEntry.DivisionStats(
            division: .PROD,
            classification: .M,
            totalTime: 85.75,
            percentage: 89,
            daysSinceLastMatch: 3,
            totalStages: 8,
            stageScores: [
                PerformanceEntry.StageScore(stageCode: "SC-101", time: 10.85, percentage: 92),
                PerformanceEntry.StageScore(stageCode: "SC-102", time: 8.95, percentage: 89),
                PerformanceEntry.StageScore(stageCode: "SC-103", time: 9.20, percentage: 91),
                PerformanceEntry.StageScore(stageCode: "SC-104", time: 12.45, percentage: 88),
                PerformanceEntry.StageScore(stageCode: "SC-105", time: 10.30, percentage: 90),
                PerformanceEntry.StageScore(stageCode: "SC-106", time: 11.50, percentage: 87),
                PerformanceEntry.StageScore(stageCode: "SC-107", time: 11.75, percentage: 89),
                PerformanceEntry.StageScore(stageCode: "SC-108", time: 8.75, percentage: 91)
            ],
            bestStageCode: "SC-103",
            worstStageCode: "SC-106",
            lastMatchName: "Local Club Match",
            bestRecentStages: [
                PerformanceEntry.StageScore(stageCode: "SC-101", time: 10.85, percentage: 92),
                PerformanceEntry.StageScore(stageCode: "SC-103", time: 9.20, percentage: 91),
                PerformanceEntry.StageScore(stageCode: "SC-108", time: 8.75, percentage: 91),
                PerformanceEntry.StageScore(stageCode: "SC-105", time: 10.30, percentage: 90)
            ]
        ),
        showPercentage: false,
        stageDisplayMode: .classification
    )
}

#Preview("Large - B Class", as: .systemLarge) {
    GMJuiceWidget()
} timeline: {
    PerformanceEntry(
        date: Date(),
        divisionStats: PerformanceEntry.DivisionStats(
            division: .RFPI,
            classification: .B,
            totalTime: 105.20,
            percentage: 68,
            daysSinceLastMatch: 45,
            totalStages: 7,
            stageScores: [
                PerformanceEntry.StageScore(stageCode: "SC-101", time: 14.20, percentage: 72),
                PerformanceEntry.StageScore(stageCode: "SC-102", time: 12.50, percentage: 68),
                PerformanceEntry.StageScore(stageCode: "SC-103", time: 11.85, percentage: 65),
                PerformanceEntry.StageScore(stageCode: "SC-104", time: 18.40, percentage: 62),
                PerformanceEntry.StageScore(stageCode: "SC-105", time: 13.75, percentage: 70),
                PerformanceEntry.StageScore(stageCode: "SC-106", time: 15.60, percentage: 67),
                PerformanceEntry.StageScore(stageCode: "SC-107", time: 16.90, percentage: 64)
            ],
            bestStageCode: "SC-101",
            worstStageCode: "SC-104",
            lastMatchName: "State Championship",
            bestRecentStages: [
                PerformanceEntry.StageScore(stageCode: "SC-101", time: 14.20, percentage: 72),
                PerformanceEntry.StageScore(stageCode: "SC-105", time: 13.75, percentage: 70),
                PerformanceEntry.StageScore(stageCode: "SC-102", time: 12.50, percentage: 68),
                PerformanceEntry.StageScore(stageCode: "SC-106", time: 15.60, percentage: 67)
            ]
        ),
        showPercentage: false,
        stageDisplayMode: .classification
    )
}

#Preview("Medium - No Data", as: .systemMedium) {
    GMJuiceWidget()
} timeline: {
    PerformanceEntry(date: Date(), divisionStats: nil, showPercentage: false, stageDisplayMode: .classification)
}

#Preview("Large - No Data", as: .systemLarge) {
    GMJuiceWidget()
} timeline: {
    PerformanceEntry(date: Date(), divisionStats: nil, showPercentage: false, stageDisplayMode: .classification)
}

#Preview("Large - GM Performance", as: .systemLarge) {
    GMJuiceWidget()
} timeline: {
    PerformanceEntry(
        date: Date(),
        divisionStats: PerformanceEntry.DivisionStats(
            division: .RFPO,
            classification: .GM,
            totalTime: 71.25,
            percentage: 97,
            daysSinceLastMatch: 7,
            totalStages: 8,
            stageScores: [
                PerformanceEntry.StageScore(stageCode: "SC-101", time: 8.95, percentage: 98),
                PerformanceEntry.StageScore(stageCode: "SC-102", time: 7.65, percentage: 98),
                PerformanceEntry.StageScore(stageCode: "SC-103", time: 7.14, percentage: 98),
                PerformanceEntry.StageScore(stageCode: "SC-104", time: 11.73, percentage: 98),
                PerformanceEntry.StageScore(stageCode: "SC-105", time: 8.68, percentage: 98),
                PerformanceEntry.StageScore(stageCode: "SC-106", time: 9.69, percentage: 98),
                PerformanceEntry.StageScore(stageCode: "SC-107", time: 10.20, percentage: 98),
                PerformanceEntry.StageScore(stageCode: "SC-108", time: 7.65, percentage: 98)
            ],
            bestStageCode: "SC-103",
            worstStageCode: "SC-104",
            lastMatchName: "Steel Challenge World Championship",
            bestRecentStages: [
                PerformanceEntry.StageScore(stageCode: "SC-103", time: 7.14, percentage: 98.5),
                PerformanceEntry.StageScore(stageCode: "SC-102", time: 7.65, percentage: 98.2),
                PerformanceEntry.StageScore(stageCode: "SC-108", time: 7.65, percentage: 98.0),
                PerformanceEntry.StageScore(stageCode: "SC-105", time: 8.68, percentage: 97.8)
            ]
        ),
        showPercentage: false,
        stageDisplayMode: .classification
    )
}
