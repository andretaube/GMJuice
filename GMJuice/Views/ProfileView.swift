//
//  ProfileView.swift
//  GMJuice
//
//  Created by Claude on 11/5/25.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SCMatchScore.scoreDate, order: .reverse) private var allScores: [SCMatchScore]
    @Query private var profiles: [ShooterProfile]
    @State private var selectedTab = 0
    @StateObject private var scraper = SCWebScraper.shared
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingUSPSASettings = false
    @AppStorage("scsa_auto_sync_enabled") private var autoSyncEnabled = true
    @State private var showingCoachMarks = false
    @State private var trackedFrames: [String: CGRect] = [:]
    @AppStorage("hasSeenProfileCoachMarks") private var hasSeenCoachMarks = false
    @State private var previousUSPSANumber: String = ""

    private var hasUSPSANumber: Bool {
        guard let profile = profiles.first else { return false }
        return !profile.uspsaNumber.isEmpty
    }

    private var hasExistingData: Bool {
        return !allScores.isEmpty || profiles.first?.divisions.isEmpty == false
    }

    // Create coach marks from tracked frames
    private func createCoachMarks() -> [CoachMark]? {
        // Only show coach marks when user has USPSA number and data
        guard hasUSPSANumber else { return nil }

        guard let uspsaNumberFrame = trackedFrames["uspsaNumber"],
              let matchScoresTabFrame = trackedFrames["matchScoresTab"],
              let firstDivisionFrame = trackedFrames["firstDivision"] else {
            return nil
        }

        var marks: [CoachMark] = []

        // 1. USPSA Number
        marks.append(CoachMark(
            title: "Edit USPSA Number",
            message: "Tap here to edit your USPSA member number or adjust auto-sync settings for your classification data.",
            highlightFrame: uspsaNumberFrame,
            calloutPosition: .bottom
        ))

        // 2. Division Section
        marks.append(CoachMark(
            title: "Division Summary",
            message: "Each division shows your classification level, current percentage, total time, and peak time. The chevron indicates you can tap to expand and view individual stage scores.",
            highlightFrame: firstDivisionFrame,
            calloutPosition: .top
        ))

        // 3. Expand for stages (only if we have the chevron frame)
        if let chevronFrame = trackedFrames["divisionChevron"] {
            marks.append(CoachMark(
                title: "Expand Division",
                message: "Tap on any division to expand and view all 8 classifier stages used for your classification score. Each stage shows your time, classification level, and what you need to reach the next level.",
                highlightFrame: chevronFrame,
                calloutPosition: .top
            ))
        }

        // 4. Match Scores Tab
        marks.append(CoachMark(
            title: "View All Match Scores",
            message: "Switch to this tab to view all your match scores from every competition, not just the ones used for classification.",
            highlightFrame: matchScoresTabFrame,
            calloutPosition: .bottom
        ))

        return marks
    }

    private func ensureProfile() -> ShooterProfile {
        if let first = profiles.first {
            return first
        }
        let created = ShooterProfile()
        context.insert(created)
        do { try context.save() } catch { print("Initial save failed: \(error)") }
        return created
    }

    private func deleteUSPSAData() {
        // Delete all match scores (USPSA-related data)
        do {
            try context.delete(model: SCMatchScore.self)

            // Clear division profiles but keep the profile
            if let profile = profiles.first {
                profile.divisions.removeAll()
            }

            try context.save()
            print("✅ Deleted all USPSA-related data")
        } catch {
            print("⚠️ Error deleting USPSA data: \(error)")
        }
    }

    private func syncClassificationData(profile: ShooterProfile) async {
        guard !profile.uspsaNumber.isEmpty else {
            errorMessage = "Please enter your SCSA member number first"
            showingError = true
            return
        }

        let hadDataBefore = hasExistingData

        do {
            try await scraper.syncClassificationData(memberNumber: profile.uspsaNumber, context: context)
            // Update previous number on successful sync
            await MainActor.run {
                previousUSPSANumber = profile.uspsaNumber
            }
        } catch let error as NSError where error.code == 404 {
            await MainActor.run {
                errorMessage = "Unable to find USPSA member number. Please check the number and try again."
                showingError = true

                // If there was no data before, clear the USPSA number
                if !hadDataBefore {
                    profile.uspsaNumber = ""
                    try? context.save()
                }
            }
        } catch let error as NSError where error.code == 403 {
            await MainActor.run {
                errorMessage = "Access denied by SCSA website. This is usually temporary. Please try again in a few minutes."
                showingError = true

                // If there was no data before, clear the USPSA number
                if !hadDataBefore {
                    profile.uspsaNumber = ""
                    try? context.save()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true

                // If there was no data before, clear the USPSA number
                if !hadDataBefore {
                    profile.uspsaNumber = ""
                    try? context.save()
                }
            }
        }
    }

    var body: some View {
        let p = ensureProfile()
        @Bindable var profile = p

        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    // Tab picker
                    Picker("View", selection: $selectedTab) {
                        Text("Profile").tag(0)
                        Text("Match Scores").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: FramePreferenceKey.self,
                                value: ["matchScoresTab": geometry.frame(in: .global).offsetBy(dx: geometry.size.width / 2, dy: 0)]
                            )
                        }
                    )

                    if selectedTab == 0 {
                        ProfileStatsView(
                            allScores: allScores,
                            profiles: profiles,
                            profile: profile,
                            onShowSettings: {
                                showingUSPSASettings = true
                            }
                        )
                    } else {
                        MyScoresTabView(allScores: allScores)
                    }
                }
                .onAppear {
                    // Initialize previous number on appear
                    if previousUSPSANumber.isEmpty && !profile.uspsaNumber.isEmpty {
                        previousUSPSANumber = profile.uspsaNumber
                    }
                }
                .navigationTitle("Profile")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            if createCoachMarks() != nil {
                                showingCoachMarks = true
                            }
                        } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                }
                .onPreferenceChange(FramePreferenceKey.self) { frames in
                    trackedFrames = frames

                    // Show coach marks on first visit once frames are available and user has USPSA number
                    if !hasSeenCoachMarks && !showingCoachMarks && !frames.isEmpty && hasUSPSANumber {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showingCoachMarks = true
                            hasSeenCoachMarks = true
                        }
                    }
                }
                .sheet(isPresented: $showingUSPSASettings) {
                    USPSASettingsSheet(
                        profile: profile,
                        autoSyncEnabled: $autoSyncEnabled,
                        previousNumber: previousUSPSANumber,
                        hasExistingData: hasExistingData,
                        onSync: {
                            Task {
                                await syncClassificationData(profile: profile)
                            }
                        },
                        onDeleteData: {
                            deleteUSPSAData()
                        }
                    )
                }
                .alert("Sync Error", isPresented: $showingError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
            }

            // Coach marks overlay at the top level
            if showingCoachMarks, let marks = createCoachMarks() {
                CoachMarkOverlay(isPresented: $showingCoachMarks, marks: marks)
            }
        }
    }
}

