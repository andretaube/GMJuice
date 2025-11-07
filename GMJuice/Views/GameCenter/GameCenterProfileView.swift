//
//  GameCenterProfileView.swift
//  GMJuice
//
//  Created by Claude on 11/6/25.
//

import SwiftUI
import GameKit
import SwiftData

struct GameCenterProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var gameCenterManager: GameCenterManager
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Query(sort: \TrackedShooter.dateAdded, order: .reverse) private var trackedShooters: [TrackedShooter]
    @State private var friendAvatars: [String: UIImage] = [:]
    @State private var selectedFriendID: String?
    @State private var selectedTrackedShooter: TrackedShooter?
    @State private var showingGameCenterDashboard = false
    @State private var showingAddShooter = false
    @State private var isRefreshing = false

    private var selectedFriend: GKPlayer? {
        guard let id = selectedFriendID else { return nil }
        return gameCenterManager.friends.first(where: { $0.gamePlayerID == id })
    }

    private func refreshFriends() async {
        isRefreshing = true
        await gameCenterManager.loadFriends()
        isRefreshing = false
    }

    var body: some View {
        NavigationStack {
            List {
                // Local player section
                if let player = gameCenterManager.localPlayer {
                    Section {
                        HStack(spacing: 16) {
                            if let avatar = gameCenterManager.playerAvatar {
                                Image(uiImage: avatar)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.gray)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.displayName)
                                    .font(.headline)

                                if !player.alias.isEmpty {
                                    Text("@\(player.alias)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 8) {
                                    Text("Connected")
                                        .font(.caption)
                                        .foregroundStyle(.green)

                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 4) {
                                        Image(systemName: "person.2.fill")
                                        Text("Shared with Friends")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Friends list
                Section {
                    if isRefreshing {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Loading friends...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 32)
                            Spacer()
                        }
                    } else if gameCenterManager.friends.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)

                            Text("No Friends Yet")
                                .font(.headline)

                            Text("Tap 'Add Friends in GameCenter' below to send friend requests")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Text("Note: Both you and your friend must have accepted each other's friend requests on GameCenter for them to appear here")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        ForEach(gameCenterManager.friends, id: \.gamePlayerID) { friend in
                            Button {
                                selectedFriendID = friend.gamePlayerID
                            } label: {
                                HStack(spacing: 12) {
                                    if let avatar = friendAvatars[friend.gamePlayerID] {
                                        Image(uiImage: avatar)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.gray)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friend.displayName)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        if !friend.alias.isEmpty {
                                            Text("@\(friend.alias)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .task {
                                // Load avatar for this friend
                                if friendAvatars[friend.gamePlayerID] == nil {
                                    if let avatar = await gameCenterManager.loadAvatar(for: friend) {
                                        friendAvatars[friend.gamePlayerID] = avatar
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Friends (\(gameCenterManager.friends.count))")
                        Spacer()
                        Button {
                            showingGameCenterDashboard = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .foregroundStyle(.blue)
                        }
                    }
                } footer: {
                    Text("Tap + to add friends in GameCenter. Friends must also use GMJuice to appear in comparisons")
                }

                // Tracked Shooters
                Section {
                    if trackedShooters.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)

                            Text("No Tracked Shooters")
                                .font(.headline)

                            Text("Manually add shooters to compare performance")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        ForEach(trackedShooters) { shooter in
                            Button {
                                selectedTrackedShooter = shooter
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.orange)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(shooter.displayName)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        Text("USPSA: \(shooter.uspsaNumber)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    context.delete(shooter)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Tracked Shooters (\(trackedShooters.count))")
                        Spacer()
                        Button {
                            showingAddShooter = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                } footer: {
                    Text("Add competitors or training partners to compare their official SCSA match scores with yours")
                }
            }
            .refreshable {
                await refreshFriends()
            }
            .navigationTitle("GameCenter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Refresh friends when view appears
                Task {
                    await refreshFriends()
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedFriend != nil },
                set: { if !$0 { selectedFriendID = nil } }
            )) {
                if let friend = selectedFriend {
                    FriendComparisonView(friend: friend)
                }
            }
            .sheet(isPresented: $showingGameCenterDashboard) {
                GameCenterDashboard()
            }
            .sheet(isPresented: $showingAddShooter) {
                AddTrackedShooterView(context: context)
            }
            .sheet(isPresented: Binding(
                get: { selectedTrackedShooter != nil },
                set: { if !$0 { selectedTrackedShooter = nil } }
            )) {
                if let shooter = selectedTrackedShooter {
                    TrackedShooterComparisonView(shooter: shooter)
                }
            }
            .onChange(of: showingGameCenterDashboard) { wasShowing, isShowing in
                // Refresh friends when returning from GameCenter dashboard
                if wasShowing && !isShowing {
                    Task {
                        await refreshFriends()
                    }
                }
            }
        }
    }
}

// MARK: - GameCenter Dashboard

struct GameCenterDashboard: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let viewController = GKGameCenterViewController(state: .dashboard)
        viewController.gameCenterDelegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            dismiss()
        }
    }
}

// MARK: - Add Tracked Shooter View

struct AddTrackedShooterView: View {
    @Environment(\.dismiss) private var dismiss
    let context: ModelContext

    @State private var uspsaNumber: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @StateObject private var scraper = SCWebScraper.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("USPSA Number", text: $uspsaNumber)
                        .textContentType(.username)
                        .autocapitalization(.allCharacters)
                        .font(.body)
                        .disabled(isLoading)
                } header: {
                    Text("Shooter Information")
                } footer: {
                    Text("Enter the shooter's USPSA member number. Their name will be fetched from the SCSA website.")
                }

                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("Looking up shooter...")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                            Spacer()
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Shooter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            await addShooter()
                        }
                    }
                    .disabled(uspsaNumber.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
        }
    }

    private func addShooter() async {
        let trimmedNumber = uspsaNumber.trimmingCharacters(in: .whitespaces).uppercased()

        // Check if already tracking this shooter
        let descriptor = FetchDescriptor<TrackedShooter>(
            predicate: #Predicate { $0.uspsaNumber == trimmedNumber }
        )

        if let existing = try? context.fetch(descriptor).first {
            errorMessage = "Already tracking \(existing.displayName)"
            return
        }

        // Fetch member name from SCSA website
        isLoading = true
        errorMessage = nil

        do {
            // Fetch member info (name only, no database save)
            let memberInfo = try await scraper.fetchMemberInfo(memberNumber: trimmedNumber)

            print("👤 Found shooter: \(memberInfo.name)")

            // Add new tracked shooter
            let shooter = TrackedShooter(uspsaNumber: trimmedNumber, displayName: memberInfo.name)
            context.insert(shooter)

            try context.save()
            isLoading = false
            dismiss()

        } catch {
            errorMessage = "Could not find member number. Please check and try again."
            isLoading = false
        }
    }
}

