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
                        fastestRun: timeString(summary.fastestRun),
                        avgRun: timeString(summary.avgRun),
                        slowestRun: timeString(summary.slowestRun),
                        fastestFirstShot: timeString(summary.fastestFirstShot),
                        avgFirstShot: timeString(summary.avgFirstShot),
                        slowestFirstShot: timeString(summary.slowestFirstShot)
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            // RUNS
            ForEach(strings) { run in
                // Keep newest-first order, but index should count from oldest (1..N)
                if let pos = strings.firstIndex(where: { $0.id == run.id }) {
                    let idx = strings.count - pos

                    StringRowView(run: run, index: idx)
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
                          fastestRun: Double,
                          avgRun: Double,
                          slowestRun: Double,
                          fastestFirstShot: Double,
                          avgFirstShot: Double,
                          slowestFirstShot: Double) {

        // Totals use last shot's 'now'
        let totals: [Double] = strings.compactMap { $0.orderedStringShots.last?.now }

        // First-shot times use first shot's 'first'
        let firsts: [Double] = strings.compactMap { $0.orderedStringShots.first?.first }

        let totalCount = strings.count
        let fastestRun = totals.min() ?? 0
        let slowestRun = totals.max() ?? 0
        let fastestFirst = firsts.min() ?? 0
        let slowestFirst = firsts.max() ?? 0
        let avgRun = totals.isEmpty ? 0 : totals.reduce(0, +) / Double(totals.count)
        let avgFirst = firsts.isEmpty ? 0 : firsts.reduce(0, +) / Double(firsts.count)

        return (totalCount, fastestRun, avgRun, slowestRun, fastestFirst, avgFirst, slowestFirst)
    }

    // MARK: - Helpers

    private func titleDate(_ d: Date) -> String {
        d.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func timeString(_ t: Double) -> String {
        let totalHundredths = Int((t * 100).rounded())
        let m = totalHundredths / 6000
        let s = (totalHundredths % 6000) / 100
        let h = totalHundredths % 100
        return m > 0 ? String(format: "%d:%02d.%02d", m, s, h)
                     : String(format: "%d.%02d", s, h)
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
