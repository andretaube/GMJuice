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
                    Text("First Shot Time")
                        .font(.headline)
                        .padding(.horizontal)

                    Chart {
                        ForEach(Array(strings.enumerated()), id: \.element.id) { index, run in
                            if let firstShot = run.orderedStringShots.first?.first {
                                LineMark(
                                    x: .value("Run", index + 1),
                                    y: .value("Time", NSDecimalNumber(decimal: firstShot).doubleValue)
                                )
                                .foregroundStyle(.blue)
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Run", index + 1),
                                    y: .value("Time", NSDecimalNumber(decimal: firstShot).doubleValue)
                                )
                                .foregroundStyle(.blue)
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
                            AxisGridLine()
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("#\(intValue)")
                                }
                            }
                        }
                    }
                    .frame(height: 250)
                    .padding()
                }

                // Total Time Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Time")
                        .font(.headline)
                        .padding(.horizontal)

                    Chart {
                        ForEach(Array(strings.enumerated()), id: \.element.id) { index, run in
                            if let totalTime = run.orderedStringShots.last?.now {
                                LineMark(
                                    x: .value("Run", index + 1),
                                    y: .value("Time", NSDecimalNumber(decimal: totalTime).doubleValue)
                                )
                                .foregroundStyle(.green)
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Run", index + 1),
                                    y: .value("Time", NSDecimalNumber(decimal: totalTime).doubleValue)
                                )
                                .foregroundStyle(.green)
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
                            AxisGridLine()
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("#\(intValue)")
                                }
                            }
                        }
                    }
                    .frame(height: 250)
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("\(stageId) – \(divisionName)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Performance Analysis") {
    let schema = Schema(versionedSchema: Schema001.self)
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
