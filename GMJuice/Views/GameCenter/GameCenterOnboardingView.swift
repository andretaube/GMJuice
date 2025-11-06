//
//  GameCenterOnboardingView.swift
//  GMJuice
//
//  Created by Claude on 11/6/25.
//

import SwiftUI

struct GameCenterOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var gameCenterManager: GameCenterManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 20)

                    // Icon
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)

                    // Title
                    VStack(spacing: 12) {
                        Text("Connect with GameCenter")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Compare your Steel Challenge performance with friends")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Benefits
                    VStack(alignment: .leading, spacing: 20) {
                        GameCenterBenefitRow(
                            icon: "person.2.fill",
                            title: "Add Friends",
                            description: "Connect with other Steel Challenge shooters through GameCenter"
                        )

                        GameCenterBenefitRow(
                            icon: "chart.bar.fill",
                            title: "Compare Performance",
                            description: "See side-by-side classification percentages and stage times"
                        )

                        GameCenterBenefitRow(
                            icon: "trophy.fill",
                            title: "Track Progress Together",
                            description: "Motivate each other and celebrate improvements"
                        )

                        GameCenterBenefitRow(
                            icon: "lock.shield.fill",
                            title: "Privacy First",
                            description: "Only shares official match scores, never your training data"
                        )
                    }
                    .padding(.horizontal, 32)

                    // Connect button
                    Button {
                        gameCenterManager.authenticate()
                    } label: {
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                            Text("Connect with GameCenter")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)

                    if let error = gameCenterManager.authenticationError {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 32)
                    }

                    Spacer()
                }
            }
            .navigationTitle("GameCenter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct GameCenterBenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.green)
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
