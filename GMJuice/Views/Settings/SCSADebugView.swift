//
//  SCSADebugView.swift
//  GMJuice
//
//  Created by Claude on 11/3/25.
//

import SwiftUI
import SwiftData

/// Debug view to test SCSA web scraping
/// Add this to Settings > Developer menu to test the scraper
struct SCSADebugView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var scraper = SCWebScraper.shared

    @State private var testMemberNumber = "L6266"
    @State private var rawHTML: String?
    @State private var parsedData: AllClassificationData?
    @State private var fetchError: String?

    var body: some View {
        Form {
            Section("Test Member Number") {
                TextField("Member Number", text: $testMemberNumber)
                    .autocapitalization(.allCharacters)

                Button {
                    Task {
                        await testFetch()
                    }
                } label: {
                    Label("Fetch & Parse", systemImage: "arrow.down.circle")
                }
                .disabled(scraper.isScraping)

                if scraper.isScraping {
                    HStack {
                        ProgressView()
                        Text("Fetching...")
                    }
                }

                if let error = scraper.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            if let data = parsedData {
                if !data.classifications.isEmpty {
                    Section("Classifications (\(data.classifications.count))") {
                        ForEach(data.classifications.indices, id: \.self) { index in
                            let classification = data.classifications[index]
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(classification.division)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(classification.shooterClass)
                                        .font(.headline)
                                        .foregroundStyle(.blue)
                                }
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Current")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("\(classification.currentPercent, specifier: "%.2f")%")
                                            .font(.subheadline)
                                            .foregroundStyle(.blue)
                                    }
                                    if let highPct = classification.highPercent {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("High")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text("\(highPct, specifier: "%.2f")%")
                                                .font(.subheadline)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    Spacer()
                                    if let date = classification.date {
                                        Text(date, format: .dateTime.month().day().year())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if !data.stageScores.isEmpty {
                    Section("Stage Scores (\(data.stageScores.count))") {
                        ForEach(data.stageScores.indices, id: \.self) { index in
                            let score = data.stageScores[index]
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(score.stage)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(score.division)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(score.matchName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Text("Time: \(score.time, specifier: "%.2f")")
                                        .font(.caption)
                                    Text("Peak: \(score.peakTime, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                    Spacer()
                                    if score.usedForClassification {
                                        Text("USED")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.green)
                                    }
                                    if let date = score.date {
                                        Text(date, format: .dateTime.month().day().year())
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if let html = rawHTML {
                Section {
                    Button("View Raw HTML") {
                        print("=== RAW HTML ===")
                        print(html)
                        print("=== END HTML ===")
                    }
                } footer: {
                    Text("HTML will be printed to Xcode console")
                        .font(.caption2)
                }
            }
        }
        .navigationTitle("SCSA Scraper Debug")
    }

    private func testFetch() async {
        guard !testMemberNumber.isEmpty else { return }

        fetchError = nil
        rawHTML = nil

        // First, let's fetch the raw HTML to see what we're working with
        let url = URL(string: "https://scsa.org/classification/\(testMemberNumber)/all")!
        var request = URLRequest(url: url)
        request.addValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                        forHTTPHeaderField: "User-Agent")
        request.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                        forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                fetchError = "Invalid response"
                return
            }

            print("📡 Status Code: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 200, let html = String(data: data, encoding: .utf8) {
                rawHTML = html
                print("📄 Fetched \(html.count) characters of HTML")

                // Print first 2000 chars to console
                print("=== HTML PREVIEW ===")
                print(String(html.prefix(2000)))
                print("=== END PREVIEW ===")

                // Look for classification/division data
                if let classStart = html.range(of: "Classification", options: .caseInsensitive) {
                    let startIndex = html.index(classStart.lowerBound, offsetBy: -200, limitedBy: html.startIndex) ?? html.startIndex
                    let endIndex = html.index(classStart.upperBound, offsetBy: 2000, limitedBy: html.endIndex) ?? html.endIndex
                    let snippet = String(html[startIndex..<endIndex])
                    print("\n=== CLASSIFICATION SECTION ===")
                    print(snippet)
                    print("=== END CLASSIFICATION ===")
                }

                // Look for division tables
                if let divStart = html.range(of: "RFPO", options: .caseInsensitive) {
                    let startIndex = html.index(divStart.lowerBound, offsetBy: -500, limitedBy: html.startIndex) ?? html.startIndex
                    let endIndex = html.index(divStart.upperBound, offsetBy: 1500, limitedBy: html.endIndex) ?? html.endIndex
                    let snippet = String(html[startIndex..<endIndex])
                    print("\n=== DIVISION DATA ===")
                    print(snippet)
                    print("=== END DIVISION ===")
                }

                // Try to parse it
                try await scraper.syncClassificationData(memberNumber: testMemberNumber, context: context)

                // Check what was stored
                let descriptor = FetchDescriptor<SCMatchScore>(
                    predicate: #Predicate { $0.memberNumber == testMemberNumber }
                )
                let scores = try context.fetch(descriptor)
                print("✅ Stored \(scores.count) match scores in database")

                // Print details of what was stored
                for (index, score) in scores.enumerated() {
                    let percentage = score.peakTime > 0 ? (score.peakTime / score.time) * 100 : 0
                    let percentageValue = NSDecimalNumber(decimal: percentage).doubleValue
                    print("Score \(index + 1): \(score.stageCode) - \(score.stageName) (\(score.divisionCode)) - \(String(format: "%.1f", percentageValue))%")
                }

                // Also check the shooter profile
                let profileDesc = FetchDescriptor<ShooterProfile>()
                if let profile = try context.fetch(profileDesc).first {
                    print("\n📊 Profile Classifications:")
                    for divProfile in profile.divisions {
                        print("  \(divProfile.division.rawValue): \(divProfile.classification.rawValue.uppercased())")
                    }
                }

            } else {
                fetchError = "HTTP \(httpResponse.statusCode)"
            }

        } catch {
            fetchError = error.localizedDescription
            print("❌ Error: \(error)")
        }
    }
}

#Preview {
    let schema = Schema(versionedSchema: Schema004.self)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    return NavigationStack {
        SCSADebugView()
    }
    .modelContainer(container)
}
