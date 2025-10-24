//
//  StagePracticeSuggestions.swift
//  GMJuice
//
//  Created by Claude on 10/24/25.
//

import Foundation

/// Maps each Steel Challenge stage to practice focus areas
struct StagePracticeSuggestions {

    /// Get random practice suggestions for a stage
    static func suggestions(for stageCode: String) -> [String] {
        return stageSuggestions[stageCode] ?? []
    }

    /// Get a random suggestion for a stage
    static func randomSuggestion(for stageCode: String) -> String? {
        return suggestions(for: stageCode).randomElement()
    }

    // MARK: - Stage Suggestions Data

    static let stageSuggestions: [String: [String]] = [

        // SC-101: 5 To Go — accuracy, small plates, plate four matters
        "SC-101": [
            "clean accurate first shot start",
            "smooth trigger press on first plate",
            "see the sight, press straight",
            "steady sight picture before each shot",
            "call every shot before leaving plate",
            "see the hit, trust it",
            "consistent grip pressure through string",
            "maintaining sight alignment through transitions",
            "efficient target acquisition on each plate",
            "hard visual focus on plate four",
            "plate four demands precise aiming discipline",
            "eliminating hesitation between shots when ready",
            "drive gun to next target decisively",
            "hard visual focus on each plate",
            "follow-through on the stop plate",
            "controlled breathing before the beep",
            "quick trigger recovery after each shot",
            "commitment to each trigger press",
            "accuracy first, then build speed",
            "clear sight picture every single plate",
            "call the stop plate hit",
            "no wasted motion between plates",
            "know each hit as it breaks"
        ],

        // SC-102: Showdown — fast stage, call shots, stay fast
        // No movement / footwork coaching
        "SC-102": [
            "fast first shot with confidence",
            "see sight flash, call the hit",
            "call every shot instantly, no doubt",
            "run a blazing consistent cadence",
            "hard visual focus on each plate",
            "minimal hesitation between plates, stay aggressive",
            "trigger press is fast but clean",
            "lock the hit in your mind immediately",
            "no extra thought between targets",
            "push pace without losing control",
            "aggressive finish on the stop plate",
            "grip stays locked and consistent",
            "eyes snap early to next plate",
            "match trigger rhythm to transitions",
            "trust the sight picture you see",
            "attack each string like it's final",
            "mentally rehearse shot order and hits",
            "stay on the gas entire string",
            "pure confidence in called hits",
            "call stop plate clean and fast"
        ],

        // SC-103: Smoke & Hope — extremely aggressive, very fast, call shots
        "SC-103": [
            "very aggressive first-shot commitment",
            "blazing fast pairs with minimal pause",
            "drive the sight fast and hard",
            "short, committed trigger presses only",
            "immediate second shot without hesitation",
            "high cadence while keeping hits",
            "attack each plate with urgency",
            "push split-times faster every rep",
            "quick reset and immediate follow-up",
            "control recoil while staying aggressive",
            "run this stage with pure speed",
            "see the hit as you leave",
            "eyes already on next plate instantly",
            "commit fully to each fast shot",
            "run the gun, stay attacking",
            "finish string with aggressive cadence",
            "hard focus to hit that stop plate",
            "no backing off at the end",
            "call every shot at full speed",
            "stay fearless, stay accurate",
            "send it fast, trust the hit",
            "pure speed mindset every string"
        ],

        // SC-104: Outer Limits — accuracy and box-to-box movement
        // This is the ONLY stage allowed to mention movement
        // Movement theme: gun on target and ready to shoot entering box
        "SC-104": [
            "accuracy on distant plates prioritized",
            "controlled accurate breaks at distance",
            "maintain crisp sight picture at range",
            "visually commit to each long shot",
            "call long shots before leaving box",
            "plan exact hits before leaving box",
            "move smooth between shooting boxes",
            "enter box with gun on target",
            "be ready to shoot on entry",
            "muzzle indexed on first plate entering",
            "reengage targets accurately after movement",
            "drive into long shots with intent",
            "no hurried shots at distance at all",
            "eyes back on sight after movement",
            "steady pace even across both boxes",
            "clear identification of stop plate priority",
            "hold finish until you see hit",
            "call the stop plate immediately",
            "stay accurate while changing position",
            "visual plan for second box beforehand",
            "accuracy first, position second"
        ],

        // SC-105: Accelerator — build speed while staying accurate, call shots
        "SC-105": [
            "clean first shot from ready",
            "build speed through the string aggressively",
            "accelerate each target without panic",
            "track the sight on each target",
            "trigger reset timing on fast splits",
            "maintain accuracy while accelerating hard",
            "hard visual focus on final plate",
            "grip pressure locked during speed increase",
            "confident commitment to acceleration",
            "see the hit, call the hit",
            "follow-through on the stop plate",
            "eliminate hesitation between plates entirely",
            "visual discipline on every distance change",
            "upper body stays stable under speed",
            "eyes lead the gun to next plate",
            "no drop in pace on farther plates",
            "steady trigger finger despite speed",
            "clear sight even at max pace",
            "plan splits for near then far targets",
            "rhythm matched to target distances",
            "finish strong with absolute commitment",
            "call the stop plate impact"
        ],

        // SC-106: The Pendulum — accuracy, rhythm, call shots
        // No movement / footwork coaching
        "SC-106": [
            "smooth lateral transitions across plates",
            "consistent rhythm through target array",
            "steady sight before every press",
            "hard visual focus on each plate",
            "call every shot as it leaves",
            "clean trigger timing through transitions",
            "maintain sight alignment through full swing",
            "locked wrists, manage recoil repeatably",
            "controlled first shot with purpose",
            "controlled final plate engagement every string",
            "commitment to your transition pattern",
            "visual lead into next plate early",
            "do not rush the toughest plate",
            "accurate trigger press on tighter plates",
            "accuracy first, let speed happen",
            "clear mental picture of each hit",
            "steady muzzle as shot breaks",
            "eyes ahead of muzzle movement",
            "call the stop plate instantly",
            "never guess the hit, know it"
        ],

        // SC-107: Speed Option — accuracy, stage plan, call shots
        "SC-107": [
            "choose your sequence and trust it",
            "commit fully to chosen pattern",
            "run that pattern fast and clean",
            "maintain speed through the entire option",
            "sight picture consistent on every plate",
            "hard visual focus on each target in order",
            "trigger control on your planned pattern",
            "call every shot as it breaks",
            "eliminate second-guessing mid-run completely",
            "aggressive execution of your plan",
            "mental rehearsal of sequence before start",
            "smooth flow through your option path",
            "follow-through on the stop plate",
            "breathe, settle, then attack hard",
            "accuracy prioritized over reckless speed",
            "deliberate sighted hits for consistency",
            "avoid back-tracking between plates mentally",
            "keep grip consistent through entire run",
            "eyes snap early to next plate",
            "know the hit before leaving target",
            "call the stop plate clean"
        ],

        // SC-108: Roundabout — aggressive, fast, call shots under speed
        "SC-108": [
            "attack the circle with aggression",
            "very fast target entries and exits",
            "high cadence while keeping hits",
            "short, committed trigger presses only",
            "drive the sight hard to target",
            "minimal pause on each plate",
            "push split-times around the circle",
            "fast, committed swing through targets",
            "eyes already on next plate instantly",
            "call every shot at full speed",
            "see the hit as you leave",
            "no wasted motion in rotation",
            "stay fearless and stay accurate",
            "finish each lap with aggression",
            "hard focus to hit that stop plate",
            "no backing off at the end",
            "commit fully to direction of rotation",
            "aggressive muzzle control through recoil",
            "fast acquisition into every plate",
            "do not second-guess entry or exit",
            "call the stop plate while firing"
        ]
    ]
}
