//
//  WidgetDataProvider.swift
//  GMJuiceWidget
//
//  Created by Claude on 11/6/25.
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct PerformanceEntry: TimelineEntry {
    let date: Date
    let divisionStats: DivisionStats?
    let showPercentage: Bool  // Toggle between classification and percentage
    let stageDisplayMode: StageDisplayMode  // What to display in stage boxes

    struct DivisionStats {
        let division: Division
        let classification: ShooterClass
        let totalTime: Decimal
        let percentage: Decimal
        let daysSinceLastMatch: Int?
        let totalStages: Int  // Number of stages used for classification
        let stageScores: [StageScore]  // Individual stage data (current classification scores)
        let bestStageCode: String?  // Code of best performing stage
        let worstStageCode: String?  // Code of worst performing stage
        let lastMatchName: String?  // Name of most recent match
        let bestRecentStages: [StageScore]  // Best 4 stages from last match
    }

    struct StageScore {
        let stageCode: String
        let time: Decimal
        let percentage: Decimal
    }
}

// Copy of StageDisplayMode for widget (can't import from main app)
enum StageDisplayMode: String, Codable {
    case classification = "Class"
    case percentage = "Percent"
    case time = "Time"
    case all = "All"
}

// MARK: - Widget Settings Data

struct WidgetSettingsData {
    let selectedDivisions: [String]
    let rotationInterval: Int
    let stageDisplayMode: StageDisplayMode
}

// MARK: - Timeline Provider

struct PerformanceProvider: TimelineProvider {
    typealias Entry = PerformanceEntry

