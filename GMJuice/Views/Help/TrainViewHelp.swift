//
//  TrainViewHelp.swift
//  GMJuice
//
//  Created by Claude on 11/23/25.
//

import SwiftUI

// MARK: - TrainView Help Content

struct TrainViewHelp {
    
    /// Creates coach marks for TrainView tutorial overlay
    static func createCoachMarks(
        divisionFrame: CGRect,
        timerButtonFrame: CGRect,
        videoButtonFrame: CGRect,
        timerLogFrame: CGRect,
        videosLogFrame: CGRect
    ) -> [CoachMark] {
        var marks: [CoachMark] = []

        // First tip: Connect timer (if not connected)
        let hasTimerSaved = UserDefaults.standard.string(forKey: "ble_saved_uuid") != nil
        if !hasTimerSaved {
            marks.append(CoachMark(
                title: "Connect Your Timer",
                message: "Go to Settings to connect your AMG timer via Bluetooth. Once connected, you can automatically track your shot times and splits.",
                highlightFrame: divisionFrame, // Use same frame as division since settings isn't visible
                calloutPosition: .bottom
            ))
        }

        // Division picker tip
        marks.append(CoachMark(
            title: "Choose Your Division",
            message: "Select which USPSA division you're training with. This determines the GM benchmark times used for performance tracking.",
            highlightFrame: divisionFrame,
            calloutPosition: .bottom
        ))

        // Timer button tip
        marks.append(CoachMark(
            title: "Start Training with Timer",
            message: hasTimerSaved
                ? "When your timer is connected, you'll see your shots, splits, and performance history automatically recorded for each training run."
                : "After connecting your timer in Settings, tap here to start recording your training runs with automatic shot and split timing.",
            highlightFrame: timerButtonFrame,
            calloutPosition: .top
        ))

        // Video button tip
        marks.append(CoachMark(
            title: "Record Your Training",
            message: "Record video of your runs with a professional overlay showing shot times, splits, classification score, and performance metrics. Perfect for reviewing technique and tracking progress.",
            highlightFrame: videoButtonFrame,
            calloutPosition: .top
        ))

        // Timer Log tip
        marks.append(CoachMark(
            title: "View Your Training History",
            message: "Access all your recorded runs organized by date and stage. Review times and track improvement.",
            highlightFrame: timerLogFrame,
            calloutPosition: .bottom
        ))

        // Video Log tip
        marks.append(CoachMark(
            title: "Browse Your Video Log",
            message: "View all your recorded training videos in one place. Review your form and technique across all stages.",
            highlightFrame: videosLogFrame,
            calloutPosition: .bottom
        ))

        // Final motivational tip (use division frame since no specific UI to highlight)
        let motivationalMessage = getRandomMotivationalMessage()
        marks.append(CoachMark(
            title: "Now Go Train!",
            message: motivationalMessage,
            highlightFrame: divisionFrame,
            calloutPosition: .bottom
        ))

        return marks
    }
    
    /// Tutorial cards for the TrainView help sheet
    static func tutorialCards() -> [TutorialCardData] {
        let hasTimerSaved = UserDefaults.standard.string(forKey: "ble_saved_uuid") != nil
        
        var cards: [TutorialCardData] = []
        
        // Division Selection
        cards.append(TutorialCardData(
            icon: "list.bullet",
            iconColor: .blue,
            title: "Choose Your Division",
            description: "Select which USPSA division you're training with. This determines the GM benchmark times used for performance tracking."
        ))
        
        // BLE Connection (conditional)
        if !hasTimerSaved {
            cards.append(TutorialCardData(
                icon: "antenna.radiowaves.left.and.right",
                iconColor: .orange,
                title: "Connect Your Timer",
                description: "Go to Settings to connect your AMG timer via Bluetooth. Once connected, you can automatically track your shot times and splits."
            ))
        }
        
        // Timer Button
        cards.append(TutorialCardData(
            icon: "timer",
            iconColor: .blue,
            title: "Start Training with Timer",
            description: hasTimerSaved
                ? "When your timer is connected, you'll see your shots, splits, and performance history automatically recorded for each training run."
                : "After connecting your timer in Settings, tap here to start recording your training runs with automatic shot and split timing."
        ))
        
        // Video Button
        cards.append(TutorialCardData(
            icon: "video.fill",
            iconColor: .red,
            title: "Record Your Training",
            description: "Record video of your runs to review technique and track progress over time."
        ))
        
        // Timer Log
        cards.append(TutorialCardData(
            icon: "list.bullet.rectangle",
            iconColor: .blue,
            title: "View Your Training History",
            description: "Access all your recorded runs organized by date and stage. Review times and track improvement."
        ))
        
        // Video Log
        cards.append(TutorialCardData(
            icon: "video.fill",
            iconColor: .red,
            title: "Browse Your Video Log",
            description: "View all your recorded training videos in one place. Review your form and technique across all stages."
        ))
        
        return cards
    }
}

// MARK: - Tutorial Card Data Model

struct TutorialCardData {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

// MARK: - TrainView Tutorial View

struct TrainTutorialView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HelpViewContainer(title: "How to Use Train") {
            ForEach(TrainViewHelp.tutorialCards().indices, id: \.self) { index in
                let card = TrainViewHelp.tutorialCards()[index]
                TutorialCard(
                    icon: card.icon,
                    iconColor: card.iconColor,
                    title: card.title,
                    description: card.description
                )
            }
        }
    }
}

#Preview("Train Tutorial") {
    TrainTutorialView()
}