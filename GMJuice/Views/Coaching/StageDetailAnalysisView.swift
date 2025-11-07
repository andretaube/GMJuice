//
//  StageDetailAnalysisView.swift
//  GMJuice
//
//  Created by Claude on 11/5/25.
//

import SwiftUI
import SwiftData
import Charts

struct StageDetailAnalysisView: View {
    let stageAnalysis: StageAnalysis
    let divisionCode: String

    @Query private var allScores: [SCMatchScore]

    private var divisionDisplayName: String {
        Division(rawValue: divisionCode)?.displayName ?? divisionCode
    }

    private var stageScores: [SCMatchScore] {
        allScores.filter {
            $0.divisionCode == divisionCode &&
            $0.stageCode == stageAnalysis.stageCode &&
            NSDecimalNumber(decimal: $0.time).doubleValue <= 30.0
        }
        .sorted { $0.scoreDate < $1.scoreDate }
    }

    // Scores used for average calculation (same logic as SCPerformanceAnalyzer)
    private var recentScoresForAverage: [SCMatchScore] {
        let lookbackDate = Calendar.current.date(byAdding: .day, value: -AnalysisConstants.recentDaysWindow, to: Date()) ?? Date()
        let recentScores = stageScores.filter { $0.scoreDate >= lookbackDate }

        return AnalysisConstants.getRecentScores(recentScores: recentScores, allScores: stageScores)
    }