    func placeholder(in context: Context) -> PerformanceEntry {
        PerformanceEntry(
            date: Date(),
            divisionStats: PerformanceEntry.DivisionStats(
                division: .RFPO,
                classification: .GM,
                totalTime: 71.25,
                percentage: 97,
                daysSinceLastMatch: 7,
                totalStages: 8,
                stageScores: [
                    PerformanceEntry.StageScore(stageCode: "SC-101", time: 8.95, percentage: 98),
                    PerformanceEntry.StageScore(stageCode: "SC-102", time: 7.65, percentage: 98),
                    PerformanceEntry.StageScore(stageCode: "SC-103", time: 7.14, percentage: 98),
                    PerformanceEntry.StageScore(stageCode: "SC-104", time: 11.73, percentage: 98),
                    PerformanceEntry.StageScore(stageCode: "SC-105", time: 8.68, percentage: 98),
                    PerformanceEntry.StageScore(stageCode: "SC-106", time: 9.69, percentage: 98),
                    PerformanceEntry.StageScore(stageCode: "SC-107", time: 10.20, percentage: 98),
                    PerformanceEntry.StageScore(stageCode: "SC-108", time: 7.65, percentage: 98)
                ],
                bestStageCode: "SC-103",
                worstStageCode: "SC-104",
                lastMatchName: "Steel Challenge World Championship",
                bestRecentStages: [
                    PerformanceEntry.StageScore(stageCode: "SC-103", time: 7.14, percentage: 98.5),
                    PerformanceEntry.StageScore(stageCode: "SC-102", time: 7.65, percentage: 98.2),
                    PerformanceEntry.StageScore(stageCode: "SC-108", time: 7.65, percentage: 98.0),
                    PerformanceEntry.StageScore(stageCode: "SC-105", time: 8.68, percentage: 97.8)
                ]
            ),
            showPercentage: false,
            stageDisplayMode: .classification
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PerformanceEntry) -> Void) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PerformanceEntry>) -> Void) {
        Task {
            let currentDate = Date()

            // Read widget settings
            let settings = getWidgetSettings()

            // Fetch the performance data
            let baseStats = await fetchPerformanceData(settings: settings)

            // Create alternating entries based on stage display mode
            var entries: [PerformanceEntry] = []

            if settings.stageDisplayMode == .all {
                // For "All" mode, rotate through classification, percentage, and time
                let modes: [(mode: StageDisplayMode, showPercentage: Bool)] = [
                    (.classification, false),
                    (.percentage, false),
                    (.time, false)
                ]

                for (index, modeConfig) in modes.enumerated() {
                    if let entryDate = Calendar.current.date(byAdding: .second, value: index * 4, to: currentDate) {
                        let entry = PerformanceEntry(
                            date: entryDate,
                            divisionStats: baseStats.divisionStats,
                            showPercentage: modeConfig.showPercentage,
                            stageDisplayMode: modeConfig.mode
                        )
                        entries.append(entry)
                    }
                }
            } else {
                // For specific modes (classification, percentage, time), show static - no rotation
                let entry = PerformanceEntry(
                    date: currentDate,
                    divisionStats: baseStats.divisionStats,
                    showPercentage: false,
                    stageDisplayMode: settings.stageDisplayMode
                )
                entries.append(entry)
            }

            // Reload timing: 12 seconds for "All" mode (3 modes × 4 seconds), 60 seconds for static modes
            let reloadSeconds = settings.stageDisplayMode == .all ? 12 : 60
            let nextUpdate = Calendar.current.date(byAdding: .second, value: reloadSeconds, to: currentDate) ?? currentDate
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))

            completion(timeline)
        }
    }

    // MARK: - Data Fetching

    private func fetchPerformanceData(settings: WidgetSettingsData) async -> PerformanceEntry {
        do {
            // Get the shared model container
            guard let container = try? await getSharedModelContainer() else {
                return PerformanceEntry(date: Date(), divisionStats: nil, showPercentage: false, stageDisplayMode: .classification)
            }

            let context = ModelContext(container)

            // Fetch shooter profile
            let profileDescriptor = FetchDescriptor<ShooterProfile>()
            guard let profile = try context.fetch(profileDescriptor).first else {
                return PerformanceEntry(date: Date(), divisionStats: nil, showPercentage: false, stageDisplayMode: .classification)
            }

            // Get divisions with classifications
            var divisionsWithData = profile.divisions.filter { $0.classification != .U }

            // Filter by user-selected divisions
            if !settings.selectedDivisions.isEmpty {
                divisionsWithData = divisionsWithData.filter { div in
                    settings.selectedDivisions.contains(div.division.rawValue)
                }
            }

            guard !divisionsWithData.isEmpty else {
                return PerformanceEntry(date: Date(), divisionStats: nil, showPercentage: false, stageDisplayMode: .classification)
            }

            // Smart division selection: prioritize by recent activity
            let selectedDivision = selectDivisionToDisplay(
                divisions: divisionsWithData,
                context: context,
                settings: settings
            )

            // Store division code for predicate (can't access captured variables in #Predicate)
            let divisionCode = selectedDivision.division.rawValue

            // Fetch classification scores for this division
            let scoresDescriptor = FetchDescriptor<MatchScore>(
                predicate: #Predicate<MatchScore> { score in
                    score.divisionCode == divisionCode &&
                    score.usedForClassification == true
                },
                sortBy: [SortDescriptor(\MatchScore.scoreDate, order: .reverse)]
            )

            let classificationScores: [MatchScore] = try context.fetch(scoresDescriptor)

            // Calculate metrics
            let totalTime = classificationScores.reduce(Decimal(0)) { $0 + $1.time }
            let totalPeakTime = classificationScores.reduce(Decimal(0)) { $0 + $1.peakTime }

            let percentage: Decimal
            if totalTime > 0 && totalPeakTime > 0 {
                let rawPercent = (totalPeakTime / totalTime) * 100
                var roundedPercent = Decimal()
                var rawPercentValue = rawPercent
                NSDecimalRound(&roundedPercent, &rawPercentValue, 2, .plain)  // Keep 2 decimal places
                percentage = roundedPercent
            } else {
                percentage = 0
            }

            // Calculate days since last match (reuse divisionCode variable)
            let allScoresDescriptor = FetchDescriptor<MatchScore>(
                predicate: #Predicate<MatchScore> { score in
                    score.divisionCode == divisionCode
                },
                sortBy: [SortDescriptor(\MatchScore.scoreDate, order: .reverse)]
            )

            let allScores: [MatchScore] = try context.fetch(allScoresDescriptor)
            let daysSinceLastMatch: Int?
            if let lastMatchDate = allScores.first?.scoreDate {
                let days = Calendar.current.dateComponents([.day], from: lastMatchDate, to: Date()).day
                daysSinceLastMatch = days
            } else {
                daysSinceLastMatch = nil
            }

            // Build individual stage scores
            let stageScores = classificationScores.map { score in
                let stagePercentage: Decimal
                if score.time > 0 && score.peakTime > 0 {
                    let rawPercent = (score.peakTime / score.time) * 100
                    var roundedPercent = Decimal()
                    var rawPercentValue = rawPercent
                    NSDecimalRound(&roundedPercent, &rawPercentValue, 2, .plain)  // Keep 2 decimal places
                    stagePercentage = roundedPercent
                } else {
                    stagePercentage = 0
                }

                return PerformanceEntry.StageScore(
                    stageCode: score.stageCode,
                    time: score.time,
                    percentage: stagePercentage
                )
            }.sorted { $0.stageCode < $1.stageCode }  // Sort by stage code

            // Find best and worst stages
            let bestStage = stageScores.max(by: { $0.percentage < $1.percentage })
            let worstStage = stageScores.min(by: { $0.percentage < $1.percentage })

            // Get last match name and best stages from recent match
            let lastMatchName = allScores.first?.matchName

            // Get scores from the most recent match (same date as first score)
            let recentMatchScores: [PerformanceEntry.StageScore]
            if let lastDate = allScores.first?.scoreDate {
                let calendar = Calendar.current
                let lastMatchDay = calendar.startOfDay(for: lastDate)

                let matchDayScores = allScores.filter { score in
                    calendar.startOfDay(for: score.scoreDate) == lastMatchDay
                }

                // Convert to StageScore and sort by percentage (best first)
                let sortedScores = matchDayScores.map { score in
                    let stagePercentage: Decimal
                    if score.time > 0 && score.peakTime > 0 {
                        let rawPercent = (score.peakTime / score.time) * 100
                        var roundedPercent = Decimal()
                        var rawPercentValue = rawPercent
                        NSDecimalRound(&roundedPercent, &rawPercentValue, 2, .plain)
                        stagePercentage = roundedPercent
                    } else {
                        stagePercentage = 0
                    }

                    return PerformanceEntry.StageScore(
                        stageCode: score.stageCode,
                        time: score.time,
                        percentage: stagePercentage
                    )
                }
                .sorted { $0.percentage > $1.percentage }  // Sort by percentage descending

                recentMatchScores = Array(sortedScores.prefix(4))  // Take top 4 (keep sorted by percentage)
            } else {
                recentMatchScores = []
            }

            let stats = PerformanceEntry.DivisionStats(
                division: selectedDivision.division,
                classification: selectedDivision.classification,
                totalTime: totalTime,
                percentage: percentage,
                daysSinceLastMatch: daysSinceLastMatch,
                totalStages: classificationScores.count,
                stageScores: stageScores,
                bestStageCode: bestStage?.stageCode,
                worstStageCode: worstStage?.stageCode,
                lastMatchName: lastMatchName,
                bestRecentStages: Array(recentMatchScores)
            )

            return PerformanceEntry(date: Date(), divisionStats: stats, showPercentage: false, stageDisplayMode: settings.stageDisplayMode)

        } catch {
            print("Widget error fetching data: \(error)")
            return PerformanceEntry(date: Date(), divisionStats: nil, showPercentage: false, stageDisplayMode: .classification)
        }
    }

    // MARK: - Widget Settings

    private func getWidgetSettings() -> WidgetSettingsData {
        let appGroupID = "group.com.andretaube.gmjuice"
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return WidgetSettingsData(
                selectedDivisions: [],
                rotationInterval: 15,
                stageDisplayMode: .classification
            )
        }

        let selectedDivisions = defaults.stringArray(forKey: "widget_selected_divisions") ?? []
        let rotationInterval = defaults.integer(forKey: "widget_rotation_interval")
        let modeRaw = defaults.string(forKey: "widget_stage_display_mode") ?? "Class"
        let stageDisplayMode = StageDisplayMode(rawValue: modeRaw) ?? .classification

        return WidgetSettingsData(
            selectedDivisions: selectedDivisions,
            rotationInterval: rotationInterval > 0 ? rotationInterval : 15,
            stageDisplayMode: stageDisplayMode
        )
    }

    // MARK: - Smart Division Selection

    private func selectDivisionToDisplay(
        divisions: [DivisionProfile],
        context: ModelContext,
        settings: WidgetSettingsData
    ) -> DivisionProfile {
        // Find the division with the most recent match
        var divisionScores: [(division: DivisionProfile, lastMatchDate: Date?)] = []

        for division in divisions {
            let divisionCode = division.division.rawValue
            let scoresDescriptor = FetchDescriptor<MatchScore>(
                predicate: #Predicate<MatchScore> { score in
                    score.divisionCode == divisionCode
                },
                sortBy: [SortDescriptor(\MatchScore.scoreDate, order: .reverse)]
            )

            if let scores = try? context.fetch(scoresDescriptor),
               let lastScore = scores.first {
                divisionScores.append((division: division, lastMatchDate: lastScore.scoreDate))
            } else {
                divisionScores.append((division: division, lastMatchDate: nil))
            }
        }

        // Sort by most recent match first
        divisionScores.sort { a, b in
            if let dateA = a.lastMatchDate, let dateB = b.lastMatchDate {
                return dateA > dateB
            }
            if a.lastMatchDate != nil { return true }
            if b.lastMatchDate != nil { return false }
            return false
        }

        // If multiple divisions, rotate between top 3 most active
        let activeDivisions = divisionScores.prefix(3).map { $0.division }

        if activeDivisions.count > 1 && settings.rotationInterval > 0 {
            // Rotate based on user's chosen interval
            let minute = Calendar.current.component(.minute, from: Date())
            let rotationIndex = (minute / settings.rotationInterval) % activeDivisions.count
            return activeDivisions[rotationIndex]
        } else {
            return activeDivisions.first ?? divisions.first!
        }
    }

    private func getSharedModelContainer() async throws -> ModelContainer {
        // Use the app group container for shared data access
        let schema = Schema(versionedSchema: Schema004.self)

        let appGroupID = "group.com.andretaube.gmjuice"  // Make sure this matches your app group
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw NSError(domain: "WidgetError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get app group URL"])
        }

        let modelURL = groupURL.appendingPathComponent("default.store")
        let config = ModelConfiguration(url: modelURL)

        return try ModelContainer(for: schema, configurations: [config])
    }
}
