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
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [ShooterProfile]
    @StateObject private var scraper = SCWebScraper.shared
    @StateObject private var remoteConfig = RemoteConfigService.shared

    // Optional USPSA number - if provided, show that profile; otherwise show current user
    let uspsaNumber: String?

    @State private var selectedTab = 0
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingUSPSASettings = false
    @State private var showingCoachMarks = false
    @State private var showingCompare = false
    @State private var showingDeleteConfirmation = false
    @State private var trackedFrames: [String: CGRect] = [:]
    @AppStorage("hasSeenProfileCoachMarks") private var hasSeenCoachMarks = false
    @State private var previousUSPSANumber: String = ""

    init(uspsaNumber: String? = nil) {
        self.uspsaNumber = uspsaNumber
    }

    private var currentUserNumber: String? {
        UserDefaults.standard.currentUserUSPSANumber
    }

    // Check if viewing current user's profile or a followed shooter
    private var isCurrentUser: Bool {
        if let uspsaNumber = uspsaNumber {
            return uspsaNumber == currentUserNumber
        }
        return true // Default to current user if no USPSA number specified
    }

    // Get the profile to display (either specified USPSA number or current user)
    private var myProfile: ShooterProfile? {
        if let uspsaNumber = uspsaNumber {
            // Show specific profile by USPSA number
            return profiles.first { $0.uspsaNumber == uspsaNumber }
        } else {
            // Show current user's profile
            guard let currentUser = currentUserNumber else {
                // No current user set - use first profile for backward compatibility
                return profiles.first
            }
            return profiles.first { $0.uspsaNumber == currentUser }
        }
    }

    // Get current user's profile for comparison (when viewing a followed shooter)
    private var currentUserProfile: ShooterProfile? {
        guard let currentUser = currentUserNumber else { return nil }
        return profiles.first { $0.uspsaNumber == currentUser }
    }

    // Get current user's scores from their profile relationship - with error recovery
    private var myScores: [MatchScore] {
        guard let profile = myProfile else { return [] }

        // Safely access match scores with error recovery
        return ProfileErrorRecovery.safelyAccessProfile(
            context: context,
            profileNumber: profile.uspsaNumber,
            autoRecover: true
        ) {
            profile.matchScores.sorted { $0.scoreDate > $1.scoreDate }
        } ?? []
    }

    private var hasUSPSANumber: Bool {
        guard let profile = myProfile else { return false }
        return !profile.uspsaNumber.isEmpty
    }

    private var hasExistingData: Bool {
        return !myScores.isEmpty || myProfile?.divisions.isEmpty == false
    }

    // Create coach marks from tracked frames
    private func createCoachMarks() -> [CoachMark]? {
        // Only show coach marks when user has USPSA number and data
        guard hasUSPSANumber else { return nil }

        guard let uspsaNumberFrame = trackedFrames["uspsaNumber"],
              let tabPickerFrame = trackedFrames["tabPicker"],
              let firstDivisionFrame = trackedFrames["firstDivision"] else {
            return nil
        }

        var marks: [CoachMark] = []

        // 1. Tab Navigation
        marks.append(CoachMark(
            title: "Navigation Tabs",
            message: "Switch between Profile, Match Scores, and Following tabs to view different aspects of your shooting data.",
            highlightFrame: tabPickerFrame,
            calloutPosition: .bottom
        ))

        // 2. USPSA Number
        marks.append(CoachMark(
            title: "Edit USPSA Number",
            message: "Tap here to edit your USPSA member number and view sync status for your classification data.",
            highlightFrame: uspsaNumberFrame,
            calloutPosition: .bottom
        ))

        // 3. Division Section
        marks.append(CoachMark(
            title: "Division Summary",
            message: "Each division shows your classification level, current percentage, total time, and peak time. The chevron indicates you can tap to expand and view individual stage scores.",
            highlightFrame: firstDivisionFrame,
            calloutPosition: .top
        ))

        // 4. Expand for stages (only if we have the chevron frame)
        if let chevronFrame = trackedFrames["divisionChevron"] {
            marks.append(CoachMark(
                title: "Expand Division",
                message: "Tap on any division to expand and view all 8 classifier stages used for your classification score. Each stage shows your time, classification level, and what you need to reach the next level.",
                highlightFrame: chevronFrame,
                calloutPosition: .top
            ))
        }

        // 5. Match Scores Division Filter (only if we have the frame from Match Scores tab)
        if let divisionFilterFrame = trackedFrames["divisionFilter"] {
            marks.append(CoachMark(
                title: "Filter by Division",
                message: "Use these pills to filter your match scores by division. Tap 'All' to see scores from all divisions, or select a specific division to view only those scores.",
                highlightFrame: divisionFilterFrame,
                calloutPosition: .bottom
            ))
        }

        // 6. Following Tab (only if current user and has followed shooters)
        if isCurrentUser,
           let followingTabFrame = trackedFrames["followingTab"],
           let currentUser = currentUserNumber {
            let followedCount = profiles.filter { $0.uspsaNumber != currentUser && !$0.uspsaNumber.isEmpty }.count
            if followedCount > 0 {
                marks.append(CoachMark(
                    title: "Compare with Others",
                    message: "View shooters you're following and compare your performance against them to track your progress.",
                    highlightFrame: followingTabFrame,
                    calloutPosition: .bottom
                ))
            }
        }

        return marks
    }

    private func ensureProfile() -> ShooterProfile {
        // Use myProfile which handles current user logic
        if let profile = myProfile {
            return profile
        }
        // No profile exists yet - create one
        let created = ShooterProfile()
        context.insert(created)
        do { try context.save() } catch { print("Initial save failed: \(error)") }
        return created
    }

    private func deleteUSPSAData() {
        // Delete all match scores (USPSA-related data)
        do {
            try context.delete(model: MatchScore.self)

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
        
        // Check if SCSA data is enabled via Remote Config
        guard RemoteConfigService.shared.isSCSADataEnabled else {
            errorMessage = "SCSA data import is currently disabled"
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
                    UserDefaults.standard.currentUserUSPSANumber = nil
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
                    UserDefaults.standard.currentUserUSPSANumber = nil
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
                    UserDefaults.standard.currentUserUSPSANumber = nil
                    try? context.save()
                }
            }
        }
    }

    var body: some View {
        let p = ensureProfile()
        @Bindable var profile = p

        NavigationStack {
            ProfileStatsView(
                allScores: myScores,
                profile: profile,
                isCurrentUser: true,
                currentUserProfile: nil,
                onShowSettings: { showingUSPSASettings = true },
                onCompare: {}
            )
            .onAppear {
                if previousUSPSANumber.isEmpty && !profile.uspsaNumber.isEmpty {
                    previousUSPSANumber = profile.uspsaNumber
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingUSPSASettings) {
                if let profile = myProfile {
                    USPSANumberSheet(profile: profile, isEditable: true, onUnfollow: nil)
                }
            }
            .alert("Sync Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - Profile Stats View

private struct ProfileStatsView: View {
    let allScores: [MatchScore]
    @Bindable var profile: ShooterProfile
    let isCurrentUser: Bool
    let currentUserProfile: ShooterProfile?
    let onShowSettings: () -> Void
    let onCompare: () -> Void

    private func calculateTotalPeakTime(for division: Division) -> Decimal {
        var total = Decimal(0)
        for stage in AllStages {
            if let benchmark = CurrentPeakBenchmarks.get(division: division, stageCode: stage.code) {
                total += benchmark.peakTime
            }
        }
        return total
    }

    private var classificationScoresByDivision: [(division: String, totalTime: Decimal, totalPeakTime: Decimal, classification: String, percentage: Decimal, highPercentage: Decimal?, classificationDate: Date?, stages: [(stageCode: String, stageName: String, scores: [MatchScore])])] {
        // ONLY show scores where usedForClassification = true (one score per stage per division)
        let usedScores = allScores.filter { $0.usedForClassification }

        let byDivision = Dictionary(grouping: usedScores) { $0.divisionCode }

        // Start with all divisions that have a classification in the profile
        var allDivisions: [(division: String, totalTime: Decimal, totalPeakTime: Decimal, classification: String, percentage: Decimal, highPercentage: Decimal?, classificationDate: Date?, stages: [(stageCode: String, stageName: String, scores: [MatchScore])])] = []

        // Add divisions that have classification scores
        for (division, scores) in byDivision {
            // Get classification info from profile
            let divProfile = profile.divisions.first { $0.division.rawValue == division }

            // Skip if division is not visible
            guard divProfile?.isVisible ?? true else { continue }

            let totalTime = scores.reduce(Decimal(0)) { $0 + $1.time }
            let byStage = Dictionary(grouping: scores) { $0.stageCode }
            let stages = byStage.map { (stageCode: $0.key, stageName: stageName(for: $0.key), scores: $0.value.sorted { $0.scoreDate > $1.scoreDate }) }
                .sorted { $0.stageCode < $1.stageCode }

            let classification = divProfile?.classification.rawValue.uppercased() ?? "U"
            let percentage = divProfile?.currentPercentage ?? 0
            let highPercentage = divProfile?.highPercentage
            let classificationDate = divProfile?.classificationDate

            // Calculate peak time for all 8 standard Steel Challenge stages (not just classification scores)
            let totalPeakTime: Decimal
            if let divisionEnum = Division(rawValue: division) {
                totalPeakTime = AllStages.reduce(Decimal(0)) { total, stage in
                    if let benchmark = CurrentPeakBenchmarks.get(division: divisionEnum, stageCode: stage.code) {
                        return total + benchmark.peakTime
                    }
                    return total
                }
            } else {
                totalPeakTime = scores.reduce(Decimal(0)) { $0 + $1.peakTime }
            }

            allDivisions.append((division: division, totalTime: totalTime, totalPeakTime: totalPeakTime, classification: classification, percentage: percentage, highPercentage: highPercentage, classificationDate: classificationDate, stages: stages))
        }

        // Add divisions from profile that don't have classification scores yet but have a classification
        for divProfile in profile.divisions where divProfile.classification != .U && divProfile.isVisible {
            let divisionCode = divProfile.division.rawValue
            // Skip if already added from match scores
            if !allDivisions.contains(where: { $0.division == divisionCode }) {
                // Calculate peak time for all 8 standard Steel Challenge stages
                let allEightStagesPeakTime = AllStages.reduce(Decimal(0)) { total, stage in
                    if let benchmark = CurrentPeakBenchmarks.get(division: divProfile.division, stageCode: stage.code) {
                        return total + benchmark.peakTime
                    }
                    return total
                }

                allDivisions.append((
                    division: divisionCode,
                    totalTime: 0,
                    totalPeakTime: allEightStagesPeakTime,
                    classification: divProfile.classification.rawValue.uppercased(),
                    percentage: divProfile.currentPercentage ?? 0,
                    highPercentage: divProfile.highPercentage,
                    classificationDate: divProfile.classificationDate,
                    stages: []
                ))
            }
        }

        return allDivisions.sorted { $0.division < $1.division }
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
                        .foregroundStyle(Color.gmAmber)

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
                        .background(Color.gmAmber)
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
                        .foregroundStyle(Color.gmAmber)

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
                        .background(Color.gmAmber)
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
                                .foregroundStyle(Color.gmAmber)

                            VStack(alignment: .leading, spacing: 4) {
                                if !profile.name.isEmpty {
                                    Text(profile.name)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.primary)
                                    Text("USPSA# \(profile.uspsaNumber)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("USPSA Member")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(profile.uspsaNumber)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.primary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    // Compare button - only show when viewing someone else's profile
                    if !isCurrentUser {
                        Button {
                            onCompare()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.left.arrow.right")
                                    .foregroundStyle(.purple)
                                Text("Stage-by-Stage Comparison")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(currentUserProfile == nil)
                    }
                }
                .trackFrame(named: "uspsaNumber")

                // Division sections
                ForEach(Array(classificationScoresByDivision.enumerated()), id: \.element.division) { index, divisionGroup in
                    DivisionProfileSection(
                        divisionGroup: divisionGroup,
                        allScores: allScores,
                        profileUSPSANumber: profile.uspsaNumber,
                        isFirst: index == 0
                    )
                }
            }
        }
    }
}

// MARK: - Division Section

private struct DivisionProfileSection: View {
    let divisionGroup: (division: String, totalTime: Decimal, totalPeakTime: Decimal, classification: String, percentage: Decimal, highPercentage: Decimal?, classificationDate: Date?, stages: [(stageCode: String, stageName: String, scores: [MatchScore])])
    let allScores: [MatchScore]
    let profileUSPSANumber: String
    var isFirst: Bool = false

    @State private var isExpanded = false

    /// The stage with the lowest classification percentage — the one to practice next.
    private var weakestStage: (code: String, name: String, pct: Double)? {
        var result: (code: String, name: String, pct: Double)?
        for stage in divisionGroup.stages {
            guard let score = stage.scores.first, score.time > 0 else { continue }
            let pct = NSDecimalNumber(decimal: score.peakTime / score.time * 100).doubleValue
            if result == nil || pct < result!.pct {
                result = (code: stage.stageCode, name: stage.stageName, pct: pct)
            }
        }
        return result
    }

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
                                .foregroundStyle(Color.gmAmber)

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
                                .foregroundStyle(Color.gmAmber)
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

                    // Show message if no recent classification scores
                    if divisionGroup.totalTime == 0 {
                        Text("No recent classification scores")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .padding(.top, 4)
                    }

                    // Time to shave to reach next class (only if not GM and has classification scores)
                    if divisionGroup.totalTime > 0, let currentClass = ShooterClass(rawValue: divisionGroup.classification), currentClass != .GM {
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

            // Expanded detail
            if isExpanded {
                // B — "Why this class?" explainer
                VStack(alignment: .leading, spacing: 4) {
                    Label("Why \(divisionGroup.classification)?", systemImage: "info.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.gmAmber)
                    Text("Your classification is the GM peak time ÷ your time, averaged across the 8 classifier stages. You're shooting \(NSDecimalNumber(decimal: divisionGroup.percentage).doubleValue, specifier: "%.0f")% of GM pace.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                // C — Focus next: weakest stage
                if let weak = weakestStage {
                    Label {
                        Text("Focus next: ").foregroundStyle(.secondary)
                        + Text("\(weak.code) \(weak.name)").fontWeight(.semibold)
                        + Text(" — \(weak.pct, specifier: "%.0f")%").foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "scope").foregroundStyle(.orange)
                    }
                    .font(.caption)
                    .padding(.bottom, 4)
                }

                ForEach(divisionGroup.stages, id: \.stageCode) { stage in
                    ForEach(stage.scores, id: \.id) { score in
                        StageScoreRow(score: score)
                    }
                }
            }
        }
    }
}

// MARK: - Stage Score Row

private struct StageScoreRow: View {
    let score: MatchScore

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
                Text(stageName(for: score.stageCode))
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
                        .foregroundStyle(Color.gmAmber)
                }
            }
        }
        .padding(.vertical, 6)
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
    @StateObject private var remoteConfig = RemoteConfigService.shared
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
                        if remoteConfig.isSCSADataEnabled {
                            Text("Your classification data will sync automatically when you open the app. SCSA updates scores on Wednesdays.")
                        } else {
                            Text("SCSA data refresh is currently not available, please check again later")
                                .foregroundStyle(.orange)
                        }
                    }

                    if remoteConfig.isSCSADataEnabled {
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

                            // Save the new number to profile
                            profile.uspsaNumber = newNumber
                            try? context.save()

                            // Also save to UserDefaults to mark this as "my" profile
                            UserDefaults.standard.currentUserUSPSANumber = newNumber

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

                            // Also clear from UserDefaults
                            UserDefaults.standard.currentUserUSPSANumber = nil

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
                .foregroundStyle(Color.gmAmber)
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

