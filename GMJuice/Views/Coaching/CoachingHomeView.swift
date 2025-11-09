//
//  CoachingHomeView.swift
//  GMJuice
//
//  Created by Claude on 11/4/25.
//

import SwiftUI
import SwiftData

struct CoachingHomeView: View {
    @Query private var profiles: [ShooterProfile]

    private var currentUserNumber: String? {
        UserDefaults.standard.currentUserUSPSANumber
    }

    private var myProfile: ShooterProfile? {
        guard let currentUser = currentUserNumber else {
            return profiles.first
        }
        return profiles.first { $0.uspsaNumber == currentUser }
    }

    private var myScores: [MatchScore] {
        guard let profile = myProfile else { return [] }
        return profile.matchScores.sorted { $0.scoreDate > $1.scoreDate }
    }

    private var hasUSPSANumber: Bool {
        guard let profile = myProfile else { return false }
        return !profile.uspsaNumber.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !hasUSPSANumber {
                    // Show info message when no USPSA number provided
                    NoCoachingMemberView()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Division Cards
                            DivisionCoachingListView(allScores: myScores)
                        }
                        .padding(.vertical, 32)
                    }
                }
            }
            .navigationTitle("Analysis")
        }
    }
}

// MARK: - No USPSA Number Info View

private struct NoCoachingMemberView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)

                // Icon
                Image(systemName: "chart.bar.xaxis.circle")
                    .font(.system(size: 80))
                    .foregroundStyle(.purple)

                // Header
                VStack(spacing: 12) {
                    Text("Connect Your Profile")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Add your SCSA member number to unlock performance analysis and insights")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Benefits
                VStack(alignment: .leading, spacing: 16) {
                    CoachingBenefitRow(
                        icon: "target",
                        title: "Match Strategy",
                        description: "Stage-by-stage tactics based on your performance data"
                    )

                    CoachingBenefitRow(
                        icon: "figure.run",
                        title: "Practice Plans",
                        description: "ROI-focused training priorities to maximize improvement"
                    )

                    CoachingBenefitRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Performance Analysis",
                        description: "Detailed trends, consistency metrics, and progress tracking"
                    )
                }
                .padding(.horizontal, 32)

                // Button
                NavigationLink(destination: ProfileView()) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                        Text("Go to Profile Settings")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }
}

private struct CoachingBenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)
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

// MARK: - Division Coaching List

private struct DivisionCoachingListView: View {
    let allScores: [MatchScore]

    private var divisionGroups: [(division: String, matchCount: Int, mostRecentDate: Date)] {
        let grouped = Dictionary(grouping: allScores) { $0.divisionCode }
        return grouped.map { division, scores in
            let uniqueMatches = Set(scores.map { "\($0.matchName)-\($0.scoreDate)" })
            let mostRecent = scores.map { $0.scoreDate }.max() ?? Date.distantPast
            return (division: division, matchCount: uniqueMatches.count, mostRecentDate: mostRecent)
        }
        .sorted { $0.mostRecentDate > $1.mostRecentDate }  // Sort by most recent first
    }

    var body: some View {
        VStack(spacing: 16) {
            if divisionGroups.isEmpty {
                // No data state
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)

                    Text("No Match Data")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Import classifier scores or record training runs to get personalized coaching")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.vertical, 60)
            } else {
                ForEach(divisionGroups, id: \.division) { group in
                    DivisionCoachingCard(
                        division: group.division,
                        matchCount: group.matchCount,
                        lastShotDate: group.mostRecentDate
                    )
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Division Coaching Card

private struct DivisionCoachingCard: View {
    let division: String
    let matchCount: Int
    let lastShotDate: Date

    private var daysSinceLastShot: Int {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: lastShotDate, to: now)
        return components.day ?? 0
    }

    private var lastShotText: String {
        if daysSinceLastShot == 0 {
            return "Last shot today"
        } else if daysSinceLastShot == 1 {
            return "Last shot yesterday"
        } else if daysSinceLastShot < 7 {
            return "Last shot \(daysSinceLastShot)d ago"
        } else if daysSinceLastShot < 30 {
            let weeks = daysSinceLastShot / 7
            return "Last shot \(weeks)w ago"
        } else if daysSinceLastShot < 365 {
            let months = daysSinceLastShot / 30
            return "Last shot \(months)mo ago"
        } else {
            let years = daysSinceLastShot / 365
            let remainingDays = daysSinceLastShot % 365
            let months = remainingDays / 30
            if months > 0 {
                return "Last shot \(years)y \(months)mo ago"
            } else {
                return "Last shot \(years)y ago"
            }
        }
    }

    var body: some View {
        NavigationLink(destination: CoachingCardsView(divisionCode: division)) {
            HStack(spacing: 16) {
                // Division Icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 56, height: 56)

                    Text(division)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.purple)
                }

                // Division Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(divisionName(division))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(matchCount) matches")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(lastShotText)
                        .font(.caption)
                        .foregroundStyle(daysSinceLastShot > 90 ? .orange : .secondary)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func divisionName(_ code: String) -> String {
        // Use the Division enum's displayName for consistency
        if let division = Division(rawValue: code) {
            return division.displayName
        }
        return code
    }
}
