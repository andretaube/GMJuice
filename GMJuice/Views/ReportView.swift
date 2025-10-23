import SwiftUI
import Charts

struct ReportView: View {
    let strings: [StringRun]
    let stageId: String
    let divisionId: String

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // First Shot Time Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("First Shot Time")
                        .font(.headline)
                        .padding(.horizontal)

                    Chart {
                        ForEach(Array(strings.enumerated().reversed()), id: \.element.id) { index, run in
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
                        ForEach(Array(strings.enumerated().reversed()), id: \.element.id) { index, run in
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
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Report with Sample Data") {
    let stageId = "SC-101"
    let divisionId = Division.RFPO.rawValue

    // Create mock runs
    let runs = [
        createMockRun(stageId: stageId, divisionId: divisionId, time: 2.17, firstShot: 0.85),
        createMockRun(stageId: stageId, divisionId: divisionId, time: 2.21, firstShot: 0.91),
        createMockRun(stageId: stageId, divisionId: divisionId, time: 2.35, firstShot: 0.95),
        createMockRun(stageId: stageId, divisionId: divisionId, time: 2.12, firstShot: 0.82),
        createMockRun(stageId: stageId, divisionId: divisionId, time: 2.18, firstShot: 0.88),
    ]

    return NavigationStack {
        ReportView(strings: runs, stageId: stageId, divisionId: divisionId)
    }
}

private func createMockRun(stageId: String, divisionId: String, time: Double, firstShot: Double) -> StringRun {
    let run = StringRun(stageId: stageId, divisionId: divisionId, date: Date(), time: Decimal(time))

    // Create mock shots
    let shot1 = StringShot(now: Decimal(firstShot), split: Decimal(firstShot), first: Decimal(firstShot))
    let shot2 = StringShot(now: Decimal(firstShot + 0.4), split: Decimal(0.4), first: Decimal(firstShot))
    let shot3 = StringShot(now: Decimal(firstShot + 0.8), split: Decimal(0.4), first: Decimal(firstShot))
    let shot4 = StringShot(now: Decimal(firstShot + 1.2), split: Decimal(0.4), first: Decimal(firstShot))
    let shot5 = StringShot(now: Decimal(time), split: Decimal(time - firstShot - 1.2), first: Decimal(firstShot))

    run.stringShots = [shot1, shot2, shot3, shot4, shot5]
    return run
}
#endif
