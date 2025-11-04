//
//  NotificationManager.swift
//  GMJuice
//
//  Created by Claude on 10/24/25.
//

import Foundation
import UserNotifications
import SwiftData

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private let notificationCenter = UNUserNotificationCenter.current()

    // UserDefaults keys
    private let weeklyNotificationEnabledKey = "weekly_notification_enabled"
    private let weeklyNotificationDayKey = "weekly_notification_day"
    private let weeklyNotificationHourKey = "weekly_notification_hour"

    private let dailyNotificationEnabledKey = "daily_notification_enabled"
    private let dailyNotificationHourKey = "daily_notification_hour"
    private let dailyNotificationDaysKey = "daily_notification_days" // Stored as array of Int

    private let defaults = UserDefaults.standard

    var weeklyNotificationEnabled: Bool {
        get {
            // If the key has never been set, return true (enabled by default)
            if defaults.object(forKey: weeklyNotificationEnabledKey) == nil {
                return true
            }
            return defaults.bool(forKey: weeklyNotificationEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: weeklyNotificationEnabledKey)
            if newValue {
                scheduleWeeklyNotification()
            } else {
                cancelWeeklyNotification()
            }
        }
    }

    // 0 = Sunday, 1 = Monday, etc.
    var weeklyNotificationDay: Int {
        get { defaults.object(forKey: weeklyNotificationDayKey) as? Int ?? 5 } // Default: Friday
        set {
            defaults.set(newValue, forKey: weeklyNotificationDayKey)
            if weeklyNotificationEnabled {
                scheduleWeeklyNotification()
            }
        }
    }

    // Hour of day (0-23)
    var weeklyNotificationHour: Int {
        get { defaults.object(forKey: weeklyNotificationHourKey) as? Int ?? 9 } // Default: 9 AM
        set {
            defaults.set(newValue, forKey: weeklyNotificationHourKey)
            if weeklyNotificationEnabled {
                scheduleWeeklyNotification()
            }
        }
    }

    // MARK: - Daily Notification Properties

    var dailyNotificationEnabled: Bool {
        get {
            // If the key has never been set, return true (enabled by default)
            if defaults.object(forKey: dailyNotificationEnabledKey) == nil {
                return true
            }
            return defaults.bool(forKey: dailyNotificationEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: dailyNotificationEnabledKey)
            if newValue {
                scheduleDailyNotifications()
            } else {
                cancelDailyNotifications()
            }
        }
    }

    // Hour of day (0-23) for daily reminder
    var dailyNotificationHour: Int {
        get { defaults.object(forKey: dailyNotificationHourKey) as? Int ?? 8 } // Default: 8 AM
        set {
            defaults.set(newValue, forKey: dailyNotificationHourKey)
            if dailyNotificationEnabled {
                scheduleDailyNotifications()
            }
        }
    }

    // Active days: [1=Monday, 2=Tuesday, ..., 5=Friday, 6=Saturday, 7=Sunday]
    var dailyNotificationDays: [Int] {
        get {
            if let savedDays = defaults.array(forKey: dailyNotificationDaysKey) as? [Int], !savedDays.isEmpty {
                return savedDays
            }
            return [2, 3, 4, 5, 6] // Default: Monday-Friday
        }
        set {
            defaults.set(newValue, forKey: dailyNotificationDaysKey)
            if dailyNotificationEnabled {
                scheduleDailyNotifications()
            }
        }
    }

    private override init() {
        super.init()
        // Set self as the notification center delegate to handle foreground presentation
        notificationCenter.delegate = self
    }

    // MARK: - Permission Management

    func requestPermission() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted

            if granted {
                print("Notification permission granted")
                if weeklyNotificationEnabled {
                    scheduleWeeklyNotification()
                }
            } else {
                print("Notification permission denied")
            }
        } catch {
            print("Error requesting notification permission: \(error)")
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Weekly Summary Notification

    func scheduleWeeklyNotification(modelContext: ModelContext? = nil) {
        // Cancel existing weekly notification first
        cancelWeeklyNotification()

        // Create date components for the weekly trigger
        var dateComponents = DateComponents()
        dateComponents.weekday = weeklyNotificationDay + 1 // Calendar uses 1-7 (Sunday = 1)
        dateComponents.hour = weeklyNotificationHour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Weekly Training Summary"
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_SUMMARY"

        // If modelContext is provided, compute fresh summary
        if let modelContext = modelContext {
            Task {
                let summaryText = await generateWeeklySummary(modelContext: modelContext)
                content.body = summaryText

                let request = UNNotificationRequest(
                    identifier: "weekly_summary",
                    content: content,
                    trigger: trigger
                )

                do {
                    try await notificationCenter.add(request)
                    print("Weekly notification scheduled with fresh data for weekday \(dateComponents.weekday ?? 0) at \(dateComponents.hour ?? 0):00")
                } catch {
                    print("Error scheduling weekly notification: \(error)")
                }
            }
        } else {
            // Fallback to placeholder text if no context provided
            content.body = "Check your practice stats from the past 7 days. Tap to view your progress."

            let request = UNNotificationRequest(
                identifier: "weekly_summary",
                content: content,
                trigger: trigger
            )

            Task {
                do {
                    try await notificationCenter.add(request)
                    print("Weekly notification scheduled for weekday \(dateComponents.weekday ?? 0) at \(dateComponents.hour ?? 0):00")
                } catch {
                    print("Error scheduling weekly notification: \(error)")
                }
            }
        }
    }

    func cancelWeeklyNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["weekly_summary"])
        print("Weekly notification cancelled")
    }

    func cancelAllNotifications() {
        cancelWeeklyNotification()
        cancelDailyNotifications()
        print("✅ All notifications cancelled")
    }

    /// Update the scheduled notification with fresh data
    /// Call this when app goes to background or terminates
    func updateScheduledNotification(modelContext: ModelContext) {
        guard weeklyNotificationEnabled else { return }
        print("Updating scheduled notification with fresh data...")
        scheduleWeeklyNotification(modelContext: modelContext)
    }

    // MARK: - Daily Reminder Notification

    func scheduleDailyNotifications() {
        // Cancel existing daily notifications first
        cancelDailyNotifications()

        let hour = dailyNotificationHour
        let activeDays = dailyNotificationDays

        for weekday in activeDays {
            var dateComponents = DateComponents()
            dateComponents.weekday = weekday // 1=Sunday, 2=Monday, etc.
            dateComponents.hour = hour
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            // Generate daily message
            let message = generateDailyMessage()

            let content = UNMutableNotificationContent()
            content.title = "Training Reminder"
            content.body = message
            content.sound = .default
            content.categoryIdentifier = "DAILY_REMINDER"

            let identifier = "daily_reminder_\(weekday)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            Task {
                do {
                    try await notificationCenter.add(request)
                    print("Daily notification scheduled for weekday \(weekday) at \(hour):00")
                } catch {
                    print("Error scheduling daily notification for weekday \(weekday): \(error)")
                }
            }
        }
    }

    func cancelDailyNotifications() {
        // Cancel all daily notifications (weekdays 1-7)
        let identifiers = (1...7).map { "daily_reminder_\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Daily notifications cancelled")
    }

    /// Update daily notifications (call when settings change or app backgrounds)
    func updateDailyNotifications() {
        guard dailyNotificationEnabled else { return }
        print("Updating daily notifications...")
        scheduleDailyNotifications()
    }

    // MARK: - Daily Message Generation

    /// Generate daily training reminder message
    private func generateDailyMessage() -> String {
        return MotivationalMessages.randomElement() ?? "Time to practice!"
    }

    // MARK: - Generate Weekly Summary

    func generateWeeklySummary(modelContext: ModelContext) async -> String {
        // Calculate date range for the past 7 days
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return "No data available for the past week."
        }

        // Get the container to create a background context
        let container = modelContext.container

        // Perform database fetch on background thread to avoid blocking main thread
        return await Task.detached {
            // Create a background ModelContext for this task
            let backgroundContext = ModelContext(container)

            let descriptor = FetchDescriptor<StringRun>(
                predicate: #Predicate<StringRun> { run in
                    run.date >= weekAgo && run.date <= now
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )

            do {
                let runs = try backgroundContext.fetch(descriptor)

            if runs.isEmpty {
                return "No practice sessions recorded this week. Time to hit the range!"
            }

            // Calculate total shots (5 per complete run)
            let totalShots = runs.filter { $0.stringShots.count >= 5 }.count * 5

            // Group by division and find best times
            var bestTimesByDivision: [String: [(stage: String, time: Decimal)]] = [:]

            for run in runs where run.time > 0 && run.stringShots.count >= 5 {
                let division = run.divisionId
                let stageName = stageName(for: run.stageId)

                if bestTimesByDivision[division] == nil {
                    bestTimesByDivision[division] = []
                }

                // Check if we already have this stage
                if let existingIndex = bestTimesByDivision[division]?.firstIndex(where: { $0.stage == stageName }) {
                    // Update if this time is better
                    if run.time < bestTimesByDivision[division]![existingIndex].time {
                        bestTimesByDivision[division]![existingIndex] = (stage: stageName, time: run.time)
                    }
                } else {
                    bestTimesByDivision[division]?.append((stage: stageName, time: run.time))
                }
            }

            // Format the summary
            var summary = "This week: \(totalShots) shots fired"

            if !bestTimesByDivision.isEmpty {
                summary += "\n\nBest Times:"
                for (division, stages) in bestTimesByDivision.sorted(by: { $0.key < $1.key }) {
                    summary += "\n\n\(division):"
                    for stageData in stages.sorted(by: { $0.stage < $1.stage }) {
                        let timeStr = Format.formatTime(stageData.time)
                        summary += "\n  \(stageData.stage): \(timeStr)"
                    }
                }
            }

            return summary

            } catch {
                print("Error fetching runs for weekly summary: \(error)")
                return "Error generating summary. Please try again."
            }
        }.value
    }

    // MARK: - Send Test Summary (for testing)

    func sendWeeklySummaryNow(modelContext: ModelContext) async {
        // First, compute fresh data from the database
        let summaryText = await generateWeeklySummary(modelContext: modelContext)

        let content = UNMutableNotificationContent()
        content.title = "Weekly Training Summary"
        content.body = summaryText
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_SUMMARY"

        // Trigger 5 seconds from now (gives time to background the app)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let request = UNNotificationRequest(
            identifier: "weekly_summary_now",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("Test notification scheduled for 5 seconds from now")
            print("Summary content: \(summaryText)")
        } catch {
            print("Error sending test notification: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Handle notification presentation when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle user tapping on notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap if needed (e.g., navigate to specific view)
        print("User tapped notification: \(response.notification.request.identifier)")
        completionHandler()
    }
}