// MARK: - Tracked Shooter Comparison View

struct TrackedShooterComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Query private var profiles: [ShooterProfile]
    @Query private var myScores: [SCMatchScore]
    @StateObject private var scraper = SCWebScraper.shared

    let shooter: TrackedShooter

    @State private var friendProfile: FriendPerformance?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var myProfile: ShooterProfile? {
        profiles.first
    }

    private var navigationTitle: String {
        if let myName = myProfile?.uspsaNumber, !myName.isEmpty {
            return "Me - \(shooter.displayName)"
        }
        return shooter.displayName
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading \(shooter.displayName)'s profile...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)

                        Text("Unable to Load Profile")
                            .font(.headline)

                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if let friendProfile = friendProfile {
                    comparisonView(friendProfile: friendProfile)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.circle")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)

                        Text("Ready to Load")
                            .font(.headline)

                        Text("Tap 'Load Data' to fetch \(shooter.displayName)'s official SCSA match scores")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                // Auto-load on appear
                await loadShooterProfile()
            }
        }
    }

    private func divisionsToShow(myProfile: ShooterProfile, friendProfile: FriendPerformance) -> [(division: Division, myDiv: DivisionProfile, friendDiv: FriendPerformance.DivisionPerformance)] {
        var result: [(division: Division, myDiv: DivisionProfile, friendDiv: FriendPerformance.DivisionPerformance)] = []

        // Only show divisions where both have data
        for division in Division.allCases {
            if let myDiv = myProfile.divisions.first(where: { $0.division == division && $0.currentPercentage != nil }),
               let friendDiv = friendProfile.divisions.first(where: { $0.divisionCode == division.rawValue }) {
                result.append((division: division, myDiv: myDiv, friendDiv: friendDiv))
            }
        }

        return result
    }

    @ViewBuilder
    private func comparisonView(friendProfile: FriendPerformance) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overall comparison
                if let myProfile = myProfile {
                    ForEach(divisionsToShow(myProfile: myProfile, friendProfile: friendProfile), id: \.division) { item in
                        VStack(spacing: 12) {
                            // Division header
                            DivisionComparisonCard(
                                division: item.division,
                                myClassification: item.myDiv.classification,
                                myPercentage: item.myDiv.currentPercentage!,
                                friendName: shooter.displayName,
                                friendClassification: ShooterClass(rawValue: item.friendDiv.classification) ?? .U,
                                friendPercentage: item.friendDiv.currentPercentage
                            )

                            // Stage-by-stage comparison
                            ForEach(AllStages.filter { $0.code.hasPrefix("SC-") }, id: \.code) { stage in
                                if let myScore = myScores.first(where: { $0.stageCode == stage.code && $0.divisionCode == item.division.rawValue && $0.usedForClassification }),
                                   let friendScore = friendProfile.classificationScores.first(where: { $0.stageCode == stage.code && $0.divisionCode == item.division.rawValue }) {

                                    StageComparisonRow(
                                        stageCode: stage.code,
                                        stageName: stage.name,
                                        myClassification: item.myDiv.classification,
                                        myTime: myScore.time,
                                        myPercentage: myScore.peakTime > 0 ? (myScore.peakTime / myScore.time) * 100 : 0,
                                        friendClassification: ShooterClass(rawValue: item.friendDiv.classification) ?? .U,
                                        friendTime: friendScore.time,
                                        friendPercentage: friendScore.peakTime > 0 ? (friendScore.peakTime / friendScore.time) * 100 : 0
                                    )
                                }
                            }
                        }
                    }
                }

                if let lastUpdated = friendProfile.lastUpdated {
                    Text("Last updated: \(lastUpdated, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    private func loadShooterProfile() async {
        print("🔄 Loading tracked shooter profile for: \(shooter.displayName)")

        isLoading = true
        errorMessage = nil

        do {
            // First try CloudKit (they might have synced their profile)
            do {
                let profile = try await cloudKitManager.fetchFriendProfile(memberNumber: shooter.uspsaNumber)
                friendProfile = profile
                print("✅ Loaded from CloudKit!")
                isLoading = false
                return
            } catch {
                print("⚠️ Not in CloudKit, will scrape SCSA website")
            }

            // If not in CloudKit, scrape SCSA website
            let scrapedProfile = try await scrapeShooterData()
            friendProfile = scrapedProfile
            print("✅ Scraped from SCSA website!")

        } catch {
            print("❌ Failed to load: \(error.localizedDescription)")
            errorMessage = "Could not load \(shooter.displayName)'s profile. Make sure their USPSA number is correct and they have classification scores on the SCSA website."
        }

        isLoading = false
    }

    private func scrapeShooterData() async throws -> FriendPerformance {
        // Use SCWebScraper to fetch classification data from SCSA website
        // This will throw if the member number is invalid or no data exists

        // Create a temporary ModelContext to scrape into
        // Use in-memory store with CloudKit disabled
        let schema = Schema(versionedSchema: Schema004.self)
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let context = ModelContext(container)

        // Scrape the data
        try await scraper.syncClassificationData(memberNumber: shooter.uspsaNumber, context: context)

        // Fetch the scraped scores
        let memberNumber = shooter.uspsaNumber
        let descriptor = FetchDescriptor<SCMatchScore>(
            predicate: #Predicate { $0.memberNumber == memberNumber && $0.usedForClassification == true },
            sortBy: [SortDescriptor(\SCMatchScore.scoreDate, order: .reverse)]
        )

        let scores = try context.fetch(descriptor)

        if scores.isEmpty {
            throw NSError(domain: "TrackedShooter", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No classification scores found for this shooter"
            ])
        }

        // Convert to FriendPerformance format
        var divisionPerformances: [FriendPerformance.DivisionPerformance] = []
        var stageScores: [FriendPerformance.StageScore] = []

        // Group by division and calculate percentages
        let divisionGroups = Dictionary(grouping: scores) { $0.divisionCode }

        for (divCode, divScores) in divisionGroups {
            // Calculate current percentage for this division
            let totalTime = divScores.reduce(Decimal(0)) { $0 + $1.time }
            let totalPeakTime = divScores.reduce(Decimal(0)) { $0 + $1.peakTime }
            let percentage: Decimal = totalPeakTime > 0 ? (totalPeakTime / totalTime) * 100 : 0

            divisionPerformances.append(FriendPerformance.DivisionPerformance(
                divisionCode: divCode,
                classification: ShooterClass.shooterClass(percentage: percentage).rawValue,
                currentPercentage: percentage,
                highPercentage: percentage
            ))

            // Add stage scores
            for score in divScores {
                stageScores.append(FriendPerformance.StageScore(
                    stageCode: score.stageCode,
                    stageName: score.stageName,
                    divisionCode: score.divisionCode,
                    time: score.time,
                    peakTime: score.peakTime,
                    matchName: score.matchName,
                    scoreDate: score.scoreDate
                ))
            }
        }

        return FriendPerformance(
            memberNumber: shooter.uspsaNumber,
            divisions: divisionPerformances,
            classificationScores: stageScores,
            lastUpdated: Date()
        )
    }
}

