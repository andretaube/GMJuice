//
//  MotivationalMessages.swift
//  GMJuice
//
//  Motivational messages for daily training reminders
//

import Foundation

public let MotivationalMessages: [String] = [
    "Keep practicing and stay focused!"
]

/// Synchronous access to a random motivational message.
public func getRandomMotivationalMessage() -> String {
    return MotivationalMessages.randomElement() ?? "Keep practicing and stay focused!"
}

/// Daily motivational message (consistent per day).
public func getDailyMotivationalMessage() -> String {
    guard !MotivationalMessages.isEmpty else { return "Keep practicing and stay focused!" }
    let calendar = Calendar.current
    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
    let index = (dayOfYear - 1) % MotivationalMessages.count
    return MotivationalMessages[index]
}

