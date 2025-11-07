//
//  SCWebScraper.swift
//  GMJuice
//
//  Created by Claude on 11/3/25.
//

import Foundation
import SwiftData
import SwiftSoup

// MARK: - Parsing Rules Models

struct SCSAParsingRules: Codable {
    let version: String
    let description: String
    let rules: Rules

    struct Rules: Codable {
        let memberName: SelectorRule
        let allStageScoresSection: SectionRule
        let divisionHeaders: SelectorRule
        let stageScoreRows: RowParsingRule
        let divisionMapping: [String: String]
        let classificationsSection: ClassificationsSection
    }

    struct SelectorRule: Codable {
        let selector: String
        let method: String?
        let extract: String?
    }

    struct SectionRule: Codable {
        let headerSelector: String
        let tableSelector: String
        let findMethod: String
    }

    struct RowParsingRule: Codable {
        let rowSelector: String
        let divisionHeaderSelector: String
        let classificationIndicator: ClassificationIndicator
        let cells: CellMapping

        struct ClassificationIndicator: Codable {
            let cellIndex: Int
            let method: String  // "contains", "notContains"
            let value: String
        }

        struct CellMapping: Codable {
            let matchName: CellRule
            let date: DateCellRule
            let stageCode: CellRule
            let time: CellRule
            let peakTime: CellRule
        }

        struct CellRule: Codable {
            let index: Int
            let extract: String
            let type: String?
        }

        struct DateCellRule: Codable {
            let index: Int
            let extract: String
            let format: String
        }
    }

    struct ClassificationsSection: Codable {
        let headerSelector: String
        let tableSelector: String
        let findMethod: String
        let rowSelector: String
        let cells: ClassificationCellMapping

        struct ClassificationCellMapping: Codable {
            let division: CellRule
            let `class`: CellRule
            let currentPercent: CellRule
            let highPercent: CellRule
            let date: DateCellRule
        }

        struct CellRule: Codable {
            let index: Int
            let extract: String
            let comment: String?
        }

        struct DateCellRule: Codable {
            let index: Int
            let extract: String
            let format: String
        }
    }

    static func load() -> SCSAParsingRules? {
        guard let url = Bundle.main.url(forResource: "SCSAParsingRules", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ Could not load SCSAParsingRules.json")
            return nil
        }

        do {
            let rules = try JSONDecoder().decode(SCSAParsingRules.self, from: data)
            print("✅ Loaded parsing rules version \(rules.version)")
            return rules
        } catch {
            print("❌ Failed to decode parsing rules: \(error)")
            return nil
        }
    }
}

// MARK: - Data Models

struct AllClassificationData {
    var memberName: String?
    var stageScores: [StageScoresData] = []
    var classifications: [ClassificationData] = []

    struct StageScoresData {
        var date: Date?
        var matchName: String
        var division: String
        var stage: String
        var time: Double
        var peakTime: Double
        var usedForClassification: Bool  // Status
    }

    struct ClassificationData {
        var division: String
        var shooterClass: String
        var currentPercent: Double
        var highPercent: Double?
        var date: Date?
    }
}

// MARK: - Web Scraper

/// Web scraper for publicly available SCSA (Steel Challenge) classification data
///
/// This service scrapes public data from scsa.org without requiring authentication.
/// Only accesses publicly visible information that any user can see in a web browser.
///
/// ## Data Source
/// - URL: https://scsa.org/classification/{memberNumber}/all
/// - Public classification data for all divisions
/// - Stage scores from "All Stage Scores" section
///
/// ## What Can Be Scraped
/// - Member name
/// - All stage scores with dates, match names, times, and classification status
///
/// ## Limitations
/// - Only public data
/// - Fragile - breaks if SCSA changes their HTML
/// - Rate limited - be respectful
@MainActor
class SCWebScraper: ObservableObject {
    static let shared = SCWebScraper()

    @Published var isScraping = false
    @Published var lastError: String?
    @Published var lastSyncDate: Date?

    private let baseURL = "https://scsa.org"
    private let parsingRules: SCSAParsingRules

