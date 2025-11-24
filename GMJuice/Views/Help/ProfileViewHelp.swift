//
//  ProfileViewHelp.swift
//  GMJuice
//
//  Created by Claude on 11/23/25.
//

import SwiftUI

// MARK: - ProfileView Help Content

struct ProfileViewHelp {
    
    /// Creates coach marks for ProfileView tutorial overlay
    static func createCoachMarks(
        trackedFrames: [String: CGRect],
        isCurrentUser: Bool,
        currentUserNumber: String?,
        profiles: [ShooterProfile]
    ) -> [CoachMark]? {
        guard let uspsaNumberFrame = trackedFrames["uspsaNumber"],
              let tabPickerFrame = trackedFrames["tabPicker"],
              let firstDivisionFrame = trackedFrames["firstDivision"] else {
            return nil
        }

        var marks: [CoachMark] = []

        // 1. Tab Navigation
        marks.append(CoachMark(
            title: "Navigation Tabs",
            message: "Switch between Profile, Match Scores, and Following tabs to view different aspects of your shooting data.",
            highlightFrame: tabPickerFrame,
            calloutPosition: .bottom
        ))

        // 2. USPSA Number
        marks.append(CoachMark(
            title: "Edit USPSA Number",
            message: "Tap here to edit your USPSA member number and view sync status for your classification data.",
            highlightFrame: uspsaNumberFrame,
            calloutPosition: .bottom
        ))

        // 3. Division Section
        marks.append(CoachMark(
            title: "Division Summary",
            message: "Each division shows your classification level, current percentage, total time, and peak time. The chevron indicates you can tap to expand and view individual stage scores.",
            highlightFrame: firstDivisionFrame,
            calloutPosition: .top
        ))

        // 4. Expand for stages (only if we have the chevron frame)
        if let chevronFrame = trackedFrames["divisionChevron"] {
            marks.append(CoachMark(
                title: "Expand Division",
                message: "Tap on any division to expand and view all 8 classifier stages used for your classification score. Each stage shows your time, classification level, and what you need to reach the next level.",
                highlightFrame: chevronFrame,
                calloutPosition: .top
            ))
        }

        // 5. Match Scores Division Filter (only if we have the frame from Match Scores tab)
        if let divisionFilterFrame = trackedFrames["divisionFilter"] {
            marks.append(CoachMark(
                title: "Filter by Division",
                message: "Use these pills to filter your match scores by division. Tap 'All' to see scores from all divisions, or select a specific division to view only those scores.",
                highlightFrame: divisionFilterFrame,
                calloutPosition: .bottom
            ))
        }

        // 6. Following Tab (only if current user and has followed shooters)
        if isCurrentUser,
           let followingTabFrame = trackedFrames["followingTab"],
           let currentUser = currentUserNumber {
            let followedCount = profiles.filter { $0.uspsaNumber != currentUser && !$0.uspsaNumber.isEmpty }.count
            if followedCount > 0 {
                marks.append(CoachMark(
                    title: "Compare with Others",
                    message: "View shooters you're following and compare your performance against them to track your progress.",
                    highlightFrame: followingTabFrame,
                    calloutPosition: .bottom
                ))
            }
        }

        return marks
    }
}