//
//  StageProgressReportView.swift
//  GMJuice
//
//  Created by Claude on 11/3/25.
//

import SwiftUI
import SwiftData
import Charts

struct StageProgressReportView: View {
    let divisionCode: String

    @Query private var allProfiles: [ShooterProfile]

    private var divisionDisplayName: String {
        Division(rawValue: divisionCode)?.displayName ?? divisionCode
    }

    private var currentUserNumber: String? {
        UserDefaults.standard.currentUserUSPSANumber
    }

    private var myProfile: ShooterProfile? {
        guard let currentUser = currentUserNumber else {
            return allProfiles.first
        }
        return allProfiles.first { $0.uspsaNumber == currentUser }
    }

    private var currentClassification: ShooterClass {
        guard let division = Division(rawValue: divisionCode),
              let profile = myProfile,
              let divProfile = profile.divisions.first(where: { $0.division == division }) else {
            return .U
        }
        return divProfile.classification
    }

    private var divisionScores: [MatchScore] {
        guard let profile = myProfile else { return [] }
        return profile.matchScores.filter {
            $0.divisionCode == divisionCode &&
            NSDecimalNumber(decimal: $0.time).doubleValue <= 30.0
        }
        .sorted { $0.scoreDate < $1.scoreDate }
    }

    // Remove high outliers using IQR (Interquartile Range) method
    // Keep low outliers (fast times are achievements!)
    private func removeOutliers(from scores: [MatchScore]) -> [MatchScore] {
        guard scores.count >= 4 else { return scores } // Need at least 4 data points for IQR

        let times = scores.map { NSDecimalNumber(decimal: $0.time).doubleValue }.sorted()

        // Calculate quartiles
        let q1Index = times.count / 4
        let q3Index = (times.count * 3) / 4
        let q1 = times[q1Index]
        let q3 = times[q3Index]
        let iqr = q3 - q1

        // Calculate upper outlier bound only
        // Using 1.5 * IQR is standard for outlier detection
        let upperBound = q3 + (1.5 * iqr)

        // Filter out only high outliers (slow times)
        return scores.filter {
            let time = NSDecimalNumber(decimal: $0.time).doubleValue
            return time <= upperBound
        }
    }

    private var stageGroups: [(stageCode: String, stageName: String, scores: [MatchScore])] {
        let grouped = Dictionary(grouping: divisionScores) { $0.stageCode }
        return grouped.map { (stageCode: $0.key, stageName: stageName(for: $0.key), scores: removeOutliers(from: $0.value.sorted { $0.scoreDate < $1.scoreDate })) }
            .sorted { $0.stageCode < $1.stageCode }
    }

