//
//  TrainViewHelp.swift
//  GMJuice
//
//  The single in-app help sheet for the Train tab.
//

import SwiftUI

struct TrainViewHelp {
    /// Tutorial cards for the TrainView help sheet.
    static func tutorialCards() -> [TutorialCardData] {
        let hasTimerSaved = UserDefaults.standard.string(forKey: "ble_saved_uuid") != nil

        var cards: [TutorialCardData] = []

        cards.append(TutorialCardData(
            icon: "list.bullet",
            iconColor: .orange,
            title: "Choose Your Division",
            description: "Select your division — it sets the GM benchmark times used for scoring."
        ))

        if !hasTimerSaved {
            cards.append(TutorialCardData(
                icon: "antenna.radiowaves.left.and.right",
                iconColor: .orange,
                title: "Connect Your Timer",
                description: "In Settings, pair your AMG timer via Bluetooth to automatically capture shot times and splits."
            ))
        }

        cards.append(TutorialCardData(
            icon: "scope",
            iconColor: .orange,
            title: "Shoot a Stage",
            description: "Tap a stage to start. Each set is 5 strings (4 for Outer Limits) and is scored on your best 4 (best 3) — the worst string is dropped. The next beep starts a fresh set."
        ))

        cards.append(TutorialCardData(
            icon: "tablecells",
            iconColor: .orange,
            title: "Target Times",
            description: "Check the per-class, per-string target times for any division — your digital range card."
        ))

        cards.append(TutorialCardData(
            icon: "list.bullet.rectangle",
            iconColor: .orange,
            title: "Review Your Log",
            description: "Every scored stage is saved by day. Tap in to see each set's strings, splits, and your trend."
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
