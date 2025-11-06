//
//  ProfileView.swift
//  GMJuice
//
//  Created by Claude on 11/5/25.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
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
                    NoUSPSANumberView()
                } else {
                    // Tab picker
                    Picker("View", selection: $selectedTab) {
                        Text("Profile").tag(0)
                        Text("Match Scores").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if selectedTab == 0 {
                        ProfileStatsView(allScores: allScores, profiles: profiles)
                    } else {
                        MyScoresTabView(allScores: allScores)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

// MARK: - Profile Stats View

private struct ProfileStatsView: View {
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

    var body: some View {
        if classificationScoresByDivision.isEmpty {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)

                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    VStack(spacing: 12) {
                        Text("No Classification Data")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Sync your SCSA profile to download your classification scores and statistics")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    NavigationLink(destination: ShooterProfileView()) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync Profile")
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
        } else {
            List {
                // USPSA Number Header
                if let profile = profiles.first {
                    Section {
                        NavigationLink(destination: ShooterProfileView()) {
                            HStack {
                                Image(systemName: "person.text.rectangle")
                                    .font(.title2)
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("USPSA Member")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(profile.uspsaNumber)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }

                // Division sections
                ForEach(classificationScoresByDivision, id: \.division) { divisionGroup in
                    DivisionProfileSection(divisionGroup: divisionGroup, allScores: allScores)
                }
            }
        }
    }
}

// MARK: - Division Section

private struct DivisionProfileSection: View {
    let divisionGroup: (division: String, totalTime: Decimal, totalPeakTime: Decimal, classification: String, percentage: Decimal, highPercentage: Decimal?, classificationDate: Date?, stages: [(stageCode: String, stageName: String, scores: [SCMatchScore])])
    let allScores: [SCMatchScore]

    @State private var isExpanded = false

    var body: some View {
        Section {
            // Division header with stats
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    // Division and Classification
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(divisionGroup.division)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)

                            if let classDate = divisionGroup.classificationDate {
                                Text(classDate, format: .dateTime.month(.abbreviated).day().year())
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Text(divisionGroup.classification)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
            }
            .buttonStyle(.plain)

            // Expanded stage list
            if isExpanded {
                ForEach(divisionGroup.stages, id: \.stageCode) { stage in
                    ForEach(stage.scores, id: \.id) { score in
                        NavigationLink {
                            // Navigate to stage detail analysis view
                            StageDetailAnalysisViewWrapper(
                                divisionCode: divisionGroup.division,
                                stageCode: score.stageCode,
                                allScores: allScores
                            )
                        } label: {
                            StageScoreRow(score: score)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Stage Score Row

private struct StageScoreRow: View {
    let score: SCMatchScore

    var body: some View {
        let percentage = score.peakTime > 0 ? (score.peakTime / score.time) * 100 : 0
        let percentageValue = NSDecimalNumber(decimal: percentage).doubleValue
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

// MARK: - Stage Detail Analysis Wrapper

private struct StageDetailAnalysisViewWrapper: View {
    let divisionCode: String
    let stageCode: String
    let allScores: [SCMatchScore]

    @Query private var allMatchScores: [SCMatchScore]

    // Create a fake StageAnalysis from the score data
    private var stageAnalysis: StageAnalysis? {
        let divisionScores = allMatchScores.filter {
            $0.divisionCode == divisionCode &&
            $0.stageCode == stageCode
        }

        guard !divisionScores.isEmpty else { return nil }

        let times = divisionScores.map { $0.time }
        let bestTime = times.min() ?? 0
        let averageTime = times.reduce(Decimal(0), +) / Decimal(times.count)
        let peakTime = divisionScores.first?.peakTime ?? 0

        let bestPercentage = peakTime > 0 ? (peakTime / bestTime) * 100 : 0
        let avgPercentage = peakTime > 0 ? (peakTime / averageTime) * 100 : 0

        // Calculate consistency (coefficient of variation)
        let mean = NSDecimalNumber(decimal: averageTime).doubleValue
        let variance = times.map { NSDecimalNumber(decimal: $0).doubleValue }
            .reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(times.count)
        let stdDev = sqrt(variance)
        let cv = (stdDev / mean) * 100.0

        // Calculate trend (simple: compare first half vs second half)
        let halfCount = times.count / 2
        let firstHalf = Array(times.prefix(halfCount))
        let secondHalf = Array(times.suffix(halfCount))
        let firstAvg = firstHalf.isEmpty ? 0 : NSDecimalNumber(decimal: firstHalf.reduce(Decimal(0), +) / Decimal(firstHalf.count)).doubleValue
        let secondAvg = secondHalf.isEmpty ? 0 : NSDecimalNumber(decimal: secondHalf.reduce(Decimal(0), +) / Decimal(secondHalf.count)).doubleValue
        let trend = firstAvg > 0 ? ((firstAvg - secondAvg) / firstAvg) * 100.0 : 0

        return StageAnalysis(
            stageCode: stageCode,
            stageName: divisionScores.first?.stageName ?? stageCode,
            matchCount: divisionScores.count,
            averageTime: averageTime,
            bestTime: bestTime,
            standardDeviation: Decimal(stdDev),
            peakTime: peakTime,
            consistencyScore: Decimal(cv),
            performanceVsPeak: avgPercentage,
            recentTrend: Decimal(trend),
            bestClassification: ShooterClass.shooterClass(percentage: bestPercentage),
            averageClassification: ShooterClass.shooterClass(percentage: avgPercentage),
            mostRecentDate: divisionScores.map { $0.scoreDate }.max(),
            oldestDate: divisionScores.map { $0.scoreDate }.min()
        )
    }

    var body: some View {
        if let analysis = stageAnalysis {
            StageDetailAnalysisView(stageAnalysis: analysis, divisionCode: divisionCode)
        } else {
            ContentUnavailableView {
                Label("No Data", systemImage: "chart.line.uptrend.xyaxis")
            } description: {
                Text("No match scores found for this stage")
            }
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
                Image(systemName: "person.circle")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                // Header
                VStack(spacing: 12) {
                    Text("Connect Your Profile")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Add your USPSA member number to track your classifications and performance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Benefits
                VStack(alignment: .leading, spacing: 16) {
                    ProfileBenefitRow(
                        icon: "trophy.fill",
                        title: "Track Classifications",
                        description: "Monitor your SCSA standings across all divisions"
                    )

                    ProfileBenefitRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Performance Analytics",
                        description: "View detailed analysis and trends for each stage"
                    )

                    ProfileBenefitRow(
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

private struct ProfileBenefitRow: View {
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

// MARK: - Match Scores Tab (reused from MatchesView)

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