    // Calculate linear regression trend line
    private func calculateTrendLine(for scores: [SCMatchScore]) -> [(x: Int, y: Double)] {
        guard scores.count >= 2 else { return [] }

        let points = scores.enumerated().map { (x: Double($0.offset + 1), y: NSDecimalNumber(decimal: $0.element.time).doubleValue) }

        // Calculate linear regression: y = mx + b
        let n = Double(points.count)
        let sumX = points.reduce(0.0) { $0 + $1.x }
        let sumY = points.reduce(0.0) { $0 + $1.y }
        let sumXY = points.reduce(0.0) { $0 + ($1.x * $1.y) }
        let sumX2 = points.reduce(0.0) { $0 + ($1.x * $1.x) }

        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n

        // Generate trend line points
        return scores.indices.map { index in
            let x = index + 1
            let y = slope * Double(x) + intercept
            return (x: x, y: y)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Summary Stats Card
                VStack(alignment: .leading, spacing: 12) {
                    Label("Performance Summary", systemImage: "chart.bar.fill")
                        .font(.headline)
                        .foregroundStyle(.purple)

                    HStack(spacing: 12) {
                        summaryStatBox(
                            title: "Best",
                            value: String(format: "%.2fs", NSDecimalNumber(decimal: stageAnalysis.bestTime).doubleValue),
                            subtitle: stageAnalysis.bestClassification.rawValue,
                            color: .green
                        )

                        summaryStatBox(
                            title: "Average",
                            value: String(format: "%.2fs", NSDecimalNumber(decimal: stageAnalysis.averageTime).doubleValue),
                            subtitle: stageAnalysis.averageClassification.rawValue,
                            color: .blue
                        )

                        summaryStatBox(
                            title: "Peak (GM)",
                            value: String(format: "%.2fs", NSDecimalNumber(decimal: stageAnalysis.peakTime).doubleValue),
                            subtitle: "Target",
                            color: .yellow
                        )
                    }

                    HStack(spacing: 12) {
                        summaryStatBox(
                            title: "Performance",
                            value: String(format: "%.1f%%", NSDecimalNumber(decimal: stageAnalysis.performanceVsPeak).doubleValue),
                            subtitle: "vs Peak",
                            color: performanceColor
                        )

                        summaryStatBox(
                            title: "Consistency",
                            value: String(format: "±%.1f%%", NSDecimalNumber(decimal: stageAnalysis.consistencyScore).doubleValue),
                            subtitle: consistencyRating,
                            color: consistencyColor
                        )

                        summaryStatBox(
                            title: "Matches",
                            value: "\(stageAnalysis.matchCount)",
                            subtitle: "Total",
                            color: .purple
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Time Series Chart
                if stageScores.count >= 2 {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Performance Timeline", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.headline)
                            .foregroundStyle(.blue)

                        timeSeriesChart
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Recent Performance Chart (used for average calculation)
                if recentScoresForAverage.count >= 2 && recentScoresForAverage.count != stageScores.count {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Recent Performance", systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                            .foregroundStyle(.green)

                        Text("Data used for average calculation")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        recentPerformanceChart
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Distribution Chart (if enough data)
                if stageScores.count >= 5 {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Time Distribution", systemImage: "chart.bar.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)

                        distributionChart
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Recent vs Historical (if enough data)
                if stageScores.count >= 6 {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Recent Form", systemImage: "clock.fill")
                            .font(.headline)
                            .foregroundStyle(.green)

                        recentVsHistoricalView
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Match History Table
                if !stageScores.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Match History", systemImage: "list.bullet")
                            .font(.headline)
                            .foregroundStyle(.gray)

                        matchHistoryTable
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("\(stageAnalysis.stageCode) · \(divisionDisplayName)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Charts

    private var recentPerformanceChart: some View {
        let times = recentScoresForAverage.map { NSDecimalNumber(decimal: $0.time).doubleValue }
        let peakTime = NSDecimalNumber(decimal: stageAnalysis.peakTime).doubleValue
        let avgTime = NSDecimalNumber(decimal: stageAnalysis.averageTime).doubleValue
        let allValues = times + [peakTime, avgTime]
        let minValue = allValues.min() ?? 0
        let maxValue = allValues.max() ?? 30

        // Add 10% padding
        let range = maxValue - minValue
        let padding = max(range * 0.1, 0.5)
        let yMin = max(0, minValue - padding)
        let yMax = maxValue + padding

        let scoreCount = recentScoresForAverage.count
        let xMax = max(6, scoreCount)

        let trendLine = calculateTrendLine(for: recentScoresForAverage)

        return VStack(spacing: 8) {
            Chart {
                // Trend line
                ForEach(Array(trendLine.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Match", point.x),
                        y: .value("Trend", point.y)
                    )
                    .foregroundStyle(.gray.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 3, dash: [5, 5]))
                }

                // Average line
                RuleMark(
                    y: .value("Average", avgTime)
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 3]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Avg")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                }

                // Peak time reference
                RuleMark(
                    y: .value("Peak", peakTime)
                )
                .foregroundStyle(.yellow)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .annotation(position: .bottom, alignment: .trailing) {
                    Text("GM Peak")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                }

                // Actual times
                ForEach(Array(recentScoresForAverage.enumerated()), id: \.offset) { index, score in
                    LineMark(
                        x: .value("Match", index + 1),
                        y: .value("Time", NSDecimalNumber(decimal: score.time).doubleValue)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Match", index + 1),
                        y: .value("Time", NSDecimalNumber(decimal: score.time).doubleValue)
                    )
                    .foregroundStyle(.green)
                    .symbol {
                        Circle()
                            .fill(.green)
                            .frame(width: score.usedForClassification ? 10 : 6)
                            .overlay(
                                score.usedForClassification ?
                                Circle().stroke(.yellow, lineWidth: 2) : nil
                            )
                    }
                }
            }
            .chartXScale(domain: 1...xMax)
            .chartYScale(domain: yMin...yMax)
            .chartYAxisLabel("Time (seconds)")
            .chartXAxisLabel("Match Number (Recent)")
            .frame(height: 200)

            Text("\(scoreCount) matches from last 90 days or most recent 10")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var timeSeriesChart: some View {
        let times = stageScores.map { NSDecimalNumber(decimal: $0.time).doubleValue }
        let peakTime = NSDecimalNumber(decimal: stageAnalysis.peakTime).doubleValue
        let allValues = times + [peakTime]
        let minValue = allValues.min() ?? 0
        let maxValue = allValues.max() ?? 30

        // Add 10% padding
        let range = maxValue - minValue
        let padding = max(range * 0.1, 0.5)
        let yMin = max(0, minValue - padding)
        let yMax = maxValue + padding

        let scoreCount = stageScores.count
        let xMax = max(6, scoreCount)

        let trendLine = calculateTrendLine(for: stageScores)

        return Chart {
            // Trend line
            ForEach(Array(trendLine.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Match", point.x),
                    y: .value("Trend", point.y)
                )
                .foregroundStyle(.gray.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 3, dash: [5, 5]))
            }

            // Peak time reference
            RuleMark(
                y: .value("Peak", peakTime)
            )
            .foregroundStyle(.yellow)
            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
            .annotation(position: .top, alignment: .trailing) {
                Text("GM Peak")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
            }

            // Actual times
            ForEach(Array(stageScores.enumerated()), id: \.offset) { index, score in
                LineMark(
                    x: .value("Match", index + 1),
                    y: .value("Time", NSDecimalNumber(decimal: score.time).doubleValue)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Match", index + 1),
                    y: .value("Time", NSDecimalNumber(decimal: score.time).doubleValue)
                )
                .foregroundStyle(.blue)
                .symbol {
                    Circle()
                        .fill(.blue)
                        .frame(width: score.usedForClassification ? 10 : 6)
                        .overlay(
                            score.usedForClassification ?
                            Circle().stroke(.yellow, lineWidth: 2) : nil
                        )
                }
            }
        }
        .chartXScale(domain: 1...xMax)
        .chartYScale(domain: yMin...yMax)
        .chartYAxisLabel("Time (seconds)")
        .chartXAxisLabel("Match Number")
        .frame(height: 220)
        .padding(.vertical, 8)
    }

    // MARK: - Distribution Chart

    private var distributionChart: some View {
        let times = stageScores.map { NSDecimalNumber(decimal: $0.time).doubleValue }
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 30
        let range = maxTime - minTime

        // Create bins (5 bins for distribution)
        let binCount = min(5, times.count)
        let binSize = range / Double(binCount)

        var bins: [(range: String, count: Int)] = []
        for i in 0..<binCount {
            let binMin = minTime + Double(i) * binSize
            let binMax = binMin + binSize
            let count = times.filter { $0 >= binMin && $0 < binMax }.count
            bins.append((range: String(format: "%.1f-%.1f", binMin, binMax), count: count))
        }

        return VStack {
            Chart(bins, id: \.range) { bin in
                BarMark(
                    x: .value("Time Range", bin.range),
                    y: .value("Count", bin.count)
                )
                .foregroundStyle(.orange.gradient)
            }
            .chartYAxisLabel("Frequency")
            .chartXAxisLabel("Time Range (s)")
            .frame(height: 180)

            Text("Shows how your times are distributed across ranges")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // MARK: - Recent vs Historical

    private var recentVsHistoricalView: some View {
        let recentCount = min(3, stageScores.count / 2)
        let recentScores = Array(stageScores.suffix(recentCount))
        let historicalScores = stageScores

        let recentAvg = recentScores.map { NSDecimalNumber(decimal: $0.time).doubleValue }.reduce(0.0, +) / Double(recentScores.count)
        let historicalAvg = historicalScores.map { NSDecimalNumber(decimal: $0.time).doubleValue }.reduce(0.0, +) / Double(historicalScores.count)
        let improvement = ((historicalAvg - recentAvg) / historicalAvg) * 100.0

        return VStack(spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Form")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2fs", recentAvg))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("Last \(recentCount) matches")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("All-Time Avg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2fs", historicalAvg))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    Text("\(historicalScores.count) total matches")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            HStack(spacing: 8) {
                Image(systemName: improvement > 0 ? "arrow.up.circle.fill" : improvement < 0 ? "arrow.down.circle.fill" : "minus.circle.fill")
                    .foregroundStyle(improvement > 0 ? .green : improvement < 0 ? .red : .gray)
                Text(String(format: "%.1f%% %@", abs(improvement), improvement > 0 ? "improvement" : improvement < 0 ? "decline" : "stable"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(improvement > 0 ? .green : improvement < 0 ? .red : .gray)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
    }

    // MARK: - Match History Table

    private var matchHistoryTable: some View {
        VStack(spacing: 8) {
            ForEach(Array(stageScores.reversed().enumerated()), id: \.offset) { index, score in
                let percentage = score.peakTime > 0 ? (score.peakTime / score.time) * 100 : 0
                let scoreClass = ShooterClass.shooterClass(percentage: percentage)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(score.matchName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(score.scoreDate, format: .dateTime.month(.abbreviated).day().year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            if score.usedForClassification {
                                Image(systemName: "trophy.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                            Text(String(format: "%.2fs", NSDecimalNumber(decimal: score.time).doubleValue))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                        Text("\(scoreClass.rawValue) · \(String(format: "%.1f%%", NSDecimalNumber(decimal: percentage).doubleValue))")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Helper Views

    private func summaryStatBox(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Computed Properties

    private var performanceColor: Color {
        let perf = NSDecimalNumber(decimal: stageAnalysis.performanceVsPeak).doubleValue
        switch perf {
        case 85...: return .green
        case 75..<85: return .blue
        case 65..<75: return .orange
        default: return .red
        }
    }

    private var consistencyColor: Color {
        let consistency = NSDecimalNumber(decimal: stageAnalysis.consistencyScore).doubleValue
        switch consistency {
        case 0..<3: return .green
        case 3..<5: return .blue
        case 5..<8: return .orange
        default: return .red
        }
    }

    private var consistencyRating: String {
        let consistency = NSDecimalNumber(decimal: stageAnalysis.consistencyScore).doubleValue
        switch consistency {
        case 0..<3: return "Excellent"
        case 3..<5: return "Good"
        case 5..<8: return "Fair"
        default: return "Inconsistent"
        }
    }
}
