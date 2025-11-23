import SwiftUI
import SwiftData

struct ExportDataView: View {
    @Query(sort: [SortDescriptor<StringRun>(\.date, order: .reverse)])
    private var allStrings: [StringRun]

    @State private var csvURL: URL?

    var body: some View {
        List {
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
                        ShareLink(item: url) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            generateCSV()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(allStrings.isEmpty)
                    }
                }
            } header: {
                Text("Export Data")
            } footer: {
                Text("Export all training data as CSV file for analysis in Excel, Google Sheets, or other tools.")
            }

            Section("CSV Format") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(csvFields, id: \.name) { field in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(field.name)
                                .font(.subheadline.bold())
                            Text(field.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let example = field.example {
                                Text("Example: \(example)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .monospaced()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Generate CSV when view appears
            generateCSV()
        }
    }

    // MARK: - CSV Export

    private func generateCSV() {
        print("📊 Starting CSV export with \(allStrings.count) string runs")

        var csvString = "DateTime,Stage,Division,Percent,Penalties,Total Time"

        // Add shot columns (1-20)
        for i in 1...20 {
            csvString += ",Shot \(i)"
        }
        csvString += "\n"

        // Sort by date (oldest first for export)
        let sortedStrings = allStrings.sorted { $0.date < $1.date }
        print("📊 Sorted \(sortedStrings.count) runs for export")

        for stringRun in sortedStrings {
            // DateTime
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateTime = dateFormatter.string(from: stringRun.date)

            // Stage and Division
            let stage = stringRun.stageId
            let division = stringRun.divisionId

            // Calculate percentage
            let percent = PeakBenchmarks.percent(
                division: Division(rawValue: division) ?? .RFPO,
                stageCode: stage,
                time: stringRun.adjustedTime
            )
            let percentDouble = NSDecimalNumber(decimal: percent).doubleValue

            // Penalties and Total Time
            let (penalty, _) = stringRun.calculatePenalty()
            let penaltyDouble = NSDecimalNumber(decimal: penalty).doubleValue
            let totalTime = stringRun.adjustedTime
            let totalTimeDouble = NSDecimalNumber(decimal: totalTime).doubleValue

            // Build row
            var row = "\(dateTime),\(stage),\(division),\(String(format: "%.1f", percentDouble)),\(String(format: "%.2f", penaltyDouble)),\(String(format: "%.2f", totalTimeDouble))"

            // Add shot times (splits)
            let shots = stringRun.orderedStringShots
            for i in 0..<20 {
                if i < shots.count {
                    let shotTime = shots[i].split
                    let shotTimeDouble = NSDecimalNumber(decimal: shotTime).doubleValue
                    row += ",\(String(format: "%.2f", shotTimeDouble))"
                } else {
                    row += ","  // Empty column
                }
            }

            csvString += row + "\n"
        }

        // Write to temporary file
        let fileName = "gmjuice_export_\(Date().timeIntervalSince1970).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        print("📊 Writing CSV to: \(tempURL.path)")

        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            print("✅ CSV written successfully, size: \(csvString.count) characters")
            csvURL = tempURL
            print("📊 CSV ready for sharing at: \(tempURL)")
        } catch {
            print("⚠️ Failed to write CSV: \(error)")
        }
    }

    // MARK: - Field Descriptions

    private var csvFields: [CSVField] {
        [
            CSVField(
                name: "DateTime",
                description: "Date and time when the string run was recorded",
                example: "2025-01-15 14:30:45"
            ),
            CSVField(
                name: "Stage",
                description: "Stage code (SC-101 through SC-108)",
                example: "SC-101"
            ),
            CSVField(
                name: "Division",
                description: "Division competed in",
                example: "RFPO"
            ),
            CSVField(
                name: "Percent",
                description: "Performance percentage based on GM benchmark",
                example: "87.5"
            ),
            CSVField(
                name: "Penalties",
                description: "Total penalty seconds added (3s per miss, 30s for stop plate)",
                example: "3.00"
            ),
            CSVField(
                name: "Total Time",
                description: "Final time including penalties",
                example: "2.29"
            ),
            CSVField(
                name: "Shot 1 - Shot 20",
                description: "Individual shot split times in seconds. Unused columns are empty for strings with fewer than 20 shots.",
                example: "0.45"
            )
        ]
    }
}

// MARK: - CSV Field Model

struct CSVField {
    let name: String
    let description: String
    let example: String?
}

#Preview {
    NavigationStack {
        ExportDataView()
            .modelContainer(for: [StringRun.self])
    }
}
