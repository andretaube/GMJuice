//
//  CoachMarks.swift
//  GMJuice
//
//  Created by Claude on 11/5/25.
//

import SwiftUI

// MARK: - Coach Mark Model

struct CoachMark: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let highlightFrame: CGRect
    let calloutPosition: CalloutPosition

    enum CalloutPosition {
        case top
        case bottom
        case leading
        case trailing
    }
}

// MARK: - Coach Mark Overlay

struct CoachMarkOverlay: View {
    @Binding var isPresented: Bool
    let marks: [CoachMark]
    @State private var currentStep: Int = 0

    var currentMark: CoachMark {
        marks[currentStep]
    }

    var body: some View {
        ZStack {
            // If no valid highlight frame (zero or very small), just show overlay without spotlight
            let hasValidHighlight = currentMark.highlightFrame.width > 1 && currentMark.highlightFrame.height > 1

            if hasValidHighlight {
                // Semi-transparent overlay with spotlight cutout
                SpotlightOverlay(cutoutFrame: currentMark.highlightFrame)
                    .zIndex(1000)
            } else {
                // Just a dimmed background without spotlight
                Color.black.opacity(0.75)
                    .ignoresSafeArea(.all)
                    .zIndex(1000)
            }

            // Callout bubble
            VStack {
                if hasValidHighlight {
                    // Position relative to highlighted element
                    if currentMark.calloutPosition == .bottom {
                        Spacer()
                            .frame(height: currentMark.highlightFrame.maxY + 20)
                    }

                    if currentMark.calloutPosition == .top {
                        CalloutBubble(
                            title: currentMark.title,
                            message: currentMark.message,
                            currentStep: currentStep + 1,
                            totalSteps: marks.count,
                            onNext: nextStep,
                            onSkip: skip
                        )
                        .padding(.horizontal, 20)
                        .zIndex(1001)

                        Spacer()
                            .frame(height: UIScreen.main.bounds.height - currentMark.highlightFrame.minY + 20)
                    }

                    if currentMark.calloutPosition == .bottom {
                        CalloutBubble(
                            title: currentMark.title,
                            message: currentMark.message,
                            currentStep: currentStep + 1,
                            totalSteps: marks.count,
                            onNext: nextStep,
                            onSkip: skip
                        )
                        .padding(.horizontal, 20)
                        .zIndex(1001)

                        Spacer()
                    }
                } else {
                    // Center the callout when no highlight
                    Spacer()

                    CalloutBubble(
                        title: currentMark.title,
                        message: currentMark.message,
                        currentStep: currentStep + 1,
                        totalSteps: marks.count,
                        onNext: nextStep,
                        onSkip: skip
                    )
                    .padding(.horizontal, 20)
                    .zIndex(1001)

                    Spacer()
                }
            }
            .zIndex(1001)
        }
        .ignoresSafeArea(.all)
        .zIndex(999)
    }

    private func nextStep() {
        if currentStep < marks.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        } else {
            dismiss()
        }
    }

    private func skip() {
        dismiss()
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }
}

// MARK: - Spotlight Overlay

struct SpotlightOverlay: View {
    let cutoutFrame: CGRect

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Fill entire screen with dark overlay (dims everything including navigation)
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.black.opacity(0.75))
                )

                // Cut out spotlight area with rounded corners
                let spotlightPath = Path(roundedRect: cutoutFrame.insetBy(dx: -8, dy: -8), cornerRadius: 12)
                context.blendMode = .destinationOut
                context.fill(spotlightPath, with: .color(.white))
            }
            .ignoresSafeArea(.all)

            // Add glowing border around spotlight
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue, lineWidth: 3)
                .frame(width: cutoutFrame.width + 16, height: cutoutFrame.height + 16)
                .position(x: cutoutFrame.midX, y: cutoutFrame.midY)
                .shadow(color: .blue.opacity(0.6), radius: 10)
        }
    }
}

// MARK: - Callout Bubble

struct CalloutBubble: View {
    let title: String
    let message: String
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index < currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }

                Spacer()

                Text("\(currentStep)/\(totalSteps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Title
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            // Message
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Buttons
            HStack(spacing: 12) {
                Button("Skip") {
                    onSkip()
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onNext()
                } label: {
                    HStack(spacing: 4) {
                        Text(currentStep < totalSteps ? "Next" : "Got it")
                            .fontWeight(.semibold)
                        if currentStep < totalSteps {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(20)
                }
            }
        }
        .padding(20)
        .background(
            ZStack {
                // Solid opaque background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))

                // Border for better visibility
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
        )
    }
}

// MARK: - Preference Key for Frame Tracking

struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - View Extension for Frame Tracking

extension View {
    func trackFrame(named name: String) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: FramePreferenceKey.self,
                    value: [name: geometry.frame(in: .global)]
                )
            }
        )
    }
}
