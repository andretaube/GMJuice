//
//  WidgetSettings.swift
//  GMJuice
//
//  Created by Claude on 11/6/25.
//

import Foundation

enum StageDisplayMode: String, Codable, CaseIterable {
    case classification = "Class"
    case percentage = "Percent"
    case time = "Time"
    case all = "All"

    var displayName: String { rawValue }
}

enum WidgetRotationInterval: Int, Codable, CaseIterable {
    case never = 0
    case every5Minutes = 5
    case every15Minutes = 15
    case every30Minutes = 30
    case every60Minutes = 60

    var displayName: String {
        switch self {
        case .never: return "Never (show first only)"
        case .every5Minutes: return "Every 5 minutes"
        case .every15Minutes: return "Every 15 minutes"
        case .every30Minutes: return "Every 30 minutes"
        case .every60Minutes: return "Every hour"
        }
    }
}

class WidgetSettings {
    static let shared = WidgetSettings()

    private let appGroupID = "group.com.andretaube.gmjuice"
    private let selectedDivisionsKey = "widget_selected_divisions"
    private let rotationIntervalKey = "widget_rotation_interval"
    private let stageDisplayModeKey = "widget_stage_display_mode"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // Selected divisions to show in widget (empty = show all)
    var selectedDivisions: [String] {
        get {
            defaults.stringArray(forKey: selectedDivisionsKey) ?? []
        }
        set {
            defaults.set(newValue, forKey: selectedDivisionsKey)
        }
    }

    // How often to rotate between divisions
    var rotationInterval: WidgetRotationInterval {
        get {
            WidgetRotationInterval(rawValue: defaults.integer(forKey: rotationIntervalKey)) ?? .every15Minutes
        }
        set {
            defaults.set(newValue.rawValue, forKey: rotationIntervalKey)
        }
    }

    // What to display in stage boxes
    var stageDisplayMode: StageDisplayMode {
        get {
            if let raw = defaults.string(forKey: stageDisplayModeKey),
               let mode = StageDisplayMode(rawValue: raw) {
                return mode
            }
            return .classification
        }
        set {
            defaults.set(newValue.rawValue, forKey: stageDisplayModeKey)
        }
    }
}
