# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GMJuice is an iOS SwiftUI application for tracking Steel Challenge shooting performance. It connects to an AMG timer via Bluetooth Low Energy (BLE) to record shot times, calculate performance percentages against USPSA benchmarks, and provide real-time audio feedback through text-to-speech announcements.

## Build & Development Commands

### Building and Running
```bash
# Build the project
xcodebuild -project GMJuice.xcodeproj -scheme GMJuice -configuration Debug build

# Build for release
xcodebuild -project GMJuice.xcodeproj -scheme GMJuice -configuration Release build

# Clean build
xcodebuild -project GMJuice.xcodeproj -scheme GMJuice clean
```

**Note:** This project is best developed in Xcode. Open `GMJuice.xcodeproj` in Xcode for the full development experience including simulator testing and debugging.

## Architecture

### Core Singletons
The app uses three main singleton managers that coordinate throughout the app:

- **BLEManager** (`BLE/BLEManager.swift`): Singleton managing Bluetooth connection to AMG shot timer. Handles device discovery, connection persistence via UserDefaults, and parsing shot data from BLE notifications. Publishes connection status and provides callbacks for beep events, shot events, and disconnection.

- **Announcer** (`Announcer.swift`): Singleton managing text-to-speech announcements using AVSpeechSynthesizer. Configured via UserDefaults for enable/disable, voice selection, and "speak on silent" mode. Used throughout the app to provide audio feedback for times and performance.

- **NotificationManager** (`Utils/NotificationManager.swift`): Singleton managing local push notifications using UNUserNotificationCenter. Handles permission requests, schedules weekly summary notifications with training stats, and provides test notification functionality. Configured via UserDefaults for enable/disable, day of week, and time of day.

### Data Layer (SwiftData)
The app uses SwiftData for persistence with a versioned schema approach:

- **Schemas.swift** defines `Schema001` containing all model types: `StringShot`, `StringRun`, `DivisionProfile`, `ShooterProfile`
- **ModelAliases.swift** provides type aliases to the latest schema version (e.g., `typealias StringRun = Schema001.StringRun`)
- Main app creates `ModelContainer` using the versioned schema in `GMJuice.swift:36-49`
- Models use `@Relationship(deleteRule: .cascade)` for parent-child relationships

### Domain Models (Data/)
Non-persisted domain types defining Steel Challenge structure:

- **Division.swift**: Enum of USPSA divisions (RFPO, RFPI, CO, etc.)
- **Stage.swift**: Defines 8 Steel Challenge stages with codes (SC-101 to SC-108) and number of strings
- **ShooterClass.swift**: Classifications (U, D, C, B, A, M, GM) with percentage thresholds
- **PeakBenchmark.swift**: Seed data of GM benchmark times for each division+stage combination. Includes `PeakTable` which calculates performance percentages against benchmarks

### Recording Flow
The core recording workflow ties together BLE, ViewModels, and persistence:

1. User navigates to `RecordingView` with selected stage and division
2. `RecordingViewModel` subscribes to `BLEManager.onBeep` and `BLEManager.onShot` callbacks
3. On beep → creates new `StringRun` and increments counter
4. On shot → appends `StringShot` to current run with now/split/first times
5. When 5 shots recorded → `RecordingView.onChange` inserts run into SwiftData, announces time
6. View displays live performance percentage by comparing to `PeakBenchmarks` based on shooter's classification

### View Layer Organization
- **RootTabs.swift**: Tab navigation with Train, Log, Profile, Settings
- **RecordingView.swift**: Main recording interface with adaptive portrait/landscape layouts. Shows live timer, performance indicators (trophy/thumbs up/down), best/worst times, shots/splits
- **TrainView.swift**: Stage and division selection to start recording
- **LogView.swift**: Historical runs grouped by stage and date
- **ShooterProfileView.swift**: USPSA number and classification management per division
- **SettingsView.swift**: App settings including announcer configuration

### BLE Protocol
The AMG timer uses UART-style BLE service:
- Service UUID: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- Notify characteristic: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
- Write characteristic: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- Device name prefix: "AMG"

Data parsing in `BLEManager.handleData()`:
- Byte[0] = message type (1 for timer events)
- Byte[1] = subtype (3=shot, 5=beep, 8=stop waiting)
- Bytes[4-9] = shot timing data as UInt8 pairs (high/low bytes representing hundredths of seconds)

### Performance Calculation
Performance percentage is calculated in `PeakTable.percent()`:
- For single string: Compare user's time against GM benchmark time for that division+stage
- For "best N of M" strings: Sum recent N strings (excluding slowest), compare to GM benchmark
- Result maps to classification levels via `ShooterClass.shooterClass(percentage:)`
- Display logic in `RecordingView` shows trophy (above class), thumbs up (at class), or thumbs down (below class)

### Audio Feedback
Announcer speaks at key moments:
- RecordingView.onAppear: Announces stage name or "Timer is not connected"
- After 5 shots: Announces final string time
- Trophy achievement: Plays system sound 1309
- Configurable via Settings: enable/disable, voice selection, speak on silent mode

### Notifications
NotificationManager provides both weekly summaries and daily training reminders:

**Weekly Summary:**
- Requests permission in `AppInitializer.start()` on first launch
- Schedules repeating weekly notification based on user-selected day/time (default: Friday 9 AM)
- Generates summary in `generateWeeklySummary()` by querying SwiftData for runs from past 7 days
- Summary includes: total shots fired, best times grouped by division and stage
- Content is refreshed when app goes to background via `updateScheduledNotification()`

**Daily Training Reminder:**
- Schedules recurring notifications for selected days of week (default: Mon-Fri at 8 AM)
- Generates practice suggestions in `generateDailyMessage()` combining:
  - Random motivational prefix ("Time to practice:", "Today's training:", etc.)
  - 2 randomly selected stages via `selectStages()` (extensible for smart selection later)
  - Specific focus areas from `StagePracticeSuggestions` (10-20 tips per stage)
- Example: "You can focus on: Outer Limits, pay attention to round counting for the stop plate and Accelerator, pay attention to explosive first shot from the holster"
- Notification content is regenerated when app backgrounds via `updateDailyNotifications()`
- SettingsView provides: enable toggle, time picker, day-of-week toggles (M-F circular buttons)

**Data Source:**
- `StagePracticeSuggestions.swift` maps each stage code to 10-20 practice focus areas
- Focus areas cover technical (trigger control, sight picture), mental (commitment, focus), and physical (balance, footwork) aspects
- Stage-specific tips like "counting rounds for the stop plate" (SC-104) or "choosing and committing to your sequence" (SC-107)
