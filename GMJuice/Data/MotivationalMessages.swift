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

/// Synchronous access to motivational messages (uses Firebase data when available)
public func getRandomMotivationalMessage() -> String {
    let messages = MotivationalMessagesService.shared.syncMessages
    return messages.randomElement() ?? "Keep practicing and stay focused!"
}

/// Daily motivational message (consistent per day)  
public func getDailyMotivationalMessage() -> String {
    let messages = MotivationalMessagesService.shared.syncMessages
    // Use current date as seed for consistent daily message
    let calendar = Calendar.current
    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
    let index = (dayOfYear - 1) % messages.count
    return messages[index]
}

