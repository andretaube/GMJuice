//
//  FollowingView.swift
//  GMJuice
//
//  Created by Claude on 11/7/25.
//

import SwiftUI
import SwiftData

struct FollowingView: View {
    @Environment(\.modelContext) private var context
    @Query private var allProfiles: [ShooterProfile]
    @StateObject private var scraper = SCWebScraper.shared

    @State private var showingAddSheet = false
    @State private var newUSPSANumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingCoachMarks = false
    @AppStorage("hasSeenFollowingCoachMarks") private var hasSeenCoachMarks = false

    private var currentUserNumber: String? {
        UserDefaults.standard.currentUserUSPSANumber
    }

    var body: some View {
        NavigationStack {
            VStack {
                if followedProfiles.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(followedProfiles, id: \.uspsaNumber) { profile in
                                NavigationLink(destination: ProfileView(uspsaNumber: profile.uspsaNumber)) {
                                    FollowedShooterCard(profile: profile)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteProfile(profile)
                                    } label: {
                                        Label("Unfollow", systemImage: "person.fill.xmark")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("Following")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCoachMarks = true
                    }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddShooterSheet(
                    newUSPSANumber: $newUSPSANumber,
                    isLoading: $isLoading,
                    onAdd: addShooter
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay {
                if showingCoachMarks, let marks = createCoachMarks() {
                    CoachMarkOverlay(isPresented: $showingCoachMarks, marks: marks)
                }
            }
        }
    }

    private func createCoachMarks() -> [CoachMark]? {
        return [
            CoachMark(
                title: "Following Other Shooters",
                message: "Tap the + button in the top-left to add other shooters by their SCSA member number. Once added, you can tap on their profile card to view their shooter info and compare their scores with yours.",
                highlightFrame: .zero,
                calloutPosition: .bottom
            )
        ]
    }

    private var followedProfiles: [ShooterProfile] {
        // All profiles except the current user's profile
        // Also filter out empty USPSA numbers (uninitialized profiles)
        allProfiles.filter { profile in
            // Skip empty profiles
            guard !profile.uspsaNumber.isEmpty else { return false }

            // Skip current user's profile
            if let currentUser = currentUserNumber {
                return profile.uspsaNumber != currentUser
            }

            // If no current user set, show all non-empty profiles
            return true
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue.gradient)
            }

            VStack(spacing: 8) {
                Text("No Shooters Followed")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Follow other shooters to track their progress and compare your performance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: { showingAddSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Add Shooter")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.blue.gradient)
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    private func addShooter() {
        guard !newUSPSANumber.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        let trimmedNumber = newUSPSANumber.trimmingCharacters(in: .whitespaces)

        // Check if already following (profile already exists)
        if allProfiles.contains(where: { $0.uspsaNumber == trimmedNumber }) {
            errorMessage = "You're already following this shooter"
            showingError = true
            return
        }

        // Check if it's the current user
        if trimmedNumber == currentUserNumber {
            errorMessage = "You can't follow yourself"
            showingError = true
            return
        }

        isLoading = true

        Task {
            do {
                // Check if SCSA data is enabled via Remote Config
                guard RemoteConfigService.shared.isSCSADataEnabled else {
                    await MainActor.run {
                        errorMessage = "SCSA data import is currently disabled"
                        showingError = true
                        isLoading = false
                    }
                    return
                }
                
                print("🔍 Fetching data for: \(trimmedNumber)")
                // Fetch the shooter's data - this will create the ShooterProfile
                try await scraper.syncClassificationData(memberNumber: trimmedNumber, context: context)

                await MainActor.run {
                    print("✅ Successfully added shooter: \(trimmedNumber)")
                    // Reset form
                    newUSPSANumber = ""
                    isLoading = false
                    showingAddSheet = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Error fetching shooter data: \(error)")
                    errorMessage = "Failed to fetch shooter data: \(error.localizedDescription)"
                    showingError = true
                    isLoading = false
                }
            }
        }
    }

    private func deleteProfile(_ profile: ShooterProfile) {
        print("🗑️ Deleting shooter profile: \(profile.uspsaNumber)")

        // Delete the profile and all its associated data (match scores will cascade delete)
        context.delete(profile)

        // Save the context
        do {
            try context.save()
            print("✅ Successfully deleted shooter: \(profile.uspsaNumber)")
        } catch {
            print("❌ Error deleting shooter: \(error)")
        }
    }
}

// MARK: - Followed Shooter Card

private struct FollowedShooterCard: View {
    let profile: ShooterProfile
    @Environment(\.modelContext) private var context

    private var visibleDivisions: [DivisionProfile] {
        // Safely access divisions with error recovery
        return ProfileErrorRecovery.safelyAccessProfile(
            context: context,
            profileNumber: profile.uspsaNumber,
            autoRecover: true
        ) {
            profile.divisions.filter { $0.isVisible && $0.classification != .U }
                .sorted { $0.division.rawValue < $1.division.rawValue }
        } ?? []
    }

    private var hiddenDivisionsCount: Int {
        // Count divisions that are hidden (not visible but have a classification)
        return ProfileErrorRecovery.safelyAccessProfile(
            context: context,
            profileNumber: profile.uspsaNumber,
            autoRecover: true
        ) {
            profile.divisions.filter { !$0.isVisible && $0.classification != .U }.count
        } ?? 0
    }

    private var displayName: String {
        if !profile.name.isEmpty {
            return profile.name
        }
        return profile.uspsaNumber
    }

    private func classificationColor(for classification: ShooterClass) -> Color {
        switch classification {
        case .GM: return .purple
        case .M: return .red
        case .A: return .orange
        case .B: return .green
        case .C: return .blue
        case .D: return .cyan
        case .U: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and name
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.gradient)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(profile.uspsaNumber)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }

            // Classification badges
            if !visibleDivisions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(hiddenDivisionsCount > 0 ? "Classifications (\(hiddenDivisionsCount) hidden)" : "Classifications")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(visibleDivisions, id: \.division) { divProfile in
                            HStack(spacing: 6) {
                                Text(divProfile.division.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(divProfile.classification.rawValue)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(classificationColor(for: divProfile.classification).gradient)
                                    .cornerRadius(6)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
            } else {
                Text("No visible classifications")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

// MARK: - Add Shooter Sheet

private struct AddShooterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var newUSPSANumber: String
    @Binding var isLoading: Bool
    let onAdd: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("SCSA Member Number", text: $newUSPSANumber)
                        .textContentType(.username)
                        .autocapitalization(.allCharacters)
                        .disabled(isLoading)
                } header: {
                    Text("Shooter Information")
                } footer: {
                    Text("Enter the SCSA member number of the shooter you want to follow")
                }
            }
            .navigationTitle("Add Shooter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Add") {
                            onAdd()
                        }
                        .disabled(newUSPSANumber.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
}

// MARK: - Followed Shooter Profile View

struct FollowedShooterProfileView: View {
    let profile: ShooterProfile
    @Environment(\.modelContext) private var context
    @StateObject private var scraper = SCWebScraper.shared

    @State private var selectedTab = 0
    @State private var isRefreshing = false
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var showingUSPSAInfo = false

    private var shooterScores: [MatchScore] {
        profile.matchScores.sorted { $0.scoreDate > $1.scoreDate }
    }

    private var classificationScoresByDivision: [(division: String, totalTime: Decimal, totalPeakTime: Decimal, classification: String, percentage: Decimal, highPercentage: Decimal?, classificationDate: Date?, stages: [(stageCode: String, stageName: String, scores: [MatchScore])])] {
        let usedScores = shooterScores.filter { $0.usedForClassification }
        let byDivision = Dictionary(grouping: usedScores) { $0.divisionCode }

        var allDivisions: [(division: String, totalTime: Decimal, totalPeakTime: Decimal, classification: String, percentage: Decimal, highPercentage: Decimal?, classificationDate: Date?, stages: [(stageCode: String, stageName: String, scores: [MatchScore])])] = []

        for (division, scores) in byDivision {
            let totalTime = scores.reduce(Decimal(0)) { $0 + $1.time }
            let byStage = Dictionary(grouping: scores) { $0.stageCode }
            let stages = byStage.map { (stageCode: $0.key, stageName: stageName(for: $0.key), scores: $0.value.sorted { $0.scoreDate > $1.scoreDate }) }
                .sorted { $0.stageCode < $1.stageCode }

            let divProfile = profile.divisions.first { $0.division.rawValue == division }
            let classification = divProfile?.classification.rawValue.uppercased() ?? "U"
            let percentage = divProfile?.currentPercentage ?? 0
            let highPercentage = divProfile?.highPercentage
            let classificationDate = divProfile?.classificationDate

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

        for divProfile in profile.divisions where divProfile.classification != .U {
            let divisionCode = divProfile.division.rawValue
            if !allDivisions.contains(where: { $0.division == divisionCode }) {
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
        VStack(spacing: 0) {
            // Tab picker
            Picker("View", selection: $selectedTab) {
                Text("Profile").tag(0)
                Text("Match Scores").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if selectedTab == 0 {
                // Profile view
                if classificationScoresByDivision.isEmpty {
                    ContentUnavailableView {
                        Label("No Classification Data", systemImage: "person.circle")
                    } description: {
                        Text("No classification scores found for this shooter")
                    }
                } else {
                    List {
                        // Shooter Info Header
                        Section {
                            Button {
                                showingUSPSAInfo = true
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
                        }

                        // Division sections
                        ForEach(Array(classificationScoresByDivision.enumerated()), id: \.element.division) { index, divisionGroup in
                            FollowedShooterDivisionSection(
                                divisionGroup: divisionGroup,
                                allScores: shooterScores
                            )
                        }
                    }
                }
            } else {
                // Match Scores view
                FollowedShooterScoresView(allScores: shooterScores, profile: profile)
            }
        }
        .navigationTitle(profile.name.isEmpty ? profile.uspsaNumber : profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshProfile) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingUSPSAInfo) {
            USPSANumberSheet(profile: profile, isEditable: false)
        }
        .onAppear {
            checkAndAutoRefresh()
        }
    }

    private func checkAndAutoRefresh() {
        // Only auto-refresh if last sync was more than 24 hours ago
        guard let lastSync = profile.lastSyncDate else {
            // Never synced, refresh now
            print("📱 Auto-refreshing followed profile (never synced): \(profile.uspsaNumber)")
            refreshProfile()
            return
        }

        let hoursSinceLastSync = Date().timeIntervalSince(lastSync) / 3600
        if hoursSinceLastSync >= 24 {
            print("📱 Auto-refreshing followed profile (last synced \(String(format: "%.1f", hoursSinceLastSync)) hours ago): \(profile.uspsaNumber)")
            refreshProfile()
        } else {
            print("⏭️ Skipping auto-refresh for followed profile (last synced \(String(format: "%.1f", hoursSinceLastSync)) hours ago): \(profile.uspsaNumber)")
        }
    }

    private func refreshProfile() {
        isRefreshing = true


        Task {
            do {
                // Check if SCSA data is enabled via Remote Config
                guard RemoteConfigService.shared.isSCSADataEnabled else {
                    await MainActor.run {
                        errorMessage = "SCSA data refresh is currently disabled"
                        showingError = true
                        isRefreshing = false
                        
                    }
                    return
                }
                
                print("🔄 Refreshing profile for: \(profile.uspsaNumber)")
                try await scraper.syncClassificationData(memberNumber: profile.uspsaNumber, context: context)

                await MainActor.run {
                    print("✅ Successfully refreshed profile: \(profile.uspsaNumber)")
                    isRefreshing = false
                    
                }
            } catch {
                await MainActor.run {
                    print("❌ Error refreshing profile: \(error)")
                    errorMessage = "Failed to refresh profile: \(error.localizedDescription)"
                    showingError = true
                    isRefreshing = false
                    
                }
            }
        }
    }
}

// MARK: - Followed Shooter Division Section

private struct FollowedShooterDivisionSection: View {
    let divisionGroup: (division: String, totalTime: Decimal, totalPeakTime: Decimal, classification: String, percentage: Decimal, highPercentage: Decimal?, classificationDate: Date?, stages: [(stageCode: String, stageName: String, scores: [MatchScore])])
    let allScores: [MatchScore]

    @State private var isExpanded = false

    var body: some View {
        Section {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
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

                    if divisionGroup.totalTime == 0 {
                        Text("No recent classification scores")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(divisionGroup.stages, id: \.stageCode) { stage in
                    ForEach(stage.scores, id: \.id) { score in
                        FollowedShooterStageScoreRow(score: score)
                    }
                }
            }
        }
    }
}

// MARK: - Followed Shooter Stage Score Row

private struct FollowedShooterStageScoreRow: View {
    let score: MatchScore

    var body: some View {
        let percentage = score.peakTime > 0 ? (score.peakTime / score.time) * 100 : 0
        let percentageValue = NSDecimalNumber(decimal: percentage).doubleValue
        let stageClass = ShooterClass.shooterClass(percentage: percentage)

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(score.stageCode)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(stageName(for: score.stageCode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 8) {
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

                Text("\(percentageValue, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Followed Shooter Scores View

private struct FollowedShooterScoresView: View {
    let allScores: [MatchScore]
    let profile: ShooterProfile
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

    private var groupedScores: [(date: Date, matchName: String, divisions: [String], scores: [MatchScore])] {
        let calendar = Calendar.current
        let byDate = Dictionary(grouping: filteredScores) { score in
            calendar.startOfDay(for: score.scoreDate)
        }

        return byDate.map { date, scores in
            let matchName = scores.first?.matchName ?? ""
            let divisions = Array(Set(scores.map { $0.divisionCode })).sorted()
            let sortedScores = scores.sorted { $0.stageCode < $1.stageCode }
            return (date: date, matchName: matchName, divisions: divisions, scores: sortedScores)
        }
        .sorted { $0.date > $1.date }
    }

    private func getShooterClassification(for divisionCode: String) -> ShooterClass {
        guard let divProfile = profile.divisions.first(where: { $0.division.rawValue == divisionCode }) else {
            return .U
        }
        return divProfile.classification
    }

    var body: some View {
        if allScores.isEmpty {
            ContentUnavailableView {
                Label("No Match Scores", systemImage: "list.bullet")
            } description: {
                Text("No match scores found for this shooter")
            }
        } else {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
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

                List {
                    ForEach(groupedScores, id: \.date) { group in
                        Section {
                            ForEach(group.scores, id: \.id) { score in
                                let percentage = score.peakTime > 0 ? (score.peakTime / score.time) * 100 : 0
                                let percentageValue = NSDecimalNumber(decimal: percentage).doubleValue
                                let scoreClass = ShooterClass.shooterClass(percentage: percentage)
                                let shooterClass = getShooterClassification(for: score.divisionCode)

                                let textColor: Color = {
                                    if percentage >= 100 {
                                        return .green
                                    } else if scoreClass > shooterClass {
                                        return .green
                                    } else if scoreClass == shooterClass {
                                        return .blue
                                    } else {
                                        return .red
                                    }
                                }()

                                HStack(alignment: .top, spacing: 12) {
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
