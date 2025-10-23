import SwiftUI
import SwiftData

struct StageDayDetailView: View {
    let dayStart: Date
    let stageId: String
    let divisionId: String

    @Environment(\.modelContext) private var modelContext
    @Query private var strings: [StringRun]

    init(dayStart: Date, stageId: String, divisionId: String) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: dayStart)
        let end = cal.date(byAdding: .day, value: 1, to: start)!

        self.dayStart = start
        self.stageId = stageId
        self.divisionId = divisionId

        _strings = Query(
            filter: #Predicate<StringRun> {
                $0.stageId == stageId && $0.divisionId == divisionId && $0.date >= start && $0.date < end
            },
            sort: [SortDescriptor(\StringRun.date, order: .reverse)]
        )
    }

    var body: some View {
        List {
            // SUMMARY
            if !strings.isEmpty {
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

                    NavigationLink {
                        ReportView(strings: strings, stageId: stageId, divisionId: divisionId)
                    } label: {
                        Label("Performance Analysis", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }
            }
            
            let bestRunID = strings.min(by: { $0.time < $1.time })?.id

            // RUNS
            ForEach(strings) { run in
                // Keep newest-first order, but index should count from oldest (1..N)
                if let pos = strings.firstIndex(where: { $0.id == run.id }) {
                    let idx = strings.count - pos
                    let isBest = (run.id == bestRunID)

                    StringRowView(run: run, index: idx, isBest: isBest)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRun(run) // delete immediately (no confirmation)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteRun(run)
                            } label: {
                                Label("Delete String", systemImage: "trash")
                            }
                        }
                }
            }
            .onDelete(perform: deleteAtOffsets) // still supports EditButton
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(stageId) - \(stageName(for: stageId)) - \(divisionId) - \(titleDate(dayStart))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }

    // MARK: - Summary

    private var summary: (totalCount: Int,
                          fastestRun: Decimal,
                          avgRun: Decimal,
                          slowestRun: Decimal,
                          fastestFirstShot: Decimal,
                          avgFirstShot: Decimal,
                          slowestFirstShot: Decimal) {

        // Totals use last shot's 'now'
        let totals: [Decimal] = strings.compactMap { $0.orderedStringShots.last?.now }

        // First-shot times use first shot's 'first'
        let firsts: [Decimal] = strings.compactMap { $0.orderedStringShots.first?.first }

        let totalCount = strings.count
        let fastestRun = totals.min() ?? 0
        let slowestRun = totals.max() ?? 0
        let fastestFirst = firsts.min() ?? 0
        let slowestFirst = firsts.max() ?? 0
        let avgRun = (totals.isEmpty ? 0 : totals.reduce(0, +) / Decimal(totals.count)).rounded(toPlaces: 2)
        let avgFirst = (firsts.isEmpty ? 0 : firsts.reduce(0, +) / Decimal(firsts.count)).rounded(toPlaces: 2)

        return (totalCount, fastestRun, avgRun, slowestRun, fastestFirst, avgFirst, slowestFirst)
    }

    // MARK: - Helpers

    private func titleDate(_ d: Date) -> String {
        d.formatted(.dateTime.month(.abbreviated).day().year())
    }

    // MARK: - Deletion helpers

    private func deleteAtOffsets(_ offsets: IndexSet) {
        for index in offsets {
            guard strings.indices.contains(index) else { continue }
            modelContext.delete(strings[index])
        }
        do { try modelContext.save() }
        catch { print("Failed to delete selected StringRuns: \(error)") }
    }

    private func deleteRun(_ run: StringRun) {
        withAnimation {
            modelContext.delete(run)
            do { try modelContext.save() }
            catch { print("Failed to delete StringRun: \(error)") }
        }
    }
}

extension Decimal {
    func rounded(toPlaces places: Int) -> Decimal {
        var result = Decimal()
        
        // Use `withUnsafePointer` to safely get a pointer to the non-mutable `self`.
        withUnsafePointer(to: self) { numberPointer in
            NSDecimalRound(&result, numberPointer, places, .plain)
        }
        
        return result
    }
}

#if DEBUG


#Preview("Stage Detail with Runs") {
    let stageId = "SC-101"
    let divisionId = Division.RFPO.rawValue
    
    let schema = Schema(versionedSchema: Schema001.self)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    let _ = {
        let context = container.mainContext
        
        // Create mock runs with different times
        let run1 = StringRun(
            stageId: stageId,
            divisionId: divisionId,
            date: Date(),
            time: 2.17
        )
        let run2 = StringRun(
            stageId: stageId,
            divisionId: divisionId,
            date: Date().addingTimeInterval(-3600),
            time: 2.21
        )
        let run3 = StringRun(
            stageId: stageId,
            divisionId: divisionId,
            date: Date().addingTimeInterval(-7200),
            time: 2.35
        )
                
        context.insert(run1)
        context.insert(run2)
        context.insert(run3)
    }()
    
    NavigationStack {
        StageDayDetailView(
            dayStart: Calendar.current.startOfDay(for: Date()),
            stageId: stageId,
            divisionId: divisionId
        )
        .modelContainer(container)
    }
}
#endif
