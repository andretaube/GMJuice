import SwiftUI
import SwiftData

struct LogView: View {
    // Fetch everything newest-first
    @Query(sort: [SortDescriptor(\StringRun.date, order: .reverse)])
    private var allStrings: [StringRun]

    var body: some View {
        NavigationStack {
            List {
                if allStrings.isEmpty {
                    Section {
                        Text("No sessions yet").foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(daySections, id: \.dayStart) { day in
                        Section(day.title) {
                            ForEach(day.divisions, id: \.divisionId) { div in
                                if !div.stageSummaries.isEmpty {
                                    Text(displayName(for: div.divisionId))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 4)

                                    ForEach(div.stageSummaries, id: \.self) { s in
                                        NavigationLink {
                                            StageDayDetailView(
                                                dayStart: day.dayStart,
                                                stageId: s.stageId,
                                                divisionId: s.divisionId
                                            )
                                        } label: {
                                            HStack(spacing: 8) {
                                                Text("\(s.stageId) – \(s.name)")
                                                    .lineLimit(1)

                                                Spacer()

                                                Label {
                                                    Text("\(s.best)").monospacedDigit()
                                                } icon: {
                                                    Image(systemName: "medal.fill") // or "trophy.circle.fill"
                                                }
                                                .labelStyle(.titleAndIcon)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)

                                                Text("×\(s.count)")
                                                    .font(.subheadline.monospacedDigit())
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Log")
        }
    }

    // MARK: - Build date → division → stage summaries (divisionId-based DTOs)

    private var daySections: [DaySection] {
        let cal = Calendar.current

        // Group all strings by start-of-day
        let byDay: [Date: [StringRun]] = Dictionary(
            grouping: allStrings,
            by: { cal.startOfDay(for: $0.date) }
        )

        let sortedDays = byDay.keys.sorted(by: >)

        return sortedDays.map { dayStart in
            let itemsForDay = (byDay[dayStart] ?? []).sorted { $0.date > $1.date }

            // Group by stored primitive divisionId
            let byDivisionId: [String: [StringRun]] = Dictionary(
                grouping: itemsForDay,
                by: { $0.divisionId }
            )

            // Order divisions by your enum order when possible; include unknowns at the end
            let knownOrder = Division.allCases.map(\.rawValue)
            let orderedDivisionIds: [String] = byDivisionId.keys.sorted { a, b in
                let ia = knownOrder.firstIndex(of: a) ?? .max
                let ib = knownOrder.firstIndex(of: b) ?? .max
                return ia < ib || (ia == ib && a < b)
            }

            let divisionSummaries: [DivisionSection] = orderedDivisionIds.map { divisionId in
                let runsInDivision = byDivisionId[divisionId] ?? []

                // Group by stageId within this division
                let byStage: [String: [StringRun]] = Dictionary(
                    grouping: runsInDivision,
                    by: { $0.stageId }
                )
                let sortedStageIds = byStage.keys.sorted()

                let stageSummaries: [StageSummary] = sortedStageIds.map { sid in
                    let runs = byStage[sid] ?? []
                    let best = runs.map(\.time).min() ?? 0
                    let count = runs.count
                    return StageSummary(
                        stageId: sid,
                        divisionId: divisionId,
                        name: stageName(for: sid),
                        best: best,
                        count: count
                    )
                }

                return DivisionSection(divisionId: divisionId, stageSummaries: stageSummaries)
            }

            return DaySection(
                dayStart: dayStart,
                title: dayTitle(for: dayStart),
                divisions: divisionSummaries
            )
        }
    }

    private func dayTitle(for dayStart: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(dayStart) { return "Today" }
        if cal.isDateInYesterday(dayStart) { return "Yesterday" }
        return dayStart.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func displayName(for divisionId: String) -> String {
        Division(rawValue: divisionId)?.displayName ?? divisionId
    }

    // MARK: - DTOs

    private struct DaySection: Hashable {
        let dayStart: Date
        let title: String
        let divisions: [DivisionSection]
    }

    private struct DivisionSection: Hashable {
        let divisionId: String
        let stageSummaries: [StageSummary]
    }

    private struct StageSummary: Hashable {
        let stageId: String
        let divisionId: String
        let name: String
        let best: Decimal
        let count: Int
    }
}
