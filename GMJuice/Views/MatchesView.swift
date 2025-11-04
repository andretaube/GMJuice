//
//  MatchesView.swift
//  GMJuice
//
//  Created by Andre Taube on 11/3/25.
//

import SwiftUI
import SwiftData

struct MatchesView: View {
    @Query(sort: \SCMatchScore.scoreDate, order: .reverse) private var allScores: [SCMatchScore]
    @Query private var profiles: [ShooterProfile]
    @State private var selectedTab = 0

    private var hasUSPSANumber: Bool {
        guard let profile = profiles.first else { return false }
        return !profile.uspsaNumber.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !hasUSPSANumber {
                    // Show info message when no USPSA number provided
                    NoUSPSANumberView()
                } else {
                    Picker("View", selection: $selectedTab) {
                        Text("Classification").tag(0)
                        Text("Match Scores").tag(1)
                        Text("Classification Data").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if selectedTab == 0 {
                        ClassificationTabView(allScores: allScores, profiles: profiles)
                    } else if selectedTab == 1 {
                        MyScoresTabView(allScores: allScores)
                    } else {
                        PercentageTableTabView(profiles: profiles)
                    }
                }
            }
            .navigationTitle("Classification")
        }
    }
}

// MARK: - No USPSA Number Info View
private struct NoUSPSANumberView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)

                // Icon
                Image(systemName: "trophy.circle")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow)

                // Header
                VStack(spacing: 12) {
                    Text("Connect Your Profile")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Add your USPSA member number to unlock classification tracking and match score analysis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Benefits
                VStack(alignment: .leading, spacing: 16) {
                    InfoBenefitRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Track Classifications",
                        description: "Monitor your SCSA standings across all divisions"
                    )

                    InfoBenefitRow(
                        icon: "target",
                        title: "Stage Analysis",
                        description: "View detailed performance breakdowns for each stage"
                    )

                    InfoBenefitRow(
                        icon: "arrow.clockwise",
                        title: "Auto Sync",
                        description: "Automatically sync official classifier scores"
                    )
                }
                .padding(.horizontal, 32)

                // Button
                NavigationLink(destination: ShooterProfileView()) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                        Text("Go to Profile Settings")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }
}

private struct InfoBenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Classification Tab
private struct ClassificationTabView: View {
    let allScores: [SCMatchScore]
    let profiles: [ShooterProfile]

    private var classificationScoresByDivision: [(division: String, totalTime: Decimal, totalPeakTime: Decimal, classification: String, percentage: Decimal, highPercentage: Decimal?, classificationDate: Date?, stages: [(stageCode: String, stageName: String, scores: [SCMatchScore])])] {
        // ONLY show scores where usedForClassification = true (one score per stage per division)
        let usedScores = allScores.filter { $0.usedForClassification }
        let byDivision = Dictionary(grouping: usedScores) { $0.divisionCode }

        guard let profile = profiles.first else {
            return byDivision.map { division, scores in
                // Total time = sum of ONLY scores used for classification
                let totalTime = scores.reduce(Decimal(0)) { $0 + $1.time }
                let totalPeakTime = scores.reduce(Decimal(0)) { $0 + $1.peakTime }
                let byStage = Dictionary(grouping: scores) { $0.stageCode }
                let stages = byStage.map { (stageCode: $0.key, stageName: $0.value.first?.stageName ?? $0.key, scores: $0.value.sorted { $0.scoreDate > $1.scoreDate }) }
                    .sorted { $0.stageCode < $1.stageCode }
                return (division: division, totalTime: totalTime, totalPeakTime: totalPeakTime, classification: "U", percentage: 0, highPercentage: nil, classificationDate: nil, stages: stages)
            }
            .sorted { $0.division < $1.division }
        }

        return byDivision.map { division, scores in
            // Total time = sum of ONLY scores used for classification
            let totalTime = scores.reduce(Decimal(0)) { $0 + $1.time }
            let totalPeakTime = scores.reduce(Decimal(0)) { $0 + $1.peakTime }
            let byStage = Dictionary(grouping: scores) { $0.stageCode }
            let stages = byStage.map { (stageCode: $0.key, stageName: $0.value.first?.stageName ?? $0.key, scores: $0.value.sorted { $0.scoreDate > $1.scoreDate }) }
                .sorted { $0.stageCode < $1.stageCode }

            // Get classification info from profile
            let divProfile = profile.divisions.first { $0.division.rawValue == division }
            let classification = divProfile?.classification.rawValue.uppercased() ?? "U"
            let percentage = divProfile?.currentPercentage ?? 0
            let highPercentage = divProfile?.highPercentage
            let classificationDate = divProfile?.classificationDate

            return (division: division, totalTime: totalTime, totalPeakTime: totalPeakTime, classification: classification, percentage: percentage, highPercentage: highPercentage, classificationDate: classificationDate, stages: stages)
        }
        .sorted { $0.division < $1.division }
    }

