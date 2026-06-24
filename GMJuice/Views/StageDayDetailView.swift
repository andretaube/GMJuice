import SwiftUI
import SwiftData
import Charts

struct StageDayDetailView: View {
    let dayStart: Date
    let stageId: String
    let divisionId: String

    @Environment(\.modelContext) private var modelContext
    @Query private var stages: [StageRun]
    @Query private var allForStage: [StageRun]

    init(dayStart: Date, stageId: String, divisionId: String) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: dayStart)
        let end = cal.date(byAdding: .day, value: 1, to: start)!

        self.dayStart = start
        self.stageId = stageId
        self.divisionId = divisionId

        _stages = Query(
            filter: #Predicate<StageRun> {
                $0.stageId == stageId && $0.divisionId == divisionId && $0.date >= start && $0.date < end
            },
            sort: [SortDescriptor(\StageRun.date, order: .forward)]
        )
        _allForStage = Query(
            filter: #Predicate<StageRun> {
                $0.stageId == stageId && $0.divisionId == divisionId
            },
            sort: [SortDescriptor(\StageRun.date, order: .forward)]
        )
    }

    private var division: Division? { Division(rawValue: divisionId) }
    private var peakTime: Decimal {
        guard let division else { return 0 }
        return CurrentPeakBenchmarks.get(division: division, stageCode: stageId)?.peakTime ?? 0
    }

    var body: some View {
        List {
            if !stages.isEmpty {
                Section("Summary") {
                    SummaryView(
                        total: summary.totalCount,
                        fastestRun: summary.fastestRun,
                        avgRun: summary.avgRun,
                        slowestRun: summary.slowestRun,
                        fastestFirstShot: summary.fastestFirstShot,
                        avgFirstShot: summary.avgFirstShot,
                        slowestFirstShot: summary.slowestFirstShot
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            // E — best-4 trend across all sessions for this stage
            if allForStage.count >= 2 {
                Section("Best-4 trend · all sessions") {
                    Chart(Array(allForStage.suffix(30).enumerated()), id: \.offset) { idx, set in
                        LineMark(x: .value("Set", idx),
                                 y: .value("Time", NSDecimalNumber(decimal: set.bestNTime).doubleValue))
                            .foregroundStyle(.orange)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Set", idx),
                                  y: .value("Time", NSDecimalNumber(decimal: set.bestNTime).doubleValue))
                            .foregroundStyle(.orange)
                            .symbolSize(18)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 130)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
            }

            let bestID = stages.min(by: { $0.bestNTime < $1.bestNTime })?.id

            Section("Stages") {
                ForEach(Array(stages.enumerated().reversed()), id: \.element.id) { idx, set in
                    NavigationLink {
                        StageRunDetailView(stageRun: set, division: division, stageId: stageId)
                    } label: {
                        stageRow(set, number: idx + 1, isBest: set.id == bestID)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { deleteSet(set) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listRowBackground(Color.gmPanel)
        .gmScreenBackground()
        .navigationTitle("\(stageId) · \(stageName(for: stageId)) · \(divisionId)")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func stageRow(_ set: StageRun, number: Int, isBest: Bool) -> some View {
        let pct: Int = (peakTime > 0 && set.bestNTime > 0) ? NSDecimalNumber(decimal: peakTime / set.bestNTime * 100).intValue : 0
        let cls = ShooterClass.shooterClass(percentage: Decimal(pct))
        HStack(spacing: 10) {
            Text("Set \(number)").font(.subheadline).foregroundStyle(.secondary)
            if isBest { Image(systemName: "medal.fill").foregroundStyle(.yellow).imageScale(.small) }
            Spacer()
            Text("\(cls.rawValue) \(pct)%").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            Text(Format.formatTime(set.bestNTime)).font(.body.weight(.semibold)).monospacedDigit()
        }
    }

    // MARK: - Summary

    private var summary: (totalCount: Int, fastestRun: Decimal, avgRun: Decimal, slowestRun: Decimal,
                          fastestFirstShot: Decimal, avgFirstShot: Decimal, slowestFirstShot: Decimal) {
        let totals: [Decimal] = stages.map { $0.bestNTime }
        let firsts: [Decimal] = stages.flatMap { $0.strings }.compactMap { $0.orderedStringShots.first?.first }.filter { $0 > 0 }

        let totalCount = stages.count
        let fastestRun = totals.min() ?? 0
        let slowestRun = totals.max() ?? 0
        let fastestFirst = firsts.min() ?? 0
        let slowestFirst = firsts.max() ?? 0
        let avgRun = (totals.isEmpty ? 0 : totals.reduce(0, +) / Decimal(totals.count)).rounded(toPlaces: 2)
        let avgFirst = (firsts.isEmpty ? 0 : firsts.reduce(0, +) / Decimal(firsts.count)).rounded(toPlaces: 2)

        return (totalCount, fastestRun, avgRun, slowestRun, fastestFirst, avgFirst, slowestFirst)
    }

    private func deleteSet(_ set: StageRun) {
        withAnimation {
            modelContext.delete(set)
            do { try modelContext.save() } catch { print("Failed to delete StageRun: \(error)") }
        }
    }
}

// MARK: - Strings within one scored set

struct StageRunDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let stageRun: StageRun
    let division: Division?
    let stageId: String

    @State private var selectedRunForEdit: StringRun?

    private var orderedStrings: [StringRun] {
        stageRun.strings.sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            let worstID = orderedStrings.max(by: { $0.adjustedTime < $1.adjustedTime })?.id
            ForEach(Array(orderedStrings.enumerated()), id: \.element.id) { idx, run in
                StringRowView(run: run, index: idx + 1, isBest: false)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedRunForEdit = run }
                    .overlay(alignment: .trailing) {
                        if run.id == worstID && orderedStrings.count >= stageRun.stringCount {
                            Text("dropped").font(.caption2).foregroundStyle(.red).padding(.trailing, 4)
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Stage \(Format.formatTime(stageRun.bestNTime))")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedRunForEdit) { run in
            EditStringView(run: run)
        }
    }
}

extension Decimal {
    func rounded(toPlaces places: Int) -> Decimal {
        var result = Decimal()
        withUnsafePointer(to: self) { numberPointer in
            NSDecimalRound(&result, numberPointer, places, .plain)
        }
        return result
    }
}