    private init() {
        self.lastSyncDate = UserDefaults.standard.object(forKey: "scsa_last_sync") as? Date

        // Load parsing rules from JSON
        if let rules = SCSAParsingRules.load() {
            self.parsingRules = rules
        } else {
            // Fallback to default rules if JSON not found
            fatalError("Failed to load parsing rules from SCSAParsingRules.json")
        }
    }

    // MARK: - Auto-Sync Logic

    /// Check if we should sync based on Thursday update schedule
    /// SCSA updates classification data on Wednesdays, so we sync on Thursdays to get fresh data
    func shouldSync() -> Bool {
        guard let lastSync = lastSyncDate else {
            print("🔄 shouldSync: true (never synced before)")
            return true  // Never synced before
        }

        let calendar = Calendar.current
        let now = Date()

        // Find the most recent Thursday (including today if today is Thursday)
        // In Gregorian calendar: 1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, etc.
        let currentWeekday = calendar.component(.weekday, from: now)
        let daysBackToThursday = (currentWeekday + 7 - 5) % 7  // How many days back to Thursday

        guard let mostRecentThursday = calendar.date(byAdding: .day, value: -daysBackToThursday, to: now) else {
            print("🔄 shouldSync: true (date calculation failed)")
            return true  // If date calculation fails, sync to be safe
        }

        // Compare at day level (strip time components)
        let lastSyncDay = calendar.startOfDay(for: lastSync)
        let thursdayDay = calendar.startOfDay(for: mostRecentThursday)

        let shouldSync = lastSyncDay < thursdayDay

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        print("🔄 shouldSync: \(shouldSync)")
        print("   Last sync: \(formatter.string(from: lastSync))")
        print("   Most recent Thursday: \(formatter.string(from: mostRecentThursday))")

        // Sync if we haven't synced on or since the most recent Thursday
        return shouldSync
    }

    // MARK: - Public API

    /// Sync classification data for a member number
    func syncClassificationData(memberNumber: String, context: ModelContext) async throws {
        guard !memberNumber.isEmpty else {
            throw NSError(domain: "SCWebScraper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Member number is required"])
        }

        isScraping = true
        lastError = nil

        defer {
            isScraping = false
        }

        do {
            // Fetch and parse HTML
            let data = try await fetchClassificationData(memberNumber: memberNumber)

            // Store in database
            try await storeClassificationData(data, memberNumber: memberNumber, context: context)

            // Update last sync date
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "scsa_last_sync")