    private var hasClassificationScores: Bool {
        !allScores.filter({ $0.usedForClassification }).isEmpty
    }

    var body: some View {
        if hasClassificationScores {
            classificationListView
        } else {
            emptyStateView
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Classification Data", systemImage: "trophy.fill")
        } description: {
            Text("Sync your SCSA profile to see which scores were used for your classification")
        }
    }

    private var classificationListView: some View {
        List {
            ForEach(classificationScoresByDivision, id: \.division) { divisionGroup in
                DivisionSection(divisionGroup: divisionGroup)
            }
        }
    }
}

// MARK: - Division Section
private struct DivisionSection: View {
    let divisionGroup: (division: String, totalTime: Decimal, totalPeakTime: Decimal, classification: String, percentage: Decimal, highPercentage: Decimal?, classificationDate: Date?, stages: [(stageCode: String, stageName: String, scores: [SCMatchScore])])

    var body: some View {
        Section {
            // Prominent header showing division stats
            VStack(alignment: .leading, spacing: 12) {
                // Division and Classification
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(divisionGroup.division)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let classDate = divisionGroup.classificationDate {
                            Text(classDate, format: .dateTime.month(.abbreviated).day().year())
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Spacer()
                    
                    Text(divisionGroup.classification)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }
                
                // Current %, Total Time, and Peak Time
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current %")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(NSDecimalNumber(decimal: divisionGroup.percentage).doubleValue, specifier: "%.2f")%")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(NSDecimalNumber(decimal: divisionGroup.totalTime).doubleValue, specifier: "%.2f") sec")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Peak Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(NSDecimalNumber(decimal: divisionGroup.totalPeakTime).doubleValue, specifier: "%.2f") sec")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.yellow)
                            .monospacedDigit()
                    }
                }
                
                // Time to shave to reach next class (only if not GM)
                if let currentClass = ShooterClass(rawValue: divisionGroup.classification), currentClass != .GM {
                    let nextThreshold = currentClass.nextClassThreshold
                    let currentTime = NSDecimalNumber(decimal: divisionGroup.totalTime).doubleValue
                    let peakTime = NSDecimalNumber(decimal: divisionGroup.totalPeakTime).doubleValue
                    let nextThresholdDouble = NSDecimalNumber(decimal: nextThreshold).doubleValue
                    
                    // Calculate time needed to reach next threshold
                    // nextThreshold% = (peakTime / targetTime) * 100
                    // targetTime = (peakTime / nextThreshold) * 100
                    let targetTime = (peakTime / nextThresholdDouble) * 100.0
                    let timeToShave = currentTime - targetTime
                    
                    if timeToShave > 0 {
                        let nextClass: String = {
                            switch currentClass {
                            case .M: return "GM"
                            case .A: return "M"
                            case .B: return "A"
                            case .C: return "B"
                            case .D: return "C"
                            case .U: return "D"
                            case .GM: return "GM"
                            }
                        }()
                        
                        Text("Time to shave to reach \(nextClass): \(timeToShave, specifier: "%.2f") sec")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.vertical, 8)

            // Navigation to Reports
            NavigationLink {
                StageProgressReportView(divisionCode: divisionGroup.division)
            } label: {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.blue)
                    Text("View Stage Progress Report")
                        .font(.subheadline)
                }
                .padding(.vertical, 8)
            }
            
            // Score list
            ForEach(divisionGroup.stages, id: \.stageCode) { stage in
                ForEach(stage.scores, id: \.id) { score in
                    let percentage = score.peakTime > 0 ? (score.peakTime / score.time) * 100 : 0
                    let percentageValue = NSDecimalNumber(decimal: percentage).doubleValue

                    // Calculate classification for this specific stage based on performance
                    let stageClass = ShooterClass.shooterClass(percentage: percentage)
                    let nextClassName: String = {
                        switch stageClass {
                        case .M: return "GM"
                        case .A: return "M"
                        case .B: return "A"
                        case .C: return "B"
                        case .D: return "C"
                        case .U: return "D"
                        case .GM: return ""
                        }
                    }()
                    let timeNeeded: Double? = {
                        guard stageClass != .GM else { return nil }
                        let nextThreshold = NSDecimalNumber(decimal: stageClass.nextClassThreshold).doubleValue
                        let stageTime = NSDecimalNumber(decimal: score.time).doubleValue
                        let stagePeakTime = NSDecimalNumber(decimal: score.peakTime).doubleValue

                        // Calculate target time to reach next threshold
                        let targetTime = (stagePeakTime / nextThreshold) * 100.0
                        return stageTime - targetTime
                    }()

                    HStack(alignment: .center, spacing: 12) {
                        // Left - Stage code and name
                        VStack(alignment: .leading, spacing: 2) {
                            Text(score.stageCode)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(score.stageName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Right - Times and stats
                        VStack(alignment: .trailing, spacing: 2) {
                            // Time and Peak Time
                            HStack(spacing: 8) {
                                // Stage classification and time
                                HStack(spacing: 4) {
                                    Text(stageClass.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("\(NSDecimalNumber(decimal: score.time).doubleValue, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                }

                                Text("\(NSDecimalNumber(decimal: score.peakTime).doubleValue, specifier: "%.2f")")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.yellow)
                                    .monospacedDigit()
                            }

                            // Next class and Percentage
                            HStack(spacing: 8) {
                                if let needed = timeNeeded, needed > 0, !nextClassName.isEmpty {
                                    Text("\(nextClassName): -\(needed, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }

                                Text("\(percentageValue, specifier: "%.1f")%")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

}

// MARK: - Match Scores Tab
private struct MyScoresTabView: View {
    let allScores: [SCMatchScore]
    @Query private var profiles: [ShooterProfile]
    @State private var selectedDivision: String? = nil

    private var divisions: [String] {
        let uniqueDivisions = Set(allScores.map { $0.divisionCode })
        return uniqueDivisions.sorted()
    }

    private var filteredScores: [SCMatchScore] {
        if let selected = selectedDivision {
            return allScores.filter { $0.divisionCode == selected }
        }
        return allScores
    }

    // Group scores by date, then by match name
    private var groupedScores: [(date: Date, matchName: String, divisions: [String], scores: [SCMatchScore])] {
        // Group by date first
        let calendar = Calendar.current
        let byDate = Dictionary(grouping: filteredScores) { score in
            calendar.startOfDay(for: score.scoreDate)
        }

        // Convert to array and sort by date (newest first)
        return byDate.map { date, scores in
            // All scores on the same date should have the same match name
            let matchName = scores.first?.matchName ?? ""
            // Get unique divisions for this match
            let divisions = Array(Set(scores.map { $0.divisionCode })).sorted()
            // Sort scores by stage code
            let sortedScores = scores.sorted { $0.stageCode < $1.stageCode }
            return (date: date, matchName: matchName, divisions: divisions, scores: sortedScores)
        }
        .sorted { $0.date > $1.date }  // Newest first
    }

    private func getShooterClassification(for divisionCode: String) -> ShooterClass {
        guard let profile = profiles.first,
              let divProfile = profile.divisions.first(where: { $0.division.rawValue == divisionCode }) else {
            return .U
        }
        return divProfile.classification
    }

    var body: some View {
        if allScores.isEmpty {
            ContentUnavailableView {
                Label("No Match Scores", systemImage: "list.bullet")
            } description: {
                Text("Sync your SCSA profile to download your match history")
            }
        } else {
            VStack(spacing: 0) {
                // Division filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "All" pill
                        Button {
                selectedDivision = nil
                        } label: {
                Text("All")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedDivision == nil ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundStyle(selectedDivision == nil ? .white : .primary)
                    .clipShape(Capsule())
                        }

                        // Division pills
                        ForEach(divisions, id: \.self) { division in
                Button {
                    selectedDivision = division
                } label: {
                    Text(division)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedDivision == division ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundStyle(selectedDivision == division ? .white : .primary)
                        .clipShape(Capsule())
                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))

                Divider()

                // Scores list grouped by date
                List {
                    ForEach(groupedScores, id: \.date) { group in
                        Section {
                ForEach(group.scores, id: \.id) { score in
                    let percentage = score.peakTime > 0 ? (score.peakTime / score.time) * 100 : 0
                    let percentageValue = NSDecimalNumber(decimal: percentage).doubleValue
                    let scoreClass = ShooterClass.shooterClass(percentage: percentage)
                    let shooterClass = getShooterClassification(for: score.divisionCode)

                    // Determine color based on performance vs shooter's classification
                    let textColor: Color = {
                        if percentage >= 100 {
                            return .green  // Over 100% (beat the GM benchmark)
                        } else if scoreClass > shooterClass {
                            return .green  // Above their class
                        } else if scoreClass == shooterClass {
                            return .blue   // At their class level
                        } else {
                            return .red    // Below their class
                        }
                    }()

                    HStack(alignment: .top, spacing: 12) {
                        // Left side - Stage info
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(score.stageCode)
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                if score.usedForClassification {
                                    Image(systemName: "trophy.fill")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                }
                            }

                            Text(score.stageName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Right side - Performance metrics
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(NSDecimalNumber(decimal: score.time).doubleValue, specifier: "%.2f")")
                                .font(.title3)
                                .fontWeight(.bold)
                                .monospacedDigit()

                            Text("\(scoreClass.rawValue) \(percentageValue, specifier: "%.1f")%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(textColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
                        } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.matchName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .textCase(nil)

                    Text(group.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)

                    // Show division(s) only when "All" filter is selected
                    if selectedDivision == nil {
                        Text(group.divisions.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .textCase(nil)
                    }
                }
                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Classification Data Tab
private struct PercentageTableTabView: View {
    let profiles: [ShooterProfile]

    @State private var selectedStage: String? = nil  // nil means "All"

    // All divisions to show in the table
    private let allDivisions: [Division] = [.RFPO, .RFPI, .OPN, .CO, .PROD, .SS, .ISR, .OSR]

    // All stages
    private let allStageCodes = ["SC-101", "SC-102", "SC-103", "SC-104", "SC-105", "SC-106", "SC-107", "SC-108"]

    // Classification columns (skipping U and D as not meaningful)
    private let classifications: [ShooterClass] = [.C, .B, .A, .M, .GM]

    // Calculate total peak time for a division (sum of all 8 stages)
    private func totalPeakTime(for division: Division) -> Decimal {
        allStageCodes.reduce(Decimal(0)) { sum, stageCode in
            if let benchmark = PeakBenchmarks.get(division: division, stageCode: stageCode) {
                return sum + benchmark.peakTime
            }
            return sum
        }
    }

    // Calculate target time for a classification level
    private func targetTime(peakTime: Decimal, classificationPercent: Decimal) -> Decimal {
        guard classificationPercent > 0 else { return 0 }
        return (peakTime / classificationPercent) * 100
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stage filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "All" pill
                    Button {
                        selectedStage = nil
                    } label: {
                        Text("All")
                .font(.subheadline)
                .fontWeight(selectedStage == nil ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedStage == nil ? Color.blue : Color(.systemGray5))
                .foregroundStyle(selectedStage == nil ? .white : .primary)
                .cornerRadius(16)
                    }

                    // Stage pills
                    ForEach(allStageCodes, id: \.self) { stageCode in
                        Button {
                selectedStage = stageCode
                        } label: {
                Text(stageCode)
                    .font(.subheadline)
                    .fontWeight(selectedStage == stageCode ? .semibold : .regular)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedStage == stageCode ? Color.blue : Color(.systemGray5))
                    .foregroundStyle(selectedStage == stageCode ? .white : .primary)
                    .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))

            Divider()

            // Table content
            if selectedStage == nil {
                // Show "All" table (no per-string times)
                AllStagesTableView(
                    allDivisions: allDivisions,
                    classifications: classifications,
                    totalPeakTime: totalPeakTime,
                    targetTime: targetTime
                )
            } else {
                // Show stage-specific table (with per-string times)
                StageTableView(
                    stageCode: selectedStage!,
                    allDivisions: allDivisions,
                    classifications: classifications,
                    targetTime: targetTime
                )
            }
        }
    }
}

// MARK: - All Stages Table (no per-string times)
private struct AllStagesTableView: View {
    let allDivisions: [Division]
    let classifications: [ShooterClass]
    let totalPeakTime: (Division) -> Decimal
    let targetTime: (Decimal, Decimal) -> Decimal

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("Division")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 80, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)

                    Divider()

                    ForEach(classifications, id: \.self) { classification in
                        Text(classification.rawValue)
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 80, alignment: .center)
                .padding(.horizontal, 4)
                .padding(.vertical, 12)

                        if classification != classifications.last {
                Divider()
                        }
                    }

                    Divider()

                    Text("Peak")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 80, alignment: .center)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 12)
                }
                .background(Color(.systemGray5))

                Divider()

                // Data rows
                ForEach(allDivisions, id: \.self) { division in
                    HStack(spacing: 0) {
                        Text(division.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)

                        Divider()

                        let peakTime = totalPeakTime(division)

                        ForEach(classifications, id: \.self) { classification in
                let total = targetTime(peakTime, classification.percentThreshold)

                Text("\(NSDecimalNumber(decimal: total).doubleValue, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(width: 80, alignment: .center)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 12)

                if classification != classifications.last {
                    Divider()
                }
                        }

                        Divider()

                        Text("\(NSDecimalNumber(decimal: peakTime).doubleValue, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.yellow)
                .frame(width: 80, alignment: .center)
                .padding(.horizontal, 4)
                .padding(.vertical, 12)
                    }

                    if division != allDivisions.last {
                        Divider()
                    }
                }
            }
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Stage-Specific Table (with per-string times)
private struct StageTableView: View {
    let stageCode: String
    let allDivisions: [Division]
    let classifications: [ShooterClass]
    let targetTime: (Decimal, Decimal) -> Decimal

    private var stage: Stage? {
        getStage(for: stageCode)
    }

    private var stringsForClassification: Int {
        // SC-104 uses 3 strings, others use 4
        stageCode == "SC-104" ? 3 : 4
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("Division")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 80, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)

                    Divider()

                    ForEach(classifications, id: \.self) { classification in
                        Text(classification.rawValue)
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 90, alignment: .center)
                .padding(.horizontal, 4)
                .padding(.vertical, 12)

                        if classification != classifications.last {
                Divider()
                        }
                    }

                    Divider()

                    Text("Peak")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 90, alignment: .center)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 12)
                }
                .background(Color(.systemGray5))

                Divider()

                // Data rows
                ForEach(allDivisions, id: \.self) { division in
                    HStack(spacing: 0) {
                        Text(division.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)

                        Divider()

                        if let benchmark = PeakBenchmarks.get(division: division, stageCode: stageCode) {
                let peakTime = benchmark.peakTime

                ForEach(classifications, id: \.self) { classification in
                    let total = targetTime(peakTime, classification.percentThreshold)
                    let perString = total / Decimal(stringsForClassification)

                    VStack(spacing: 2) {
                        Text("\(NSDecimalNumber(decimal: total).doubleValue, specifier: "%.2f")")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("\(NSDecimalNumber(decimal: perString).doubleValue, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 90, alignment: .center)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)

                    if classification != classifications.last {
                        Divider()
                    }
                }

                Divider()

                let perStringPeak = peakTime / Decimal(stringsForClassification)
                VStack(spacing: 2) {
                    Text("\(NSDecimalNumber(decimal: peakTime).doubleValue, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.yellow)

                    Text("\(NSDecimalNumber(decimal: perStringPeak).doubleValue, specifier: "%.2f")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 90, alignment: .center)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                        }
                    }

                    if division != allDivisions.last {
                        Divider()
                    }
                }
            }
            .background(Color(.systemBackground))
        }
    }
}
