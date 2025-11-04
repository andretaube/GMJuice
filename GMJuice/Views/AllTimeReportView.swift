import SwiftUI
import Charts
import SwiftData

struct AllTimeReportView: View {
    @Query(sort: [SortDescriptor(\StringRun.date, order: .forward)])
    private var allStrings: [StringRun]

    var body: some View {
        List {
            ForEach(divisionSections, id: \.divisionId) { division in
                Section(division.divisionName) {
                    ForEach(division.stages, id: \.stageId) { stage in
                        NavigationLink {
                            StageReportDetailView(
                                stageId: stage.stageId,
                                stageName: stage.stageName,
                                divisionId: division.divisionId,
                                divisionName: division.divisionName,
                                strings: stage.strings
                            )
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(stage.stageId) – \(stage.stageName)")
                                        .font(.body)

                                    HStack(spacing: 12) {
                                        Label {
                                            Text("×\(stage.count)")
                                                .monospacedDigit()
                                        } icon: {
                                            Image(systemName: "number")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                        Label {
                                            Text(String(format: "%.2f", NSDecimalNumber(decimal: stage.best).doubleValue))
                                                .monospacedDigit()
                                        } icon: {
                                            Image(systemName: "medal.fill")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Performance Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Data Processing

    private var divisionSections: [DivisionSection] {
        // Group by divisionId
        let byDivision: [String: [StringRun]] = Dictionary(
            grouping: allStrings,
            by: { $0.divisionId }
        )

        // Order divisions by enum order
        let knownOrder = Division.allCases.map(\.rawValue)
        let orderedDivisionIds: [String] = byDivision.keys.sorted { a, b in
            let ia = knownOrder.firstIndex(of: a) ?? .max
            let ib = knownOrder.firstIndex(of: b) ?? .max
            return ia < ib || (ia == ib && a < b)
        }

        return orderedDivisionIds.map { divisionId in
            let runsInDivision = byDivision[divisionId] ?? []

            // Group by stageId within division
            let byStage: [String: [StringRun]] = Dictionary(
                grouping: runsInDivision,
                by: { $0.stageId }
            )
            let sortedStageIds = byStage.keys.sorted()

            let stageSections: [StageSection] = sortedStageIds.map { stageId in
                let runs = byStage[stageId] ?? []
                let best = runs.map(\.time).min() ?? 0
                return StageSection(
                    stageId: stageId,
                    stageName: stageName(for: stageId),
                    count: runs.count,
                    best: best,
                    strings: runs
                )
            }

            return DivisionSection(
                divisionId: divisionId,
                divisionName: displayName(for: divisionId),
                stages: stageSections
            )
        }
    }

    private func displayName(for divisionId: String) -> String {
        Division(rawValue: divisionId)?.displayName ?? divisionId
    }

    // MARK: - DTOs

    private struct DivisionSection {
        let divisionId: String
        let divisionName: String
        let stages: [StageSection]
    }

    private struct StageSection {
        let stageId: String
        let stageName: String
        let count: Int
        let best: Decimal
        let strings: [StringRun]
    }
}

// MARK: - Stage Report Detail View

struct StageReportDetailView: View {
    let stageId: String
    let stageName: String
    let divisionId: String
    let divisionName: String
    let strings: [StringRun]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary stats
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Runs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(strings.count)")
                                .font(.title2.bold())
                                .monospacedDigit()
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Best Time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let best = strings.map({ $0.time }).min() {
                                Text(String(format: "%.2f", NSDecimalNumber(decimal: best).doubleValue))
                                    .font(.title2.bold())
                                    .monospacedDigit()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal)

                // First Shot Time Chart
                VStack(alignment: .leading, spacing: 8) {
                    GraphHeader(
                        title: "First Shot Time",
                        explanation: "Tracks your draw-to-first-shot time across all runs for this stage and division. Grouped data shows trends over time. Lower times indicate faster, more efficient draw and presentation. Consistent performance here is key to competitive Steel Challenge shooting."
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
                        explanation: "Your complete string times from buzzer to final shot across all practice sessions. This is your official score. Watch for long-term improvement trends and identify plateaus where you might need to adjust training focus. Compare against GM benchmarks to gauge classification level."
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

                // MARK: - Shot Detection Analytics

                // Hit Rate Per Target
                if hasHitData {
                    VStack(alignment: .leading, spacing: 8) {
                        GraphHeader(
                            title: "Hit Rate by Target",
                            explanation: "Shows what percentage of the time you hit each target on the first shot. Higher is better. Identifies problematic targets or transitions. Use this to guide your dry fire practice - focus on the targets where your hit rate is lowest."
                        )

                        Chart {
                            ForEach(1...5, id: \.self) { targetNum in
                                BarMark(
                                    x: .value("Target", targetLabel(targetNum)),
                                    y: .value("Hit %", hitRateForTarget(targetNum))
                                )
                                .foregroundStyle(Color.blue)
                                .annotation(position: .top) {
                                    Text("\(Int(hitRateForTarget(targetNum)))%")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let intValue = value.as(Int.self) {
                                        Text("\(intValue)%")
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let stringValue = value.as(String.self) {
                                        Text(stringValue)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .frame(height: 180)
                        .padding()
                    }

                    // Overall Hit Rate Trend
                    VStack(alignment: .leading, spacing: 8) {
                        GraphHeader(
                            title: "Hit Rate Trend",
                            explanation: "Overall hit percentage across all 5 targets for each run over time. Shows whether your accuracy is improving, declining, or staying consistent. An upward trend means you're shooting more accurately. Aim for consistent performance above 95%."
                        )

                        Chart {
                            ForEach(Array(hitRateTrendData.enumerated()), id: \.offset) { index, dataPoint in
                                LineMark(
                                    x: .value("Group", dataPoint.label),
                                    y: .value("Hit %", dataPoint.value)
                                )
                                .foregroundStyle(.blue)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Group", dataPoint.label),
                                    y: .value("Hit %", dataPoint.value)
                                )
                                .foregroundStyle(.blue)
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text("\(Int(doubleValue))%")
                                    }
                                }
                            }
                        }
                        .chartXAxis(.hidden)
                        .frame(height: 180)
                        .padding()
                    }

                    // Average Split Time Per Target Position
                    VStack(alignment: .leading, spacing: 8) {
                        GraphHeader(
                            title: "Split Time by Target",
                            explanation: "Average time between each shot for each target position. Shows which transitions are slowest. First shot includes draw time. Compare splits to identify where you're losing time - slow transitions, awkward target sequences, or long stop plate splits all indicate areas to improve."
                        )

                        Chart {
                            ForEach(1...5, id: \.self) { targetNum in
                                BarMark(
                                    x: .value("Target", targetLabel(targetNum)),
                                    y: .value("Split", avgSplitForTarget(targetNum))
                                )
                                .foregroundStyle(Color.blue)
                                .annotation(position: .top) {
                                    Text(String(format: "%.2f", avgSplitForTarget(targetNum)))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
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
                        .chartXAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let stringValue = value.as(String.self) {
                                        Text(stringValue)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .frame(height: 180)
                        .padding()
                    }

                    // First Shot Hit Rate Trend
                    VStack(alignment: .leading, spacing: 8) {
                        GraphHeader(
                            title: "First Shot Accuracy Trend",
                            explanation: "Tracks whether you're hitting the first target cleanly on your initial shot. Critical for fast times since misses here cost you both accuracy and time. An improving trend shows your draw and presentation are getting more consistent. Top shooters maintain near 100% first shot accuracy."
                        )

                        Chart {
                            ForEach(Array(firstShotHitRateTrend.enumerated()), id: \.offset) { index, dataPoint in
                                LineMark(
                                    x: .value("Group", dataPoint.label),
                                    y: .value("Hit %", dataPoint.value)
                                )
                                .foregroundStyle(.blue)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Group", dataPoint.label),
                                    y: .value("Hit %", dataPoint.value)
                                )
                                .foregroundStyle(.blue)
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text("\(Int(doubleValue))%")
                                    }
                                }
                            }
                        }
                        .chartXAxis(.hidden)
                        .frame(height: 180)
                        .padding()
                    }

                    // Make-Up Shot Analysis
                    VStack(alignment: .leading, spacing: 8) {
                        GraphHeader(
                            title: "Make-Up Shots per Run",
                            explanation: "Number of missed targets per run that required additional shots. Lower is better - fewer makeups mean cleaner, more accurate shooting. A downward trend shows improving accuracy and target acquisition. Zero makeups means all 5 shots were first-round hits (perfect string)."
                        )

                        Chart {
                            ForEach(Array(makeupShotsTrend.enumerated()), id: \.offset) { index, dataPoint in
                                LineMark(
                                    x: .value("Group", dataPoint.label),
                                    y: .value("Makeups", dataPoint.value)
                                )
                                .foregroundStyle(.orange)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Group", dataPoint.label),
                                    y: .value("Makeups", dataPoint.value)
                                )
                                .foregroundStyle(.orange)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text(String(format: "%.1f", doubleValue))
                                    }
                                }
                            }
                        }
                        .chartXAxis(.hidden)
                        .frame(height: 180)
                        .padding()
                    }
                }

                // Performance Consistency Metrics
                VStack(alignment: .leading, spacing: 8) {
                    GraphHeader(
                        title: "Consistency Score",
                        explanation: "Rolling standard deviation of your last 10 run times. Lower values mean more consistent performance - your times are tightly grouped. High consistency is the hallmark of advanced shooters. Inconsistency suggests technique issues, mental game problems, or physical fatigue affecting your shooting."
                    )

                    Chart {
                        ForEach(Array(consistencyScoreTrend.enumerated()), id: \.offset) { index, dataPoint in
                            LineMark(
                                x: .value("Group", dataPoint.label),
                                y: .value("Std Dev", dataPoint.value)
                            )
                            .foregroundStyle(.purple)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Group", dataPoint.label),
                                y: .value("Std Dev", dataPoint.value)
                            )
                            .foregroundStyle(.purple)
                        }
                    }
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

                VStack(alignment: .leading, spacing: 8) {
                    GraphHeader(
                        title: "Best vs Average Gap",
                        explanation: "Shows the difference between your best time and average time in a rolling 10-run window. A shrinking gap indicates maturing skill - you're approaching your peak performance more consistently. Large gaps suggest you occasionally shoot well but can't repeat it reliably yet. Top shooters have minimal gaps."
                    )

                    Chart {
                        ForEach(Array(bestVsAvgGapTrend.enumerated()), id: \.offset) { index, dataPoint in
                            LineMark(
                                x: .value("Group", dataPoint.label),
                                y: .value("Gap", dataPoint.value)
                            )
                            .foregroundStyle(.indigo)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Group", dataPoint.label),
                                y: .value("Gap", dataPoint.value)
                            )
                            .foregroundStyle(.indigo)
                        }
                    }
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
            }
            .padding(.vertical)
        }
        .navigationTitle("\(stageId) – \(divisionName)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Functions

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

    // MARK: - Shot Detection Helpers

    private var hasHitData: Bool {
        // Always return true since we now track targets (missedTargets array)
        // Any run with 5+ shots has target data
        strings.contains { $0.stringShots.count >= 5 }
    }

    private func targetLabel(_ targetNum: Int) -> String {
        targetNum == 5 ? "Stop" : "T\(targetNum)"
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

    private var hitRateTrendData: [(label: String, value: Double)] {
        // Calculate overall hit rate for each run (5 targets total)
        let hitRates = strings.compactMap { run -> Double? in
            guard run.stringShots.count >= 5 else { return nil }

            let hits = 5 - run.missedTargets.count
            return (Double(hits) / 5.0) * 100.0
        }

        guard !hitRates.isEmpty else { return [] }
        return groupData(values: hitRates, maxGroups: 25)
    }

    private func avgSplitForTarget(_ targetNum: Int) -> Double {
        let targetIndex = targetNum - 1
        var splits: [Double] = []

        for run in strings {
            if targetIndex < run.orderedStringShots.count {
                let shot = run.orderedStringShots[targetIndex]
                splits.append(NSDecimalNumber(decimal: shot.split).doubleValue)
            }
        }

        guard !splits.isEmpty else { return 0.0 }
        return splits.reduce(0.0, +) / Double(splits.count)
    }

    // Graph 4: First Target Hit Rate Trend (Target 1)
    private var firstShotHitRateTrend: [(label: String, value: Double)] {
        let firstTargetHitRates = strings.compactMap { run -> Double? in
            guard run.stringShots.count >= 5 else { return nil }

            // Check if target 1 was missed
            return run.missedTargets.contains(1) ? 0.0 : 100.0
        }

        guard !firstTargetHitRates.isEmpty else { return [] }
        return groupData(values: firstTargetHitRates, maxGroups: 25)
    }

    // Graph 6: Make-Up Shot Analysis
    private var makeupShotsTrend: [(label: String, value: Double)] {
        let makeupCounts = strings.compactMap { run -> Double? in
            guard run.stringShots.count >= 5 else { return nil }

            // Number of makeup shots = total missed targets
            return Double(run.missedTargets.count)
        }

        guard !makeupCounts.isEmpty else { return [] }
        return groupData(values: makeupCounts, maxGroups: 25)
    }

    // Graph 8: Consistency Score (rolling standard deviation)
    private var consistencyScoreTrend: [(label: String, value: Double)] {
        let times = strings.map { run -> Double in
            NSDecimalNumber(decimal: run.time).doubleValue
        }

        guard !times.isEmpty else { return [] }

        // Calculate rolling standard deviation with window of 10 runs
        let windowSize = 10
        var stdDevs: [Double] = []

        for i in 0..<times.count {
            let start = max(0, i - windowSize + 1)
            let window = times[start...i]
            let stdDev = standardDeviation(Array(window))
            stdDevs.append(stdDev)
        }

        return groupData(values: stdDevs, maxGroups: 25)
    }

    // Graph 9: Best vs Average Gap
    private var bestVsAvgGapTrend: [(label: String, value: Double)] {
        let times = strings.map { run -> Double in
            NSDecimalNumber(decimal: run.time).doubleValue
        }

        guard !times.isEmpty else { return [] }

        // Calculate rolling gap with window of 10 runs
        let windowSize = 10
        var gaps: [Double] = []

        for i in 0..<times.count {
            let start = max(0, i - windowSize + 1)
            let window = times[start...i]
            let best = window.min() ?? 0.0
            let avg = window.reduce(0.0, +) / Double(window.count)
            gaps.append(avg - best)
        }

        return groupData(values: gaps, maxGroups: 25)
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }

        let mean = values.reduce(0.0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(values.count)
        return sqrt(variance)
    }
}

#if DEBUG
#Preview("Performance Analysis") {
    let schema = Schema(versionedSchema: Schema004.self)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    let _ = {
        let context = container.mainContext

        // Create mock data for multiple divisions and stages
        for divIndex in 0..<2 {
            let division = Division.allCases[divIndex]
            for stageIndex in 0..<3 {
                let stage = AllStages[stageIndex]
                for runIndex in 0..<10 {
                    let run = StringRun(
                        stageId: stage.code,
                        divisionId: division.rawValue,
                        date: Date().addingTimeInterval(Double(runIndex * 3600)),
                        time: Decimal(2.0 + Double.random(in: 0.1...0.5))
                    )

                    // Add mock shots
                    let firstShot = 0.8 + Double.random(in: 0.0...0.2)
                    let shot1 = StringShot(now: Decimal(firstShot), split: Decimal(firstShot), first: Decimal(firstShot))
                    let shot2 = StringShot(now: Decimal(firstShot + 0.4), split: Decimal(0.4), first: Decimal(firstShot))
                    let shot3 = StringShot(now: Decimal(firstShot + 0.8), split: Decimal(0.4), first: Decimal(firstShot))
                    let shot4 = StringShot(now: Decimal(firstShot + 1.2), split: Decimal(0.4), first: Decimal(firstShot))
                    let shot5 = StringShot(now: run.time, split: run.time - Decimal(firstShot + 1.2), first: Decimal(firstShot))
                    run.stringShots = [shot1, shot2, shot3, shot4, shot5]

                    context.insert(run)
                }
            }
        }
    }()

    return NavigationStack {
        AllTimeReportView()
            .modelContainer(container)
    }
}
#endif
