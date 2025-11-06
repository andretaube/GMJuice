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
    @State private var friendMemberNumber: String = ""
    @State private var showingMemberNumberPrompt = false

    private var myProfile: ShooterProfile? {
        profiles.first
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

                        Button("Try Again") {
                            showingMemberNumberPrompt = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let friendProfile = friendProfile {
                    comparisonView(friendProfile: friendProfile)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)

                        Text("Enter Friend's USPSA Number")
                            .font(.headline)

                        Text("To compare performance, enter your friend's USPSA member number")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Enter Number") {
                            showingMemberNumberPrompt = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(friend.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Enter USPSA Member Number", isPresented: $showingMemberNumberPrompt) {
                TextField("Member Number", text: $friendMemberNumber)
                    .textInputAutocapitalization(.characters)

                Button("Cancel", role: .cancel) {}

                Button("Load") {
                    Task {
                        await loadFriendProfile()
                    }
                }
            } message: {
                Text("Enter \(friend.displayName)'s USPSA member number to view their profile")
            }
        }
    }

    @ViewBuilder
    private func comparisonView(friendProfile: FriendPerformance) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overall comparison
                if let myProfile = myProfile {
                    ForEach(Division.allCases, id: \.self) { division in
                        if let myDiv = myProfile.divisions.first(where: { $0.division == division }),
                           let myPercentage = myDiv.currentPercentage,
                           let friendDiv = friendProfile.divisions.first(where: { $0.divisionCode == division.rawValue }) {

                            DivisionComparisonCard(
                                division: division,
                                myClassification: myDiv.classification,
                                myPercentage: myPercentage,
                                friendName: friend.displayName,
                                friendClassification: ShooterClass(rawValue: friendDiv.classification) ?? .U,
                                friendPercentage: friendDiv.currentPercentage
                            )
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

    private func loadFriendProfile() async {
        guard !friendMemberNumber.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let profile = try await cloudKitManager.fetchFriendProfile(memberNumber: friendMemberNumber)
            friendProfile = profile
        } catch {
            errorMessage = "Could not load friend's profile. Make sure they have synced their USPSA data and enabled sharing."
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

    private var maxPercentage: Double {
        max(myPercentage, friendPercentage, 100)
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                // My bar
                Rectangle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: geometry.size.width * (myPercentage / maxPercentage) / 2)

                Spacer()
                    .frame(width: 2)

                // Friend's bar
                Rectangle()
                    .fill(Color.green.opacity(0.6))
                    .frame(width: geometry.size.width * (friendPercentage / maxPercentage) / 2)
            }
        }
        .frame(height: 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(4)
    }
}