    // Calculate linear regression trend line
    private func calculateTrendLine(for scores: [MatchScore]) -> [(x: Int, y: Double)] {
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
                if divisionScores.isEmpty {
                    ContentUnavailableView {
                        Label("No Scores", systemImage: "chart.line.uptrend.xyaxis")
                    } description: {
                        Text("No match scores found for \(divisionDisplayName)")
                    }
                } else {
                    ForEach(stageGroups, id: \.stageCode) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            // Stage header
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.stageCode)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(group.stageName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            // Chart
                            if group.scores.count >= 2 {
                                let times = group.scores.map { NSDecimalNumber(decimal: $0.time).doubleValue }
                                let peakTimes = group.scores.map { NSDecimalNumber(decimal: $0.peakTime).doubleValue }
                                let allValues = times + peakTimes
                                let minValue = allValues.min() ?? 0
                                let maxValue = allValues.max() ?? 30

                                // Add 10% padding above and below
                                let range = maxValue - minValue
                                let padding = max(range * 0.1, 0.5)  // At least 0.5 second padding
                                let yMin = max(0, minValue - padding)
                                let yMax = maxValue + padding

                                // Set reasonable X-axis domain to prevent stretching
                                let scoreCount = group.scores.count
                                let xMax = max(6, scoreCount)  // Show at least 6 match positions

                                // Calculate trend line
                                let trendLine = calculateTrendLine(for: group.scores)

                                Chart {
                                    // Trend line (smooth)
                                    ForEach(Array(trendLine.enumerated()), id: \.offset) { _, point in
                                        LineMark(
                                            x: .value("Match", point.x),
                                            y: .value("Trend", point.y)
                                        )
                                        .foregroundStyle(.gray.opacity(0.6))
                                        .lineStyle(StrokeStyle(lineWidth: 3))
                                    }

                                    // Actual data points and line
                                    ForEach(Array(group.scores.enumerated()), id: \.offset) { index, score in
                                        LineMark(
                                            x: .value("Match", index + 1),
                                            y: .value("Time", NSDecimalNumber(decimal: score.time).doubleValue)
                                        )
                                        .foregroundStyle(.blue)

                                        PointMark(
                                            x: .value("Match", index + 1),
                                            y: .value("Time", NSDecimalNumber(decimal: score.time).doubleValue)
                                        )
                                        .foregroundStyle(.blue)

                                        // Peak time reference line
                                        RuleMark(
                                            y: .value("Peak", NSDecimalNumber(decimal: score.peakTime).doubleValue)
                                        )
                                        .foregroundStyle(.yellow)
                                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                    }
                                }
                                .chartXScale(domain: 1...xMax)
                                .chartYScale(domain: yMin...yMax)
                                .chartYAxisLabel("Time (seconds)")
                                .chartXAxisLabel("Match Number")
                                .frame(height: 200)
                                .padding(.vertical, 8)
                            }

                            // Stats
                            if let bestTime = group.scores.map({ $0.time }).min() {
                                let bestTimeDouble = NSDecimalNumber(decimal: bestTime).doubleValue
                                let peakTime = group.scores.first?.peakTime ?? Decimal(0)
                                let peakTimeDouble = NSDecimalNumber(decimal: peakTime).doubleValue

                                HStack(spacing: 20) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trophy.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.green)
                                            Text("Best")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text("\(bestTimeDouble, specifier: "%.2f")")
                                            .font(.headline)
                                            .foregroundStyle(.green)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        if currentClassification != .GM {
                                            // Show next class level
                                            let nextClass: String = {
                                                switch currentClassification {
                                                case .M: return "GM"
                                                case .A: return "M"
                                                case .B: return "A"
                                                case .C: return "B"
                                                case .D: return "C"
                                                case .U: return "D"
                                                case .GM: return "GM"
                                                }
                                            }()

                                            Text(nextClass)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)

                                            // Show time needed to reach next class
                                            let nextThreshold = currentClassification.nextClassThreshold
                                            let nextThresholdDouble = NSDecimalNumber(decimal: nextThreshold).doubleValue
                                            let targetTime = (peakTimeDouble / nextThresholdDouble) * 100.0
                                            let timeToShave = bestTimeDouble - targetTime

                                            if timeToShave > 0 {
                                                Text("-\(timeToShave, specifier: "%.2f")")
                                                    .font(.headline)
                                                    .foregroundStyle(.blue)
                                            } else {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title2)
                                                    .foregroundStyle(.green)
                                            }
                                        } else {
                                            // Already GM - show Peak target
                                            Text("Peak")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)

                                            let timeToShave = bestTimeDouble - peakTimeDouble

                                            if timeToShave > 0 {
                                                Text("-\(timeToShave, specifier: "%.2f")")
                                                    .font(.headline)
                                                    .foregroundStyle(.blue)
                                            } else {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title2)
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Peak")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(peakTimeDouble, specifier: "%.2f")")
                                            .font(.headline)
                                            .foregroundStyle(.yellow)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Matches")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(group.scores.count)")
                                            .font(.headline)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("\(divisionCode) Progress")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let container: ModelContainer = {
        let schema = Schema(versionedSchema: Schema004.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        // Create sample data
        let dates = [
            Calendar.current.date(byAdding: .day, value: -60, to: Date())!,
            Calendar.current.date(byAdding: .day, value: -45, to: Date())!,
            Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
            Calendar.current.date(byAdding: .day, value: -15, to: Date())!,
        ]

        let times = [8.5, 8.2, 7.9, 7.6]

        for (index, date) in dates.enumerated() {
            let score = MatchScore(
                matchName: "Match \(index + 1)",
                scoreDate: date,
                stageCode: "SC-101",
                divisionCode: "RFPO",
                time: Decimal(times[index]),
                peakTime: Decimal(7.10),
                usedForClassification: true
            )
            context.insert(score)
        }

        try? context.save()
        
        return container
    }()

    NavigationStack {
        StageProgressReportView(divisionCode: "RFPO")
    }
    .modelContainer(container)
}
