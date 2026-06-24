//
//  AnalyticsService.swift
//  GMJuice
//
//  Analytics service for comprehensive Firebase Analytics tracking
//

import Foundation
@preconcurrency import FirebaseAnalytics
@preconcurrency import FirebaseCrashlytics

@MainActor
class AnalyticsService {
    nonisolated static let shared = AnalyticsService()
    
    nonisolated private init() {
        Task { @MainActor in
            setupAnalytics()
        }
    }
    
    private func setupAnalytics() {
        // Enable analytics collection
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Set default event parameters
        Analytics.setDefaultEventParameters([
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "platform": "iOS"
        ])
    }
    
    // MARK: - Screen Tracking
    
    func trackScreen(_ screenName: String, screenClass: String? = nil) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
        
        // Also set current screen for Crashlytics
        Crashlytics.crashlytics().setCustomValue(screenName, forKey: "current_screen")
    }
    
    // MARK: - Session Tracking
    
    func trackSessionStart() {
        Analytics.logEvent("session_start", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackSessionEnd(duration: TimeInterval) {
        Analytics.logEvent("session_end", parameters: [
            "session_duration": duration,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - User Properties

    func setUserProperties(classification: String?) {
        // Note: We intentionally do NOT collect USPSA numbers for privacy

        if let classification = classification {
            Analytics.setUserProperty(classification, forName: "shooter_classification")
            Crashlytics.crashlytics().setCustomValue(classification, forKey: "classification")
        }
    }

    func setDivisionProperty(_ division: String) {
        Analytics.setUserProperty(division, forName: "active_division")
    }

    func setUserStats(logEntryCount: Int, divisionsUsed: Int, stagesUsed: Int) {
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(logEntryCount, forKey: "log_entry_count")
        crashlytics.setCustomValue(divisionsUsed, forKey: "divisions_used")
        crashlytics.setCustomValue(stagesUsed, forKey: "stages_used")
    }
    
    // MARK: - Training & Recording Analytics
    
    func trackStageSelection(stage: String, division: String, mode: String) {
        Analytics.logEvent("stage_selected", parameters: [
            "stage_code": stage,
            "stage_name": stageDisplayName(for: stage),
            "division": division,
            "mode": mode,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackStringRun(stage: String, division: String, stringNumber: Int, time: Double, shots: Int, penalties: Int, classification: String?) {
        Analytics.logEvent("string_completed", parameters: [
            "stage_code": stage,
            "division": division,
            "string_number": stringNumber,
            "raw_time": time,
            "shot_count": shots,
            "penalty_count": penalties,
            "classification": classification ?? "unknown",
            "adjusted_time": time + (Double(penalties) * 5.0),
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Track performance tier
        let performanceTier = getPerformanceTier(time: time, stage: stage, division: division)
        Analytics.logEvent("performance_achieved", parameters: [
            "stage_code": stage,
            "division": division,
            "performance_tier": performanceTier,
            "raw_time": time
        ])
    }
    
    func trackSessionSummary(stage: String, division: String, totalStrings: Int, bestTime: Double, worstTime: Double, avgTime: Double, totalShots: Int) {
        Analytics.logEvent("training_session_completed", parameters: [
            "stage_code": stage,
            "division": division,
            "total_strings": totalStrings,
            "best_time": bestTime,
            "worst_time": worstTime,
            "average_time": avgTime,
            "total_shots": totalShots,
            "session_duration_strings": totalStrings,
            "improvement_ratio": worstTime > 0 ? bestTime / worstTime : 0
        ])
    }
    
    // MARK: - BLE & Device Analytics
    
    func trackBLEConnection(deviceName: String?, connectionTime: TimeInterval) {
        Analytics.logEvent("ble_device_connected", parameters: [
            "device_name": deviceName ?? "unknown",
            "connection_time": connectionTime,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackBLEDisconnection(deviceName: String?, sessionDuration: TimeInterval, reason: String) {
        Analytics.logEvent("ble_device_disconnected", parameters: [
            "device_name": deviceName ?? "unknown",
            "session_duration": sessionDuration,
            "reason": reason,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackBLEScanStart() {
        Analytics.logEvent("ble_scan_started", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackBLEDeviceFound(deviceCount: Int, scanDuration: TimeInterval) {
        Analytics.logEvent("ble_devices_found", parameters: [
            "device_count": deviceCount,
            "scan_duration": scanDuration,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Feature Usage
    
    func trackFeatureUsed(_ feature: String, parameters: [String: Any] = [:]) {
        var params = parameters
        params["feature_name"] = feature
        params["timestamp"] = Date().timeIntervalSince1970
        
        Analytics.logEvent("feature_used", parameters: params)
    }
    
    func trackSettingChanged(setting: String, oldValue: String?, newValue: String) {
        Analytics.logEvent("setting_changed", parameters: [
            "setting_name": setting,
            "old_value": oldValue ?? "none",
            "new_value": newValue,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackDataExport(type: String, recordCount: Int, success: Bool) {
        Analytics.logEvent("data_exported", parameters: [
            "export_type": type, // "csv", "pdf", etc.
            "record_count": recordCount,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Error Tracking
    
    func trackError(_ error: Error, context: String) {
        Analytics.logEvent("error_occurred", parameters: [
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code,
            "error_description": error.localizedDescription,
            "context": context,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Also log to Crashlytics
        Crashlytics.crashlytics().record(error: error)
        Crashlytics.crashlytics().setCustomValue(context, forKey: "error_context")
    }
    
    // MARK: - Performance Tracking
    
    func trackPerformanceMetric(metric: String, value: Double, unit: String) {
        Analytics.logEvent("performance_metric", parameters: [
            "metric_name": metric,
            "metric_value": value,
            "metric_unit": unit,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackAppLaunchTime(_ launchTime: TimeInterval) {
        Analytics.logEvent("app_launch_performance", parameters: [
            "launch_time": launchTime,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Notification Analytics
    
    func trackNotificationScheduled(type: String, trigger: String) {
        Analytics.logEvent("notification_scheduled", parameters: [
            "notification_type": type,
            "trigger": trigger,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackNotificationReceived(type: String) {
        Analytics.logEvent("notification_received", parameters: [
            "notification_type": type,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackNotificationTapped(type: String) {
        Analytics.logEvent("notification_tapped", parameters: [
            "notification_type": type,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Helper Methods
    
    private func stageDisplayName(for code: String) -> String {
        switch code {
        case "SC-101": return "Roundabout"
        case "SC-102": return "Accelerator"
        case "SC-103": return "Bill Drill"
        case "SC-104": return "Outer Limits"
        case "SC-105": return "Pendulum"
        case "SC-106": return "Five to Go"
        case "SC-107": return "Smoke & Hope"
        case "SC-108": return "Speed Option"
        default: return code
        }
    }
    
    private func getPerformanceTier(time: Double, stage: String, division: String) -> String {
        // This would use your PeakBenchmarks logic
        // Simplified version here
        if time < 2.0 {
            return "grand_master"
        } else if time < 3.0 {
            return "master"
        } else if time < 4.0 {
            return "a_class"
        } else if time < 5.0 {
            return "b_class"
        } else {
            return "c_class_or_below"
        }
    }
}