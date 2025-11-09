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

        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    // Tab picker - hide "Following" tab when viewing someone else's profile
                    if isCurrentUser {
                        Picker("View", selection: $selectedTab) {
                            Text("Profile").tag(0)
                            Text("Match Scores").tag(1)
                                .trackFrame(named: "matchScoresTab")
                            Text("Following").tag(2)
                                .trackFrame(named: "followingTab")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .trackFrame(named: "tabPicker")
                    } else {
                        Picker("View", selection: $selectedTab) {
                            Text("Profile").tag(0)
                            Text("Match Scores").tag(1)
                                .trackFrame(named: "matchScoresTab")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .trackFrame(named: "tabPicker")
                    }

                    if selectedTab == 0 {
                        ProfileStatsView(
                            allScores: myScores,
                            profile: profile,
                            isCurrentUser: isCurrentUser,
                            currentUserProfile: currentUserProfile,
                            onShowSettings: {
                                showingUSPSASettings = true
                            },
                            onCompare: {
                                showingCompare = true
                            }
                        )
                    } else if selectedTab == 1 {
                        MyScoresTabView(allScores: myScores, trackedFrames: $trackedFrames)
                    } else {
                        FollowingView()
                    }
                }
                .onAppear {
                    // Initialize previous number on appear
                    if previousUSPSANumber.isEmpty && !profile.uspsaNumber.isEmpty {
                        previousUSPSANumber = profile.uspsaNumber
                    }
                }
                .navigationTitle(isCurrentUser ? "Profile" : (myProfile?.name.isEmpty == false ? myProfile!.name : "USPSA# \(uspsaNumber ?? "")"))
                .navigationBarTitleDisplayMode(isCurrentUser ? .automatic : .inline)
                .toolbar {
                    if isCurrentUser && hasUSPSANumber && createCoachMarks() != nil {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingCoachMarks = true
                            } label: {
                                Image(systemName: "info.circle")
                            }
                        }
                    }
                }
                .onPreferenceChange(FramePreferenceKey.self) { frames in
                    trackedFrames = frames
                }
                .sheet(isPresented: $showingUSPSASettings) {
                    if let profile = myProfile {
                        USPSANumberSheet(
                            profile: profile,
                            isEditable: isCurrentUser,
                            onUnfollow: isCurrentUser ? nil : {
                                showingDeleteConfirmation = true
                            }
                        )
                    }
                }
                .sheet(isPresented: $showingCompare) {
                    if let currentUser = currentUserProfile, let theirProfile = myProfile {
                        CompareProfilesView(
                            myProfile: currentUser,
                            theirProfile: theirProfile
                        )
                    }
                }
                .alert("Sync Error", isPresented: $showingError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
                .alert("Unfollow Shooter", isPresented: $showingDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Unfollow", role: .destructive) {
                        deleteProfile()
                    }
                } message: {
                    if let profile = myProfile {
                        Text("Are you sure you want to unfollow \(profile.name.isEmpty ? "USPSA# \(profile.uspsaNumber)" : profile.name)? This will delete their profile and all saved data.")
                    }
                }
            }

            // Coach marks overlay at the top level
            if showingCoachMarks, let marks = createCoachMarks() {
                CoachMarkOverlay(isPresented: $showingCoachMarks, marks: marks)
            }
        }
    }

    private func deleteProfile() {
        guard let profile = myProfile else { return }

        // Delete the profile (cascade delete will handle match scores and divisions)
        context.delete(profile)

        do {
            try context.save()
            print("✅ Successfully deleted followed profile: \(profile.uspsaNumber)")
            dismiss()
        } catch {
            print("❌ Error deleting profile: \(error)")
            errorMessage = "Failed to delete profile: \(error.localizedDescription)"
            showingError = true
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
            if let benchmark = PeakBenchmarks.get(division: division, stageCode: stage.code) {
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
                    if let benchmark = PeakBenchmarks.get(division: divisionEnum, stageCode: stage.code) {
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
                    if let benchmark = PeakBenchmarks.get(division: divProfile.division, stageCode: stage.code) {
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
                                Text("Compare Performances")
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
    let allScores: [MatchScore]

    @Query private var allMatchScores: [MatchScore]

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
            stageName: stageName(for: stageCode),
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
    let allScores: [MatchScore]
    @Binding var trackedFrames: [String: CGRect]
    @Query private var profiles: [ShooterProfile]
    @State private var selectedDivision: String? = nil

    private var divisions: [String] {
        let uniqueDivisions = Set(allScores.map { $0.divisionCode })
        return uniqueDivisions.sorted()
    }

    private var filteredScores: [MatchScore] {
        if let selected = selectedDivision {
            return allScores.filter { $0.divisionCode == selected }
        }
        return allScores
    }

    // Group scores by date, then by match name
    private var groupedScores: [(date: Date, matchName: String, divisions: [String], scores: [MatchScore])] {
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
                .trackFrame(named: "divisionFilter")
                .onPreferenceChange(FramePreferenceKey.self) { frames in
                    trackedFrames.merge(frames) { _, new in new }
                }

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

                                        Text(stageName(for: score.stageCode))
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

// MARK: - Compare Profiles View

struct CompareProfilesView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var myProfile: ShooterProfile
    @Bindable var theirProfile: ShooterProfile

    // Get divisions that both shooters compete in AND have visible
    private var commonDivisions: [Division] {
        let myVisibleDivisions = Set(myProfile.divisions.filter { $0.isVisible }.map { $0.division })
        let theirVisibleDivisions = Set(theirProfile.divisions.filter { $0.isVisible }.map { $0.division })
        return Array(myVisibleDivisions.intersection(theirVisibleDivisions)).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        NavigationStack {
            if commonDivisions.isEmpty {
                ContentUnavailableView(
                    "No Common Divisions",
                    systemImage: "arrow.triangle.branch",
                    description: Text("You and \(theirProfile.name.isEmpty ? "USPSA# \(theirProfile.uspsaNumber)" : theirProfile.name) don't compete in any common divisions")
                )
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(commonDivisions, id: \.self) { division in
                            VStack(alignment: .leading, spacing: 16) {
                                // Division header
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: "target")
                                            .font(.title)
                                            .foregroundStyle(.blue)

                                        Text(division.rawValue)
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.primary)

                                        Spacer()
                                    }

                                    // Division overall stats
                                    CompareDivisionHeader(
                                        division: division,
                                        myProfile: myProfile,
                                        theirProfile: theirProfile
                                    )
                                }
                                .padding(20)

                                // Individual stage comparisons
                                VStack(spacing: 8) {
                                    ForEach(AllStages) { stage in
                                        CompareStageRow(
                                            stage: stage,
                                            division: division,
                                            myProfile: myProfile,
                                            theirProfile: theirProfile
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct CompareDivisionHeader: View {
    let division: Division
    @Bindable var myProfile: ShooterProfile
    @Bindable var theirProfile: ShooterProfile

    private var myDivision: DivisionProfile? {
        myProfile.divisions.first { $0.division == division }
    }

    private var theirDivision: DivisionProfile? {
        theirProfile.divisions.first { $0.division == division }
    }

    private var myTotalTime: Decimal {
        myProfile.matchScores
            .filter { $0.usedForClassification && $0.divisionCode == division.rawValue }
            .reduce(Decimal(0)) { $0 + $1.time }
    }

    private var theirTotalTime: Decimal {
        theirProfile.matchScores
            .filter { $0.usedForClassification && $0.divisionCode == division.rawValue }
            .reduce(Decimal(0)) { $0 + $1.time }
    }

    var body: some View {
        HStack(spacing: 12) {
            // My stats (left side)
            VStack(spacing: 8) {
                Text("You")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(myDivision?.classification.rawValue ?? "U")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDecimal(myTotalTime) + "s")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .monospacedDigit()

                        Text(formatDecimal(myDivision?.currentPercentage ?? 0) + "%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(16)
            .background(
                (myDivision?.currentPercentage ?? 0) > (theirDivision?.currentPercentage ?? 0) && (myDivision?.currentPercentage ?? 0) > 0 ?
                    Color.green.opacity(0.1) :
                    (myDivision?.currentPercentage ?? 0) < (theirDivision?.currentPercentage ?? 0) && (myDivision?.currentPercentage ?? 0) > 0 ?
                        Color.red.opacity(0.1) :
                        Color(.systemBackground)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        (myDivision?.currentPercentage ?? 0) > (theirDivision?.currentPercentage ?? 0) && (myDivision?.currentPercentage ?? 0) > 0 ? Color.green :
                            (myDivision?.currentPercentage ?? 0) < (theirDivision?.currentPercentage ?? 0) && (myDivision?.currentPercentage ?? 0) > 0 ? Color.red : Color(.systemGray5),
                        lineWidth: 2
                    )
            )

            // Their stats (right side)
            VStack(spacing: 8) {
                Text(theirProfile.name.isEmpty ? "Them" : theirProfile.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(theirDivision?.classification.rawValue ?? "U")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDecimal(theirTotalTime) + "s")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .monospacedDigit()

                        Text(formatDecimal(theirDivision?.currentPercentage ?? 0) + "%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(16)
            .background(
                (theirDivision?.currentPercentage ?? 0) > (myDivision?.currentPercentage ?? 0) && (theirDivision?.currentPercentage ?? 0) > 0 ?
                    Color.green.opacity(0.1) :
                    (theirDivision?.currentPercentage ?? 0) < (myDivision?.currentPercentage ?? 0) && (theirDivision?.currentPercentage ?? 0) > 0 ?
                        Color.red.opacity(0.1) :
                        Color(.systemBackground)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        (theirDivision?.currentPercentage ?? 0) > (myDivision?.currentPercentage ?? 0) && (theirDivision?.currentPercentage ?? 0) > 0 ? Color.green :
                            (theirDivision?.currentPercentage ?? 0) < (myDivision?.currentPercentage ?? 0) && (theirDivision?.currentPercentage ?? 0) > 0 ? Color.red : Color(.systemGray5),
                        lineWidth: 2
                    )
            )
        }
    }

    private func formatDecimal(_ value: Decimal) -> String {
        String(format: "%.2f", NSDecimalNumber(decimal: value).doubleValue)
    }

    private func timeColor(mine: Decimal, theirs: Decimal) -> Color {
        if mine == 0 || theirs == 0 { return .primary }
        return mine < theirs ? .green : (mine > theirs ? .red : .primary)
    }

    private func percentageColor(mine: Decimal?, theirs: Decimal?) -> Color {
        guard let mine = mine, let theirs = theirs else { return .primary }
        if mine == 0 || theirs == 0 { return .primary }
        return mine > theirs ? .green : (mine < theirs ? .red : .primary)
    }
}

private struct CompareStageRow: View {
    let stage: Stage
    let division: Division
    @Bindable var myProfile: ShooterProfile
    @Bindable var theirProfile: ShooterProfile

    private var myScore: MatchScore? {
        myProfile.matchScores
            .filter { $0.usedForClassification && $0.divisionCode == division.rawValue && $0.stageCode == stage.code }
            .first
    }

    private var theirScore: MatchScore? {
        theirProfile.matchScores
            .filter { $0.usedForClassification && $0.divisionCode == division.rawValue && $0.stageCode == stage.code }
            .first
    }

    private var myPercentage: Decimal {
        guard let score = myScore, score.peakTime > 0 else { return 0 }
        return (score.peakTime / score.time) * 100
    }

    private var theirPercentage: Decimal {
        guard let score = theirScore, score.peakTime > 0 else { return 0 }
        return (score.peakTime / score.time) * 100
    }

    private var myClass: ShooterClass {
        ShooterClass.shooterClass(percentage: myPercentage)
    }

    private var theirClass: ShooterClass {
        ShooterClass.shooterClass(percentage: theirPercentage)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stage name header
            HStack(spacing: 8) {
                Text(stage.code)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.gradient)
                    .cornerRadius(6)

                Text(stage.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6).opacity(0.5))

            // Scores comparison
            HStack(spacing: 0) {
                // My score
                if let score = myScore {
                    HStack(spacing: 12) {
                        Text(myClass.rawValue)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(percentageColor(mine: myPercentage, theirs: theirPercentage))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: 50)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatDecimal(score.time) + "s")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .monospacedDigit()

                            Text("\(formatDecimal(myPercentage))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No Score")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Divider
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(width: 1)
                    .padding(.vertical, 8)

                // Their score
                if let score = theirScore {
                    HStack(spacing: 12) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatDecimal(score.time) + "s")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .monospacedDigit()

                            Text("\(formatDecimal(theirPercentage))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }

                        Text(theirClass.rawValue)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(percentageColor(mine: theirPercentage, theirs: myPercentage))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: 50)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Text("No Score")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            // Visual performance bar - full width proportional
            if myScore != nil || theirScore != nil {
                GeometryReader { geometry in
                    let myPct = NSDecimalNumber(decimal: myPercentage).doubleValue
                    let theirPct = NSDecimalNumber(decimal: theirPercentage).doubleValue
                    let total = myPct + theirPct

                    // Calculate proportional widths (stretches full width)
                    let myWidth = total > 0 ? (myPct / total) * geometry.size.width : geometry.size.width / 2

                    HStack(spacing: 0) {
                        // My portion (left side)
                        if myScore != nil {
                            Rectangle()
                                .fill(
                                    myPercentage > theirPercentage ?
                                        Color.green :
                                        Color.red
                                )
                                .frame(width: myWidth)
                        }

                        // Their portion (right side)
                        if theirScore != nil {
                            Rectangle()
                                .fill(
                                    theirPercentage > myPercentage ?
                                        Color.green :
                                        Color.red
                                )
                        }
                    }
                }
                .frame(height: 8)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func formatDecimal(_ value: Decimal) -> String {
        String(format: "%.2f", NSDecimalNumber(decimal: value).doubleValue)
    }

    private func timeColor(mine: Decimal?, theirs: Decimal?) -> Color {
        guard let mine = mine, let theirs = theirs else { return .primary }
        return mine < theirs ? .green : (mine > theirs ? .red : .primary)
    }

    private func percentageColor(mine: Decimal, theirs: Decimal) -> Color {
        if mine == 0 || theirs == 0 { return .primary }
        return mine > theirs ? .green : (mine < theirs ? .red : .primary)
    }
}
