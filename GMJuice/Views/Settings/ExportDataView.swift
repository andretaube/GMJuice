import SwiftUI
import SwiftData
import CoreGraphics

struct ExportDataView: View {
    @Query(sort: [SortDescriptor<StringRun>(\.date, order: .reverse)])
    private var allStrings: [StringRun]
    @Query(sort: [SortDescriptor<StageRun>(\.date, order: .reverse)])
    private var allStages: [StageRun]

    @State private var csvURL: URL?
    @State private var reportURL: URL?

    var body: some View {
        List {
            // MARK: Session report (PDF)
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Share your last session")
                            .font(.headline)
                        Text(latestDayStages.isEmpty ? "No sessions yet" : "\(latestDayStages.count) stages on \(latestDayLabel)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let url = reportURL {
                        ShareLink(item: url) {
                            Label("Report", systemImage: "doc.richtext")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button { generateReport() } label: {
                            Label("Report", systemImage: "doc.richtext")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(latestDayStages.isEmpty)
                    }
                }
            } header: {
                Text("Session Report")
            } footer: {
                Text("A clean PDF of your most recent training day — every stage, set, and string with splits. Share it with your coach.")
            }

            // MARK: CSV export
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Export your training data")
                            .font(.headline)
                        Text("\(allStrings.count) string runs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let url = csvURL {
                        ShareLink(item: url) { Label("CSV", systemImage: "tablecells") }
                            .buttonStyle(.bordered)
                    } else {
                        Button { generateCSV() } label: { Label("CSV", systemImage: "tablecells") }
                            .buttonStyle(.bordered)
                            .disabled(allStrings.isEmpty)
                    }
                }
            } footer: {
                Text("Raw CSV of every string for analysis in a spreadsheet.")
            }
        }
        .navigationTitle("Export & Share")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            generateCSV()
            generateReport()
        }
    }

    // MARK: - Latest day data

    private var latestDayStages: [StageRun] {
        guard let latest = allStages.first?.date else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: latest)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return allStages.filter { $0.date >= start && $0.date < end }
    }

    private var latestDayLabel: String {
        guard let latest = allStages.first?.date else { return "" }
        return latest.formatted(.dateTime.month(.abbreviated).day().year())
    }

    // MARK: - PDF report

    @MainActor
    private func generateReport() {
        let stages = latestDayStages
        guard !stages.isEmpty else { return }

        let report = SessionReportDocument(stages: stages, dateLabel: latestDayLabel)
        let renderer = ImageRenderer(content: report)
        renderer.proposedSize = ProposedViewSize(width: 540, height: nil)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GMJuice_Session_Report.pdf")

        renderer.render { size, context in
            var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
        reportURL = url
    }

    // MARK: - CSV Export

    private func generateCSV() {
        var csvString = "DateTime,Stage,Division,Percent,Penalties,Total Time"
        for i in 1...20 { csvString += ",Shot \(i)" }
        csvString += "\n"

        let sortedStrings = allStrings.sorted { $0.date < $1.date }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for stringRun in sortedStrings {
            let dateTime = dateFormatter.string(from: stringRun.date)
            let stage = stringRun.stageId
            let division = stringRun.divisionId
            let percent = CurrentPeakBenchmarks.percent(
                division: Division(rawValue: division) ?? .RFPO,
                stageCode: stage,
                time: stringRun.adjustedTime
            )
            let percentDouble = NSDecimalNumber(decimal: percent).doubleValue
            let (penalty, _) = stringRun.calculatePenalty()
            let penaltyDouble = NSDecimalNumber(decimal: penalty).doubleValue
            let totalTimeDouble = NSDecimalNumber(decimal: stringRun.adjustedTime).doubleValue

            var row = "\(dateTime),\(stage),\(division),\(String(format: "%.1f", percentDouble)),\(String(format: "%.2f", penaltyDouble)),\(String(format: "%.2f", totalTimeDouble))"
            let shots = stringRun.orderedStringShots
            for i in 0..<20 {
                if i < shots.count {
                    row += ",\(String(format: "%.2f", NSDecimalNumber(decimal: shots[i].split).doubleValue))"
                } else { row += "," }
            }
            csvString += row + "\n"
        }

        let fileName = "gmjuice_export_\(Date().timeIntervalSince1970).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            csvURL = tempURL
        } catch {
            print("⚠️ Failed to write CSV: \(error)")
        }
    }
}

// MARK: - Session report document (rendered to PDF)

private struct SessionReportDocument: View {
    let stages: [StageRun]
    let dateLabel: String

    private func fmt(_ d: Decimal) -> String { String(format: "%.2f", NSDecimalNumber(decimal: d).doubleValue) }

    private func classPct(_ set: StageRun) -> (String, Int) {
        guard let div = Division(rawValue: set.divisionId),
              let peak = CurrentPeakBenchmarks.get(division: div, stageCode: set.stageId)?.peakTime,
              peak > 0, set.bestNTime > 0 else { return ("U", 0) }
        let pct = NSDecimalNumber(decimal: peak / set.bestNTime * 100).intValue
        return (ShooterClass.shooterClass(percentage: Decimal(pct)).rawValue, pct)
    }

    // Group by division + stage
    private var groups: [(key: String, division: String, stageId: String, sets: [StageRun])] {
        let grouped = Dictionary(grouping: stages) { "\($0.divisionId)|\($0.stageId)" }
        return grouped.map { (key, sets) in
            let parts = key.split(separator: "|")
            return (key: key, division: String(parts.first ?? ""), stageId: String(parts.last ?? ""),
                    sets: sets.sorted { $0.date < $1.date })
        }
        .sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GMJUICE").font(.system(size: 22, weight: .heavy)).tracking(2)
                    Text("SESSION REPORT").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(dateLabel).font(.subheadline).foregroundStyle(.secondary)
            }
            Divider()

            Text("\(stages.count) stages · \(stages.reduce(0) { $0 + $1.strings.count }) strings")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(groups, id: \.key) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(group.stageId) · \(stageName(for: group.stageId)) · \(group.division)")
                        .font(.headline)

                    ForEach(Array(group.sets.enumerated()), id: \.offset) { i, set in
                        let (cls, pct) = classPct(set)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Set \(i + 1)").font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("best \(max(set.stringCount - 1, 1)): \(fmt(set.bestNTime))  ·  \(cls) \(pct)%")
                                    .font(.subheadline).monospacedDigit()
                            }
                            let worst = set.strings.max(by: { $0.adjustedTime < $1.adjustedTime })?.id
                            ForEach(Array(set.strings.sorted { $0.date < $1.date }.enumerated()), id: \.offset) { j, run in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("S\(j + 1)").font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 26, alignment: .leading)
                                    Text(fmt(run.adjustedTime)).font(.caption.monospaced().weight(.semibold)).frame(width: 48, alignment: .leading)
                                    Text(run.orderedStringShots.map { fmt($0.split) }.joined(separator: " "))
                                        .font(.caption2.monospaced()).foregroundStyle(.secondary)
                                    Spacer()
                                    if run.id == worst && set.strings.count >= set.stringCount {
                                        Text("drop").font(.caption2).foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Divider()
            Text("Recorded with AMG timer · GMJuice").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 540, alignment: .leading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}

#Preview {
    NavigationStack {
        ExportDataView()
            .modelContainer(for: [StringRun.self, StageRun.self])
    }
}
