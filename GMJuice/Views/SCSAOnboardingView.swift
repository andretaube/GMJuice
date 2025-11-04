//
//  SCSAOnboardingView.swift
//  GMJuice
//
//  Created by Claude on 11/3/25.
//

import SwiftUI
import SwiftData

struct SCSAOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool

    @State private var memberNumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Icon
                Image(systemName: "trophy.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow)
                    .padding(.top, 40)

                // Header
                VStack(spacing: 12) {
                    Text("Connect Your Classification Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Enter your USPSA member number (also known as your SCSA number) to unlock advanced analytics and performance tracking")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Benefits
                VStack(alignment: .leading, spacing: 16) {
                    BenefitRow(
                        icon: "chart.line.uptrend.xyaxis",
                        text: "Track your SCSA classification standings across all divisions"
                    )

                    BenefitRow(
                        icon: "target",
                        text: "Analyze your match performance with stage-by-stage breakdowns"
                    )

                    BenefitRow(
                        icon: "arrow.clockwise",
                        text: "Automatically sync your official classifier scores"
                    )
                }
                .padding(.horizontal, 32)

                // Input
                VStack(spacing: 16) {
                    TextField("USPSA Member Number", text: $memberNumber)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.asciiCapable)
                        .autocapitalization(.allCharacters)
                        .textInputAutocapitalization(.characters)
                        .padding(.horizontal, 32)

                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        Button {
                            Task {
                                await syncProfile()
                            }
                        } label: {
                            Text("Connect Profile")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(memberNumber.isEmpty ? Color.gray : Color.blue)
                                .cornerRadius(12)
                        }
                        .disabled(memberNumber.isEmpty)
                        .padding(.horizontal, 32)
                    }
                }

                Spacer()

                // Skip button
                Button {
                    isPresented = false
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    private func syncProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            // Sync classification data
            try await SCWebScraper.shared.syncClassificationData(
                memberNumber: memberNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                context: modelContext
            )

            // Success - dismiss
            await MainActor.run {
                isPresented = false
            }
        } catch let error as NSError where error.code == 404 {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to sync profile: \(error.localizedDescription)"
                showingError = true
                isLoading = false
            }
        }
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    let schema = Schema(versionedSchema: Schema004.self)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    return SCSAOnboardingView(isPresented: .constant(true))
        .modelContainer(container)
}
