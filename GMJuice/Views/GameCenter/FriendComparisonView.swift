//
//  FriendComparisonView.swift
//  GMJuice
//
//  Created by Claude on 11/6/25.
//

import SwiftUI
import GameKit
import SwiftData

struct FriendComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Query private var profiles: [ShooterProfile]
    @Query private var myScores: [SCMatchScore]

    let friend: GKPlayer

    @State private var friendProfile: FriendPerformance?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var myProfile: ShooterProfile? {
        profiles.first
    }

    private var navigationTitle: String {
        if let myName = myProfile?.uspsaNumber, !myName.isEmpty {
            return "Me - \(friend.displayName)"
        }
        return friend.displayName
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading friend's profile...")
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
                        Image(systemName: "person.crop.circle.badge.clock")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("Profile Not Available")
                            .font(.headline)

                        Text("\(friend.displayName) hasn't synced their USPSA profile to GMJuice yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("Check back later once they've added their USPSA number.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Auto-fetch friend's profile by GameCenter ID
                await autoLoadFriendProfile()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
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
                                friendName: friend.displayName,
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

    private func autoLoadFriendProfile() async {
        print("🔄 Auto-loading friend profile for: \(friend.displayName)")

        isLoading = true
        errorMessage = nil

        do {
            // Try to fetch by GameCenter ID
            let profile = try await cloudKitManager.fetchFriendProfileByGameCenter(gamePlayerID: friend.gamePlayerID)
            friendProfile = profile
            print("✅ Auto-loaded friend's profile!")
        } catch {
            print("⚠️ Could not auto-load: \(error.localizedDescription)")
            // Don't set error - just show "Profile Not Available" message
            errorMessage = nil
        }

        isLoading = false
    }
}

// MARK: - Division Comparison Card

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
                            .foregroundStyle(.green)
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
