import SwiftUI
import Charts

// MARK: - Graph Header with Info Button

struct GraphHeader: View {
    let title: String
    let explanation: String
    @State private var showingInfo = false

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Button {
                showingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingInfo) {
            NavigationStack {
                ScrollView {
                    Text(explanation)
                        .font(.body)
                        .padding()
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingInfo = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

struct ReportView: View {
    let strings: [StringRun]
    let stageId: String
    let divisionId: String

    @State private var heatMapDisplayLimit: Int = 20

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // First Shot Time Chart
                VStack(alignment: .leading, spacing: 8) {
                    GraphHeader(
                        title: "First Shot Time",
                        explanation: "Shows how your first shot time (draw to first shot) changes over your training session. Lower values indicate faster draw and presentation. Look for a downward trend showing improvement as you warm up and build rhythm."
                    )

                    Chart {
                        // Grouped data points
                        ForEach(Array(firstShotGroupedData.enumerated()), id: \.offset) { index, dataPoint in
                            LineMark(
                                x: .value("Group", dataPoint.label),
                                y: .value("Time", dataPoint.value)
                            )
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Group", dataPoint.label),
                                y: .value("Time", dataPoint.value)
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                    .chartYScale(domain: firstShotYDomain)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text(String(format: "%.2f", doubleValue))
                                }
                            }
                        }
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 180)
                    .padding()
                }

                // Total Time Chart
                VStack(alignment: .leading, spacing: 8) {
                    GraphHeader(
                        title: "Total Time",
                        explanation: "Shows your total string time from start signal to last shot. This is your final score for each run. Lower is better. Look for consistent times or a downward trend indicating skill improvement. Compare against your division's benchmarks to track classification progress."
                    )

                    Chart {
                        // Grouped data points
                        ForEach(Array(totalTimeGroupedData.enumerated()), id: \.offset) { index, dataPoint in
                            LineMark(
                                x: .value("Group", dataPoint.label),
                                y: .value("Time", dataPoint.value)
                            )
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Group", dataPoint.label),
                                y: .value("Time", dataPoint.value)
                            )
                            .foregroundStyle(.green)
                        }
                    }
                    .chartYScale(domain: totalTimeYDomain)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text(String(format: "%.2f", doubleValue))
                                }
                            }
                        }
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 180)
                    .padding()
                }

                // MARK: - Hit Analysis

                // Hit Analysis Overview
                VStack(alignment: .leading, spacing: 8) {
                    GraphHeader(
                        title: "Hit Analysis Overview",
                        explanation: "Shows your hit rate percentage for each target and the stop plate. Higher percentages mean better accuracy. Target accuracy issues help identify which transitions or target positions need more practice. The stop plate (5th position) is typically the most critical."
                    )

                    // Hit Rate by Target (Bars)
                    Chart {
                        ForEach(1...5, id: \.self) { targetNum in
                            BarMark(
                                x: .value("Target", targetLabel(targetNum)),
                                y: .value("Hit %", hitRateForTarget(targetNum))
                            )
                            .foregroundStyle(Color.blue)
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("\(Int(doubleValue))%")
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                    .padding()
                }

                // Detailed Hit Rate Per Target
                VStack(alignment: .leading, spacing: 8) {
                    GraphHeader(
                        title: "Hit Rate by Target",
                        explanation: "Detailed view of your hit percentage for each target position with exact percentages displayed. Use this to identify specific targets where you struggle and need to focus your practice. Consistent 100% across all targets is the goal."
                    )

                    Chart {
                        ForEach(1...5, id: \.self) { targetNum in
                            BarMark(
                                x: .value("Target", targetLabel(targetNum)),
                                y: .value("Hit %", hitRateForTarget(targetNum))
                            )
                            .foregroundStyle(Color.blue.opacity(0.8))
                            .annotation(position: .top) {
                                Text("\(Int(hitRateForTarget(targetNum)))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("\(Int(doubleValue))%")
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                    .padding()
                }

                // Option 2: Heat Map Grid
                VStack(alignment: .leading, spacing: 8) {
                    GraphHeader(
                        title: "Hit/Miss Pattern",
                        explanation: "Visual grid showing hit (✓) and miss (✗) patterns for each target across your runs. Green indicates hits, red indicates misses. Use this to spot patterns in your shooting - like consistently missing the same target or missing more frequently when fatigued. Each row represents one string run."
                    )

                    // Toggle buttons for display limit
                    HStack {
                        Text("Show:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Last 20") {
                            heatMapDisplayLimit = 20
                        }
                        .buttonStyle(.bordered)
                        .tint(heatMapDisplayLimit == 20 ? .blue : .gray)

                        Button("Last 50") {
                            heatMapDisplayLimit = 50
                        }
                        .buttonStyle(.bordered)
                        .tint(heatMapDisplayLimit == 50 ? .blue : .gray)

                        Button("All") {
                            heatMapDisplayLimit = Int.max
                        }
                        .buttonStyle(.bordered)
                        .tint(heatMapDisplayLimit == Int.max ? .blue : .gray)

                        Spacer()

                        Text("\(displayedRuns.count) runs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    ScrollView {
                        VStack(spacing: 4) {
                            // Header row
                            HStack(spacing: 4) {
                                Text("Run")
                                    .font(.caption)
                                    .frame(width: 40, alignment: .leading)
                                ForEach(1...5, id: \.self) { targetNum in
                                    Text(targetNum == 5 ? "Stop" : "T\(targetNum)")
                                        .font(.caption)
                                        .frame(maxWidth: .infinity)
                                        .foregroundColor(targetNum == 5 ? .red : .primary)
                                }
                            }
                            .padding(.horizontal)

                            // Data rows (filtered by display limit) - reversed to show most recent first
                            ForEach(Array(displayedRuns.reversed().enumerated()), id: \.element.id) { displayIndex, run in
                                let originalIndex = strings.firstIndex(where: { $0.id == run.id }) ?? 0
                                HStack(spacing: 4) {
                                    Text("#\(originalIndex + 1)")
                                        .font(.caption)
                                        .frame(width: 40, alignment: .leading)
                                    ForEach(1...5, id: \.self) { targetNum in
                                        let isMissed = run.missedTargets.contains(targetNum)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(isMissed ? Color.red.opacity(0.8) : Color.green.opacity(0.6))
                                            .frame(height: 30)
                                            .overlay(
                                                Text(isMissed ? "✗" : "✓")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    .frame(maxHeight: 400)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Functions

    private var displayedRuns: [StringRun] {
        let sortedRuns = strings.sorted { $0.date < $1.date }
        if heatMapDisplayLimit >= sortedRuns.count {
            return sortedRuns
        } else {
            return Array(sortedRuns.suffix(heatMapDisplayLimit))
        }
    }

    private var firstShotGroupedData: [(label: String, value: Double)] {
        let firstShots = strings.compactMap { run -> Double? in
            guard let first = run.orderedStringShots.first?.first else { return nil }
            return NSDecimalNumber(decimal: first).doubleValue
        }
        return groupData(values: firstShots, maxGroups: 25)
    }

    private var totalTimeGroupedData: [(label: String, value: Double)] {
        let totalTimes = strings.compactMap { run -> Double? in
            guard let total = run.orderedStringShots.last?.now else { return nil }
            return NSDecimalNumber(decimal: total).doubleValue
        }
        return groupData(values: totalTimes, maxGroups: 25)
    }

    private var firstShotYDomain: ClosedRange<Double> {
        let firstShots = strings.compactMap { run -> Double? in
            guard let first = run.orderedStringShots.first?.first else { return nil }
            return NSDecimalNumber(decimal: first).doubleValue
        }
        guard !firstShots.isEmpty else { return 0.3...2.0 }

        let minValue = firstShots.min() ?? 0.3
        let maxValue = firstShots.max() ?? 2.0
        let range = maxValue - minValue

        // Min - 10%, but not below 0.3
        let yMin = max(0.3, minValue - (range * 0.1))
        // Max + 5% for headroom
        let yMax = maxValue + (range * 0.05)

        return yMin...yMax
    }

    private var totalTimeYDomain: ClosedRange<Double> {
        let totalTimes = strings.compactMap { run -> Double? in
            guard let total = run.orderedStringShots.last?.now else { return nil }
            return NSDecimalNumber(decimal: total).doubleValue
        }
        guard !totalTimes.isEmpty else { return 1.0...5.0 }

        let minValue = totalTimes.min() ?? 1.0
        let maxValue = totalTimes.max() ?? 5.0
        let range = maxValue - minValue

        // Min - 10%, but not below 1.0
        let yMin = max(1.0, minValue - (range * 0.1))
        // Max + 5% for headroom
        let yMax = maxValue + (range * 0.05)

        return yMin...yMax
    }

    private func groupData(values: [Double], maxGroups: Int) -> [(label: String, value: Double)] {
        guard !values.isEmpty else { return [] }

        let totalCount = values.count

        // If we have fewer than maxGroups, show each individual run
        if totalCount <= maxGroups {
            return values.enumerated().map { index, value in
                (label: "#\(index + 1)", value: value)
            }
        }

        // Otherwise, group into bins
        let groupSize = Int(ceil(Double(totalCount) / Double(maxGroups)))
        var result: [(label: String, value: Double)] = []

        for groupIndex in 0..<maxGroups {
            let start = groupIndex * groupSize
            let end = min(start + groupSize, totalCount)

            guard start < totalCount else { break }

            let group = values[start..<end]
            let average = group.reduce(0.0, +) / Double(group.count)

            // Label: show range of runs in this group
            let label: String
            if groupSize == 1 {
                label = "#\(start + 1)"
            } else {
                label = "\(start + 1)-\(end)"
            }

            result.append((label: label, value: average))
        }

        return result
    }

    private func targetLabel(_ targetNum: Int) -> String {
        targetNum == 5 ? "Stop Plate" : "Target \(targetNum)"
    }

    private func hitRateForTarget(_ targetNum: Int) -> Double {
        var totalRuns = 0
        var hitCount = 0

        for run in strings {
            // Only count runs that have completed (5+ shots)
            guard run.stringShots.count >= 5 else { continue }

            totalRuns += 1

            // If target is not in missedTargets, it's a hit
            if !run.missedTargets.contains(targetNum) {
                hitCount += 1
            }
        }

        guard totalRuns > 0 else { return 0.0 }
        return (Double(hitCount) / Double(totalRuns)) * 100.0
    }
}

#if DEBUG
#Preview("Report with Sample Data") {
    let stageId = "SC-101"
    let divisionId = Division.RFPO.rawValue

    // Create mock runs with varied hit/miss patterns (500 runs to demonstrate filtering)
    var runs: [StringRun] = []

    let patterns: [[Bool]] = [
        [true, true, true, true, true],   // All hits
        [true, false, true, true, true],  // Miss on target 2
        [true, true, true, false, true],  // Miss on target 4
        [true, true, false, true, true],  // Miss on target 3
        [true, true, true, true, false],  // Miss on stop plate
        [true, false, true, false, true], // Misses on 2 and 4
        [false, true, true, true, true],  // Miss on target 1
        [true, true, true, true, true],   // All hits
        [true, true, true, true, true],   // All hits (more common)
        [true, true, true, true, true],   // All hits (more common)
    ]

    // Generate 500 runs cycling through patterns
    for i in 0..<500 {
        let pattern = patterns[i % patterns.count]
        let time = 2.0 + Double.random(in: 0.08...0.45)
        let firstShot = 0.75 + Double.random(in: 0.05...0.20)

        runs.append(createMockRun(
            stageId: stageId,
            divisionId: divisionId,
            time: time,
            firstShot: firstShot,
            hitPattern: pattern
        ))
    }

    return NavigationStack {
        ReportView(strings: runs, stageId: stageId, divisionId: divisionId)
    }
}

private func createMockRun(stageId: String, divisionId: String, time: Double, firstShot: Double, hitPattern: [Bool]) -> StringRun {
    let run = StringRun(stageId: stageId, divisionId: divisionId, date: Date(), time: Decimal(time))

    // Create mock shots
    let shot1 = StringShot(now: Decimal(firstShot), split: Decimal(firstShot), first: Decimal(firstShot))
    let shot2 = StringShot(now: Decimal(firstShot + 0.4), split: Decimal(0.4), first: Decimal(firstShot))
    let shot3 = StringShot(now: Decimal(firstShot + 0.8), split: Decimal(0.4), first: Decimal(firstShot))
    let shot4 = StringShot(now: Decimal(firstShot + 1.2), split: Decimal(0.4), first: Decimal(firstShot))
    let shot5 = StringShot(now: Decimal(time), split: Decimal(time - firstShot - 1.2), first: Decimal(firstShot))

    run.stringShots = [shot1, shot2, shot3, shot4, shot5]

    // Convert hit pattern to missed targets
    var missedTargets: [Int] = []
    for (index, isHit) in hitPattern.enumerated() {
        if !isHit {
            missedTargets.append(index + 1)  // Targets are 1-5
        }
    }
    run.missedTargets = missedTargets

    return run
}
#endif