// Re-use the DivisionComparisonCard from FriendComparisonView
private struct DivisionComparisonCard: View {
    let division: Division
    let myClassification: ShooterClass
    let myPercentage: Decimal
    let friendName: String
    let friendClassification: ShooterClass
    let friendPercentage: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(division.rawValue)
                .font(.headline)

            HStack(spacing: 24) {
                // My stats
                VStack(alignment: .leading, spacing: 4) {
                    Text("You")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(myClassification.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)

                        Text("\(NSDecimalNumber(decimal: myPercentage).doubleValue, specifier: "%.2f")%")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Friend's stats
                VStack(alignment: .trailing, spacing: 4) {
                    Text(friendName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text("\(NSDecimalNumber(decimal: friendPercentage).doubleValue, specifier: "%.2f")%")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Text(friendClassification.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Comparison bar
            ComparisonBar(
                myPercentage: NSDecimalNumber(decimal: myPercentage).doubleValue,
                friendPercentage: NSDecimalNumber(decimal: friendPercentage).doubleValue
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct ComparisonBar: View {
    let myPercentage: Double
    let friendPercentage: Double

    private var total: Double {
        myPercentage + friendPercentage
    }

    private var myRatio: Double {
        total > 0 ? myPercentage / total : 0.5
    }

    private var myColor: Color {
        myPercentage >= friendPercentage ? .green : .red
    }

    private var friendColor: Color {
        friendPercentage >= myPercentage ? .green : .red
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(myColor.opacity(0.7))
                    .frame(width: geometry.size.width * myRatio)

                Rectangle()
                    .fill(friendColor.opacity(0.7))
            }
        }
        .frame(height: 8)
        .cornerRadius(4)
    }
}

// MARK: - Stage Comparison Row

private struct StageComparisonRow: View {
    let stageCode: String
    let stageName: String
    let myClassification: ShooterClass
    let myTime: Decimal
    let myPercentage: Decimal
    let friendClassification: ShooterClass
    let friendTime: Decimal
    let friendPercentage: Decimal

    private var myPct: Double {
        NSDecimalNumber(decimal: myPercentage).doubleValue
    }

    private var friendPct: Double {
        NSDecimalNumber(decimal: friendPercentage).doubleValue
    }

    private var myColor: Color {
        myPct >= friendPct ? .green : .red
    }

    private var friendColor: Color {
        friendPct >= myPct ? .green : .red
    }

    var body: some View {
        VStack(spacing: 8) {
            // Stage code - name at top center
            Text("\(stageCode) - \(stageName)")
                .font(.subheadline)
                .fontWeight(.medium)

            // Shooter stats side by side
            HStack(spacing: 12) {
                // My stats
                VStack(alignment: .leading, spacing: 4) {
                    Text(myClassification.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(myColor)

                    Text("\(NSDecimalNumber(decimal: myTime).doubleValue, specifier: "%.2f")s")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(myPct, specifier: "%.2f")%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Comparison bar
                StageComparisonBar(
                    myPercentage: myPct,
                    friendPercentage: friendPct
                )
                .frame(height: 8)

                // Friend's stats
                VStack(alignment: .trailing, spacing: 4) {
                    Text(friendClassification.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(friendColor)

                    Text("\(NSDecimalNumber(decimal: friendTime).doubleValue, specifier: "%.2f")s")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(friendPct, specifier: "%.2f")%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Stage Comparison Bar (no gap)

private struct StageComparisonBar: View {
    let myPercentage: Double
    let friendPercentage: Double

    private var total: Double {
        myPercentage + friendPercentage
    }

    private var myRatio: Double {
        total > 0 ? myPercentage / total : 0.5
    }

    private var myColor: Color {
        myPercentage >= friendPercentage ? .green : .red
    }

    private var friendColor: Color {
        friendPercentage >= myPercentage ? .green : .red
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(myColor.opacity(0.7))
                    .frame(width: geometry.size.width * myRatio)

                Rectangle()
                    .fill(friendColor.opacity(0.7))
            }
        }
        .cornerRadius(4)
    }
}