// MARK: - Profile Stats View

private struct ProfileStatsView: View {
    let allScores: [SCMatchScore]
    let profiles: [ShooterProfile]
    @Bindable var profile: ShooterProfile
    let onShowSettings: () -> Void

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
        if profile.uspsaNumber.isEmpty {
            // Show simple prompt to add USPSA number
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)

                    Image(systemName: "person.circle")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    VStack(spacing: 12) {
                        Text("Add Your USPSA Number")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Track your classifications and performance across all divisions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Button {
                        onShowSettings()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add USPSA Number")
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
        } else if classificationScoresByDivision.isEmpty {
            // Has number but no data
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

                        Text("Sync your SCSA profile to download your classification scores")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Button {
                        onShowSettings()
                    } label: {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                            Text("Enter Your USPSA Number")
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
            // Has data - show profile stats
            List {
                // USPSA Number Header - tappable to open settings
                Section {
                    Button {
                        onShowSettings()
                    } label: {
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
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .trackFrame(named: "uspsaNumber")
                }

                // Division sections
                ForEach(Array(classificationScoresByDivision.enumerated()), id: \.element.division) { index, divisionGroup in
                    DivisionProfileSection(
                        divisionGroup: divisionGroup,
                        allScores: allScores,
                        isFirst: index == 0
                    )
                }
            }
        }
    }
}

// MARK: - Division Section

private struct DivisionProfileSection: View {
    let divisionGroup: (division: String, totalTime: Decimal, totalPeakTime: Decimal, classification: String, percentage: Decimal, highPercentage: Decimal?, classificationDate: Date?, stages: [(stageCode: String, stageName: String, scores: [SCMatchScore])])
    let allScores: [SCMatchScore]
    var isFirst: Bool = false

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
                        .trackFrame(named: isFirst ? "divisionChevron" : "")
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
            .trackFrame(named: isFirst ? "firstDivision" : "")

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

        // Calculate improvement potential
        let bestClassification = ShooterClass.shooterClass(percentage: bestPercentage)
        let nextClassification = bestClassification.nextClass
        let nextThreshold = bestClassification.nextClassThreshold

        let timeToNextLevel: Decimal
        if peakTime > 0 && nextThreshold > 0 {
            timeToNextLevel = peakTime / (nextThreshold / 100)
        } else {
            timeToNextLevel = 0
        }

        let gainToNextLevel = bestTime - timeToNextLevel

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
            bestClassification: bestClassification,
            averageClassification: ShooterClass.shooterClass(percentage: avgPercentage),
            bestPerformanceVsPeak: bestPercentage,
            nextClassification: nextClassification,
            timeToNextLevel: timeToNextLevel,
            gainToNextLevel: gainToNextLevel,
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

// MARK: - USPSA Settings Sheet

private struct USPSASettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var profile: ShooterProfile
    @Binding var autoSyncEnabled: Bool
    let previousNumber: String
    let hasExistingData: Bool
    let onSync: () -> Void
    let onDeleteData: () -> Void
    @StateObject private var scraper = SCWebScraper.shared
    @State private var initialNumber: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("SCSA Member Number", text: $profile.uspsaNumber)
                        .textContentType(.username)
                        .autocapitalization(.allCharacters)
                        .font(.body)
                        .onChange(of: profile.uspsaNumber) { oldValue, newValue in
                            // Don't save on every keystroke for now
                        }
                        .onAppear {
                            initialNumber = profile.uspsaNumber
                        }
                } header: {
                    Text("USPSA Number")
                } footer: {
                    Text("Enter your USPSA/SCSA member number to sync your classification data")
                }

                if !profile.uspsaNumber.isEmpty {
                    Section {
                        Toggle("Auto-sync my data", isOn: $autoSyncEnabled)

                        if autoSyncEnabled, let lastSync = scraper.lastSyncDate {
                            HStack {
                                Text("Last synced")
                                Spacer()
                                Text(lastSync, format: .relative(presentation: .named))
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    } header: {
                        Text("Sync Settings")
                    } footer: {
                        Text("Your classification data will sync automatically when you open the app. SCSA updates scores on Wednesdays.")
                    }

                    Section {
                        Button {
                            onSync()
                        } label: {
                            HStack {
                                Spacer()
                                if scraper.isScraping {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                }
                                Text("Sync Now")
                                Spacer()
                            }
                        }
                        .disabled(scraper.isScraping)
                    }
                }
            }
            .navigationTitle("USPSA Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        let newNumber = profile.uspsaNumber.trimmingCharacters(in: .whitespaces)
                        let numberChanged = newNumber != initialNumber

                        // If number changed to a different value
                        if numberChanged && !newNumber.isEmpty {
                            // If there was existing data with a previous number, delete it
                            if hasExistingData && !previousNumber.isEmpty {
                                onDeleteData()
                            }

                            // Save the new number
                            profile.uspsaNumber = newNumber
                            try? context.save()

                            dismiss()

                            // Trigger sync after dismiss
                            autoSyncEnabled = true
                            Task {
                                try? await Task.sleep(nanoseconds: 300_000_000)
                                onSync()
                            }
                        } else if numberChanged && newNumber.isEmpty {
                            // Number was cleared - just save and dismiss
                            profile.uspsaNumber = ""
                            try? context.save()
                            dismiss()
                        } else {
                            // No change or invalid change - dismiss without sync
                            dismiss()
                        }
                    }
                }
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