            print("✅ Successfully synced classification data for \(memberNumber)")
        } catch {
            lastError = error.localizedDescription
            print("❌ Sync failed: \(error)")
            throw error
        }
    }

    /// Force refresh classification data
    func refreshClassificationData(memberNumber: String, context: ModelContext) async throws {
        try await syncClassificationData(memberNumber: memberNumber, context: context)
    }

    /// Fetch member information (name and basic data) without saving to database
    func fetchMemberInfo(memberNumber: String) async throws -> (name: String, uspsaNumber: String) {
        let data = try await fetchClassificationData(memberNumber: memberNumber)

        guard let memberName = data.memberName, !memberName.isEmpty else {
            throw NSError(domain: "SCWebScraper", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Could not find member name for this USPSA number"
            ])
        }

        return (name: memberName, uspsaNumber: memberNumber)
    }

    // MARK: - Private Methods

    private func fetchClassificationData(memberNumber: String) async throws -> AllClassificationData {
        let url = URL(string: "\(baseURL)/classification/\(memberNumber)/all")!
        print("🌐 Fetching: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.addValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                        forHTTPHeaderField: "User-Agent")
        request.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                        forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SCWebScraper", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw NSError(domain: "SCWebScraper", code: 404, userInfo: [NSLocalizedDescriptionKey: "Member number not found"])
            }
            throw NSError(domain: "SCWebScraper", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SCWebScraper", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to decode HTML"])
        }

        return try parseClassificationData(html: html)
    }

    // MARK: - Helper Methods

    /// Find a table using the configured method (direct, preferLast, sibling)
    private func findTable(in doc: Element, tableSelector: String, findMethod: String, headerElement: Element? = nil) throws -> Element? {
        switch findMethod {
        case "direct":
            // Use direct selector (e.g., by ID)
            let table = try doc.select(tableSelector).first()
            if table != nil {
                print("✅ Found table using direct selector: \(tableSelector)")
            }
            return table

        case "preferLast":
            // Find all matching tables and prefer the last one
            let matchingTables = try doc.select(tableSelector)
            if matchingTables.count > 1 {
                print("✅ Found \(matchingTables.count) tables with selector \(tableSelector), using the last one")
                return matchingTables.last()
            } else if matchingTables.count == 1 {
                print("✅ Found 1 table with selector \(tableSelector)")
                return matchingTables.first()
            } else {
                print("⚠️ No tables found with selector \(tableSelector)")
                return nil
            }

        case "sibling":
            // Look for next sibling table after header
            guard let header = headerElement else {
                print("⚠️ No header element provided for sibling search")
                return nil
            }
            var currentElement = try header.nextElementSibling()
            var searchDepth = 0
            while currentElement != nil && searchDepth < 10 {
                let tagName = try currentElement?.tagName()
                if tagName == "table" {
                    print("✅ Found table as sibling #\(searchDepth)")
                    return currentElement
                }
                currentElement = try currentElement?.nextElementSibling()
                searchDepth += 1
            }
            print("⚠️ No table found as sibling after \(searchDepth) elements")
            return nil

        default:
            print("⚠️ Unknown findMethod: \(findMethod)")
            return nil
        }
    }

    private func parseClassificationData(html: String) throws -> AllClassificationData {
        var data = AllClassificationData()
        let rules = parsingRules.rules

        // Parse HTML with SwiftSoup
        let doc = try SwiftSoup.parse(html)

        // Extract member name from "Member Information" table
        if let memberNameElement = try doc.select(rules.memberName.selector).first() {
            let memberName = try memberNameElement.text().trimmingCharacters(in: .whitespacesAndNewlines)
            data.memberName = memberName
            print("👤 Found member name: \(memberName)")
        }

        // Check if we got a valid member page by looking for expected headers
        let h2Elements = try doc.select("h2")
        let h2Texts = h2Elements.array().compactMap { try? $0.text() }

        print("📄 Found h2 elements: \(h2Texts)")

        // Try to find at least one of the expected sections
        let hasClassifications = try doc.select(rules.classificationsSection.headerSelector).first() != nil
        let hasStageScores = try doc.select(rules.allStageScoresSection.headerSelector).first() != nil

        // If we have none of the data sections, member not found
        if !hasClassifications && !hasStageScores {
            print("❌ Member not found - page has no classification data sections")
            throw NSError(domain: "SCWebScraper", code: 404, userInfo: [NSLocalizedDescriptionKey: "Member number not found. Please check the member number and try again."])
        }

        print("✅ Valid member page detected")

        // Parse Classifications section
        if let classificationsHeader = try doc.select(rules.classificationsSection.headerSelector).first() {
            print("✅ Found 'Classifications' header")

            // Find the table using the helper method
            if let table = try findTable(
                in: doc,
                tableSelector: rules.classificationsSection.tableSelector,
                findMethod: rules.classificationsSection.findMethod,
                headerElement: classificationsHeader
            ) {
                let rows = try table.select(rules.classificationsSection.rowSelector)
                print("DEBUG: Found \(rows.count) classification rows")

                for row in rows {
                    let cells = try row.select("td")
                    // Classifications table has 6 columns: Division Name, Division Code, Class, Current%, High%, Date
                    guard cells.count >= 6 else {
                        print("DEBUG: Skipping row with only \(cells.count) cells")
                        continue
                    }

                    // Debug: Print all cell values
                    let cellTexts = try cells.map { try $0.text() }
                    print("DEBUG: Row cells: \(cellTexts)")

                    // Extract division code (index 1) - this is the second column (CO, PCCO, PROD, RFRO, etc.)
                    let divisionIndex = rules.classificationsSection.cells.division.index
                    guard divisionIndex < cells.count else { continue }
                    let divisionCode = try cells[divisionIndex].text().trimmingCharacters(in: .whitespacesAndNewlines)

                    // Extract class (index 2)
                    let classIndex = rules.classificationsSection.cells.class.index
                    guard classIndex < cells.count else { continue }
                    let shooterClass = try cells[classIndex].text().trimmingCharacters(in: .whitespacesAndNewlines)

                    // Extract current percent (index 3)
                    let currentPercentIndex = rules.classificationsSection.cells.currentPercent.index
                    guard currentPercentIndex < cells.count else { continue }
                    let currentPercentStr = try cells[currentPercentIndex].text().trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanCurrentPercentStr = currentPercentStr.replacingOccurrences(of: "%", with: "")
                    guard let currentPercent = Double(cleanCurrentPercentStr) else { continue }

                    // Extract high percent (index 4)
                    let highPercentIndex = rules.classificationsSection.cells.highPercent.index
                    var highPercent: Double?
                    if highPercentIndex < cells.count {
                        let highPercentStr = try cells[highPercentIndex].text().trimmingCharacters(in: .whitespacesAndNewlines)
                        let cleanHighPercentStr = highPercentStr.replacingOccurrences(of: "%", with: "")
                        highPercent = Double(cleanHighPercentStr)
                    }

                    // Extract date (index 5)
                    let dateIndex = rules.classificationsSection.cells.date.index
                    guard dateIndex < cells.count else { continue }
                    let dateStr = try cells[dateIndex].text().trimmingCharacters(in: .whitespacesAndNewlines)

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = rules.classificationsSection.cells.date.format
                    let date = dateFormatter.date(from: dateStr)

                    let classification = AllClassificationData.ClassificationData(
                        division: divisionCode,
                        shooterClass: shooterClass,
                        currentPercent: currentPercent,
                        highPercent: highPercent,
                        date: date
                    )

                    data.classifications.append(classification)
                    print("DEBUG: Parsed classification - \(divisionCode): \(shooterClass) - Current: \(currentPercent)% - High: \(highPercent ?? 0)%")
                }
            } else {
                print("⚠️ Could not find classifications table")
            }
        } else {
            print("⚠️ Could not find 'Classifications' header")
        }

        // Find "All Stage Scores" section using rules
        guard let allStageScoresHeader = try doc.select(rules.allStageScoresSection.headerSelector).first() else {
            print("❌ Could not find header with selector: \(rules.allStageScoresSection.headerSelector)")
            print("📄 Available h2 elements:")
            let h2s = try doc.select("h2")
            for h2 in h2s {
                print("  - \(try h2.text())")
            }
            throw NSError(domain: "SCWebScraper", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not find 'All Stage Scores' section"])
        }

        print("✅ Found 'All Stage Scores' header")

        // Find the table using the helper method
        guard let table = try findTable(
            in: doc,
            tableSelector: rules.allStageScoresSection.tableSelector,
            findMethod: rules.allStageScoresSection.findMethod,
            headerElement: allStageScoresHeader
        ) else {
            print("❌ Could not find table using selector: \(rules.allStageScoresSection.tableSelector)")
            print("📄 Available tables in document:")
            let allTables = try doc.select("table")
            print("  Total tables: \(allTables.count)")
            for (index, tbl) in allTables.enumerated() {
                let id = try? tbl.attr("id")
                print("  Table \(index): id=\(id ?? "none")")
            }
            throw NSError(domain: "SCWebScraper", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not find stage scores table"])
        }

        print("✅ Found stage scores table")

        // Find all division headers using rules
        let divisionHeaders = try table.select(rules.divisionHeaders.selector)
        print("DEBUG: Found \(divisionHeaders.count) division sections")

        var currentDivision = "Unknown"

        // Iterate through all rows in the table
        let allRows = try table.select(rules.stageScoreRows.rowSelector)

        for row in allRows {
            // Check if this row contains a division header
            if let divHeader = try? row.select(rules.stageScoreRows.divisionHeaderSelector).first() {
                let divisionName = try divHeader.text().trimmingCharacters(in: .whitespacesAndNewlines)
                currentDivision = divisionName
                let divisionCode = rules.divisionMapping[divisionName] ?? divisionName
                print("DEBUG: Found division: '\(divisionName)' → mapped to code: '\(divisionCode)'")
                continue
            }

            // Parse data row
            let cells = try row.select("td")
            // Stage scores table has 6 columns: Event, Date, Stage, Time, Peak, Status
            guard cells.count >= 6 else { continue }

            // Check if this score was used for classification using rules
            let indicatorIndex = rules.stageScoreRows.classificationIndicator.cellIndex
            guard indicatorIndex < cells.count else { continue }

            let indicatorCell = cells[indicatorIndex]
            let indicatorHTML = try indicatorCell.html()

            let usedForClassification: Bool
            if rules.stageScoreRows.classificationIndicator.method == "notContains" {
                usedForClassification = !indicatorHTML.contains(rules.stageScoreRows.classificationIndicator.value)
            } else {
                usedForClassification = indicatorHTML.contains(rules.stageScoreRows.classificationIndicator.value)
            }

            // Extract match name using rules
            let matchNameIndex = rules.stageScoreRows.cells.matchName.index
            guard matchNameIndex < cells.count else { continue }
            let matchName = try cells[matchNameIndex].text().trimmingCharacters(in: .whitespacesAndNewlines)

            // Extract date using rules
            let dateIndex = rules.stageScoreRows.cells.date.index
            guard dateIndex < cells.count else { continue }
            let dateStr = try cells[dateIndex].text().trimmingCharacters(in: .whitespacesAndNewlines)

            // Extract stage code using rules
            let stageCodeIndex = rules.stageScoreRows.cells.stageCode.index
            guard stageCodeIndex < cells.count else { continue }
            let stageCode = try cells[stageCodeIndex].text().trimmingCharacters(in: .whitespacesAndNewlines)

            guard !stageCode.isEmpty else { continue }

            // Get time and peak time using rules
            let timeIndex = rules.stageScoreRows.cells.time.index
            let peakIndex = rules.stageScoreRows.cells.peakTime.index

            guard timeIndex < cells.count && peakIndex < cells.count else { continue }

            let timeStr = try cells[timeIndex].text().trimmingCharacters(in: .whitespacesAndNewlines)
            let peakStr = try cells[peakIndex].text().trimmingCharacters(in: .whitespacesAndNewlines)

            if let time = Double(timeStr), let peak = Double(peakStr) {
                // Parse date using format from rules
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = rules.stageScoreRows.cells.date.format
                let date = dateFormatter.date(from: dateStr)

                // Map division name to code using rules
                let divisionCode = rules.divisionMapping[currentDivision] ?? currentDivision

                let stageScore = AllClassificationData.StageScoresData(
                    date: date,
                    matchName: matchName,
                    division: divisionCode,
                    stage: stageCode,
                    time: time,
                    peakTime: peak,
                    usedForClassification: usedForClassification
                )

                data.stageScores.append(stageScore)

                #if DEBUG
                if currentDivision != divisionCode {
                    print("DEBUG: Parsed - \(stageCode) (\(currentDivision) → \(divisionCode)) - \(matchName) - \(time)s vs \(peak)s - used: \(usedForClassification)")
                } else {
                    print("DEBUG: Parsed - \(stageCode) (\(divisionCode)) - \(matchName) - \(time)s vs \(peak)s - used: \(usedForClassification)")
                }
                #endif
            }
        }

        print("DEBUG: Parsed \(data.stageScores.count) total stage scores")

        return data
    }

    private func storeClassificationData(_ data: AllClassificationData, memberNumber: String, context: ModelContext) async throws {
        // Fetch existing match scores for this member
        let descriptor = FetchDescriptor<SCMatchScore>(
            predicate: #Predicate { $0.memberNumber == memberNumber }
        )
        let existing = try context.fetch(descriptor)
        let existingCount = existing.count
        let newCount = data.stageScores.count

        print("📊 Data comparison: existing=\(existingCount), new=\(newCount)")

        // Safety check: Don't overwrite if we're getting fewer records than we already have
        // This prevents data loss if the website is having issues or partially loaded
        if existingCount > 0 && newCount < existingCount {
            let message = "Sync aborted: Found \(newCount) stage scores but you already have \(existingCount) saved. This could indicate the website didn't fully load. Your existing data has been preserved."
            print("⚠️ \(message)")
            throw NSError(domain: "SCWebScraper", code: 100, userInfo: [
                NSLocalizedDescriptionKey: message,
                NSLocalizedRecoverySuggestionErrorKey: "Try syncing again in a few moments, or check scsa.org to verify your data is available."
            ])
        }

        // If we have the same or more records, proceed with update
        print("✅ Safe to update: new data has \(newCount) records (existing: \(existingCount))")

        // Delete ALL existing match scores to ensure clean data (removes old division codes)
        print("🗑️ Deleting \(existingCount) existing match scores...")
        for score in existing {
            context.delete(score)
        }

        // Force save deletions before inserting new data
        try context.save()
        print("✅ Deleted all existing data")

        // Store new stage scores with corrected division codes
        var classificationScoresByDivision: [String: Int] = [:]
        print("📝 Inserting \(data.stageScores.count) new match scores with corrected division codes...")

        for stageScore in data.stageScores {
            let score = SCMatchScore(
                matchName: stageScore.matchName,
                scoreDate: stageScore.date ?? Date(),
                stageCode: stageScore.stage,
                stageName: stageName(for: stageScore.stage),
                divisionCode: stageScore.division,
                time: Decimal(stageScore.time),
                peakTime: Decimal(stageScore.peakTime),
                usedForClassification: stageScore.usedForClassification,
                memberNumber: memberNumber
            )
            context.insert(score)

            if stageScore.usedForClassification {
                classificationScoresByDivision[stageScore.division, default: 0] += 1
            }
        }
        print("✅ Inserted \(data.stageScores.count) match scores")

        // Update shooter profile with classification info
        let profileDescriptor = FetchDescriptor<ShooterProfile>()
        let profiles = try context.fetch(profileDescriptor)

        let profile: ShooterProfile
        if let existingProfile = profiles.first {
            profile = existingProfile
        } else {
            profile = ShooterProfile(uspsaNumber: memberNumber)
            context.insert(profile)
        }

        // Update division profiles using Classifications data from the page
        for classification in data.classifications {
            print("📊 Processing classification: \(classification.division) - \(classification.shooterClass) - \(classification.currentPercent)%")

            guard let division = Division(rawValue: classification.division) else {
                print("⚠️ Could not find Division enum for code: '\(classification.division)'")
                print("   Available division codes in enum: \(Division.allCases.map { $0.rawValue }.joined(separator: ", "))")
                print("   Skipping this classification")
                continue
            }

            let divProfile: DivisionProfile
            if let existing = profile.divisions.first(where: { $0.division == division }) {
                divProfile = existing
                print("✅ Found existing division profile for \(classification.division)")
            } else {
                divProfile = DivisionProfile(division: division)
                profile.divisions.append(divProfile)
                print("✅ Created new division profile for \(classification.division)")
            }

            // Set current percentage from Classifications section
            divProfile.currentPercentage = Decimal(classification.currentPercent)
            print("✅ Set currentPercentage to \(classification.currentPercent)")

            // Determine classification from percentage
            let shooterClass = ShooterClass.shooterClass(percentage: Decimal(classification.currentPercent))
            divProfile.classification = shooterClass

            // Set classification date
            divProfile.classificationDate = classification.date

            // Set high percentage from SCSA data
            if let highPct = classification.highPercent {
                divProfile.highPercentage = Decimal(highPct)
            }

            print("📊 Updated \(classification.division): \(shooterClass.rawValue) - Current: \(String(format: "%.2f", classification.currentPercent))% - High: \(classification.highPercent.map { String(format: "%.2f", $0) } ?? "N/A")%")
        }

        try context.save()

        // Summary of what was stored
        let divisionBreakdown = Dictionary(grouping: data.stageScores) { $0.division }
            .mapValues { $0.count }
            .sorted { $0.key < $1.key }
        print("✅ Stored \(data.stageScores.count) stage scores across divisions:")
        for (division, count) in divisionBreakdown {
            let classCount = classificationScoresByDivision[division] ?? 0
            print("   - \(division): \(count) total scores (\(classCount) used for classification)")
        }
    }
}
