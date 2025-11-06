//
//  TrainTips.swift
//  GMJuice
//
//  Created by Claude on 11/5/25.
//

import SwiftUI
import TipKit

// MARK: - Division Selection Tip

struct SelectDivisionTip: Tip {
    var title: Text {
        Text("Choose Your Division")
    }

    var message: Text? {
        Text("Select which USPSA division you're training with. This determines the GM benchmark times used for performance tracking.")
    }

    var image: Image? {
        Image(systemName: "list.bullet")
    }
}

// MARK: - Timer Button Tip

struct TimerButtonTip: Tip {
    var title: Text {
        Text("Start Training with Timer")
    }

    var message: Text? {
        Text("Connect your AMG timer via Bluetooth to automatically record your shot times and track performance.")
    }

    var image: Image? {
        Image(systemName: "timer")
    }
}

// MARK: - Video Button Tip

struct VideoRecordingTip: Tip {
    var title: Text {
        Text("Record Your Training")
    }

    var message: Text? {
        Text("Record video of your runs to review technique and track progress over time.")
    }

    var image: Image? {
        Image(systemName: "video.fill")
    }
}

// MARK: - Timer Log Tip

struct TimerLogTip: Tip {
    var title: Text {
        Text("View Your Training History")
    }

    var message: Text? {
        Text("Access all your recorded runs organized by date and stage. Review times and track improvement.")
    }

    var image: Image? {
        Image(systemName: "list.bullet.rectangle")
    }
}
