# CLAUDE.md

This file provides comprehensive guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Important Development Directives

### **CRITICAL: Development Process Requirements**
1. **Before writing code, always describe what you're planning to do** - Explain your approach, which files you'll modify, and what changes you'll make
2. **When finished with making any changes, always compile and check for errors** - Run build commands to verify code compiles successfully
3. **Do what has been asked; nothing more, nothing less**
4. **NEVER create files unless they're absolutely necessary for achieving your goal**
5. **ALWAYS prefer editing an existing file to creating a new one**
6. **NEVER proactively create documentation files (*.md) or README files unless explicitly requested**

### Code Guidelines
- Follow existing code conventions and patterns in the codebase
- Use existing libraries and utilities already available
- Check that dependencies are available before using them (look at neighboring files or package.json/Cargo.toml)
- Never introduce code that exposes or logs secrets and keys
- Never commit secrets or keys to the repository
- **DO NOT ADD comments unless specifically asked**
- Run lint and typecheck commands after making changes if available

## Project Overview

GMJuice is an iOS SwiftUI application for tracking Steel Challenge shooting performance. It connects to an AMG timer via Bluetooth Low Energy (BLE) to record shot times, calculate performance percentages against USPSA benchmarks, and provide real-time audio feedback through text-to-speech announcements.

### Key Features
- **BLE Timer Integration**: Connects to AMG shot timers for automatic shot detection
- **Performance Analysis**: Calculates percentages against USPSA GM benchmarks  
- **AI-Powered Coaching**: Uses Claude API for personalized coaching recommendations
- **Firebase Remote Config**: Feature flags for Profile/Analysis tabs and SCSA data control
- **Shot Detection**: Advanced audio analysis for hit/miss detection
- **Video Recording**: Overlay shot data on recorded videos
- **Data Export**: CSV export of shooting data
- **Firebase-Backed Benchmarks**: Remote benchmark data with local fallback

## Build & Development Commands

### Building and Running
```bash
# Build the project
xcodebuild -project GMJuice.xcodeproj -scheme GMJuice -configuration Debug build

# Build for release
xcodebuild -project GMJuice.xcodeproj -scheme GMJuice -configuration Release build

# Clean build
xcodebuild -project GMJuice.xcodeproj -scheme GMJuice clean

# Build for simulator
xcodebuild -project GMJuice.xcodeproj -scheme GMJuice -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### Running Tests
```bash
# Run all tests
xcodebuild test -project GMJuice.xcodeproj -scheme GMJuice -destination 'platform=iOS Simulator,name=iPhone 15'

# Run with code coverage
xcodebuild test -project GMJuice.xcodeproj -scheme GMJuice -destination 'platform=iOS Simulator,name=iPhone 15' -enableCodeCoverage YES
```

**Note:** This project is best developed in Xcode. Open `GMJuice.xcodeproj` in Xcode for the full development experience including simulator testing and debugging.

## Architecture

### Core Singletons
The app uses main singleton managers that coordinate throughout the app:

- **BLEManager** (`BLE/BLEManager.swift`): Singleton managing Bluetooth connection to AMG shot timer. Handles device discovery, connection persistence via UserDefaults, and parsing shot data from BLE notifications. Publishes connection status and provides callbacks for beep events, shot events, and disconnection.

- **Announcer** (`Announcer.swift`): Singleton managing text-to-speech announcements using AVSpeechSynthesizer. Configured via UserDefaults for enable/disable, voice selection, and "speak on silent" mode. Used throughout the app to provide audio feedback for times and performance.

- **NotificationManager** (`Utils/NotificationManager.swift`): Singleton managing local push notifications using UNUserNotificationCenter. Handles permission requests, schedules weekly summary notifications with training stats, and provides test notification functionality. Configured via UserDefaults for enable/disable, day of week, and time of day.

- **RemoteConfigService** (`Firebase/RemoteConfigService.swift`): Singleton managing Firebase Remote Config for feature flags and remote data. Controls Profile/Analysis tab visibility, SCSA data operations, Claude AI features, and benchmark data.

- **PeakBenchmarksService** (`Firebase/PeakBenchmarksService.swift`): Singleton managing Firebase-backed benchmark data with local fallback. Provides `CurrentPeakBenchmarks` for performance calculations.

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
- **PeakBenchmark.swift**: Seed data of GM benchmark times for each division+stage combination. Includes `PeakTable` which calculates performance percentages against benchmarks. **Important**: Use `CurrentPeakBenchmarks` instead of `PeakBenchmarks` for Firebase-backed data.

### Recording Flow
The core recording workflow ties together BLE, ViewModels, and persistence:

1. User navigates to `RecordingView` with selected stage and division (forces landscape orientation)
2. `RecordingViewModel` subscribes to `BLEManager.onBeep` and `BLEManager.onShot` callbacks
3. On beep → creates new `StringRun` and increments counter
4. On shot → appends `StringShot` to current run with now/split/first times
5. When 5 shots recorded → `RecordingView.onChange` inserts run into SwiftData, announces time
6. View displays live performance percentage by comparing to `CurrentPeakBenchmarks` (Firebase-backed) based on shooter's classification
7. On exit → restores portrait-only orientation

### View Layer Organization
- **RootTabs.swift**: Tab navigation with Train, Log, Profile, Settings. Profile/Analysis tabs controlled by Firebase Remote Config with smart fallback logic.
- **RecordingView.swift**: Main recording interface with automatic landscape orientation. Shows live timer, performance indicators (trophy/thumbs up/down), best/worst times, shots/splits
- **TrainView.swift**: Stage and division selection to start recording
- **LogView.swift**: Historical runs grouped by stage and date
- **ProfileView.swift**: USPSA number and classification management per division. SCSA sync controls based on Remote Config.
- **SettingsView.swift**: App settings including announcer configuration

### Firebase Remote Config Integration
Controls app features via remote configuration:

#### Remote Config Parameters:
- **ProfileEnabled**: Controls Profile tab visibility
- **AnalysisEnabled**: Controls Analysis tab visibility (with smart fallback)  
- **SCSADataEnabled**: Controls SCSA data scraping operations
- **ClaudeAIEnabled**: Controls Claude AI features with graceful degradation
- **peak_benchmarks**: JSON data for remote benchmark updates

#### Usage Patterns:
```swift
// Check feature flags
if RemoteConfigService.shared.isProfileEnabled { ... }
if RemoteConfigService.shared.isSCSADataEnabled { ... }
if RemoteConfigService.shared.isClaudeAIEnabled { ... }

// Use Firebase-backed benchmarks
let percentage = CurrentPeakBenchmarks.percent(division: division, stageCode: stage.code, time: time)
```

#### Tab Visibility Logic:
| ProfileEnabled | AnalysisEnabled | Profile Tab | Analysis Tab | Notes |
|---------------|----------------|-------------|--------------|--------|
| ✅ true | ✅ true | Show | Show | Both tabs visible |
| ✅ true | ❌ false | Show | Hide | Only Profile visible |
| ❌ false | ✅ true | Hide | Show | Analysis overrides setting |
| ❌ false | ❌ false | Hide | Show | Analysis forced enabled |

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
- **Important**: Always use `CurrentPeakBenchmarks` for Firebase-backed data instead of `PeakBenchmarks`

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

## Test Framework

### Overview
Comprehensive test framework with 150+ tests covering 85%+ of business logic.

### Test Structure
```
GMJuiceTests/
├── Unit/                       # 6 files, 117 tests
│   ├── BLEManagerTests.swift           # BLE data parsing & connection
│   ├── PeakBenchmarkTests.swift        # Performance calculations
│   ├── VideoProcessorTests.swift       # Video processing utilities
│   ├── StringRunExtensionsTests.swift  # Penalty calculations
│   ├── FormatUtilsTests.swift          # Time formatting
│   └── ShooterClassTests.swift         # Classification logic
├── Integration/                # 2 files, 33 tests
│   ├── RecordingManagerIntegrationTests.swift  # Recording sessions
│   └── SwiftDataPersistenceTests.swift         # Database operations
├── Mocks/                      # Mock objects for testing
│   └── MockBLEManager.swift            # Mock BLE timer
└── Fixtures/                   # Test data and utilities
    └── TestData.swift                  # Sample data, helpers
```

### Test Coverage
- **Excellent Coverage (90-100%)**: PeakBenchmarks, StringRun Extensions, Format Utils, ShooterClass
- **Strong Coverage (80-90%)**: BLEManager, RecordingManager, SwiftData Models
- **Good Coverage (70-80%)**: VideoProcessor

### Key Test Patterns
```swift
// Decimal testing with tolerance
XCTAssertTrue(assertDecimalEqual(result, expected, tolerance: 0.01))

// Async testing
let expectation = expectation(description: "Callback fired")
manager.onCompleted = { expectation.fulfill() }
await fulfillment(of: [expectation], timeout: 1.0)

// SwiftData testing with in-memory container
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(for: schema, configurations: config)
```

## API Configuration

### Anthropic API Setup
The app uses the Anthropic API for AI-powered coaching features.

1. **Get API Key**: Visit https://console.anthropic.com/settings/keys
2. **Configure locally**: Edit `Config.xcconfig`:
   ```
   ANTHROPIC_API_KEY = sk-ant-api03-your-actual-key-here
   ```
3. **Link in Xcode**: Project > Info > Configurations > Select `Config` for Debug/Release
4. **How it works**: `Config.xcconfig` → Build-time injection → `Info.plist` → Runtime access

### Firebase Setup
1. **Remote Config Parameters**: Configure in Firebase Console:
   - `ProfileEnabled` (Boolean, default: true)
   - `AnalysisEnabled` (Boolean, default: true) 
   - `SCSADataEnabled` (Boolean, default: true)
   - `ClaudeAIEnabled` (Boolean, default: true)
   - `peak_benchmarks` (JSON, use `PeakBenchmarksService.shared.generateFirebaseJSON()`)

## Shot Detection Calibration

### Overview
Calibration system for tuning shot detection to specific shooting environments.

### Process
1. **Access**: Settings → Shot Detection → Calibrate Detection
2. **Distance Selection**: Close/Medium/Far/Very Far (7-25+ yards)
3. **Fire and Label**: Live fire → Mark as HIT/MISS
4. **Collect Data**: Minimum 10 hits + 10 misses (recommended 15-20 each)
5. **Analyze**: Algorithm calculates optimal thresholds
6. **Apply**: Use new thresholds or discard

### Key Metrics
- **Secondary Amplitude Ratio**: Primary hit/miss detection metric
  - Hits: 0.40-0.95 (gunshot + steel ding)
  - Misses: <0.25 (gunshot only)
- **Good Calibration**: High separation (>0.40), High confidence (>80%)
- **Warning Signs**: Low separation (<0.20), Low confidence (<50%)

### Best Practices
- Be honest with hit/miss labeling
- Vary distances for comprehensive calibration
- Use consistent microphone position
- Collect 20+ samples of each type for reliability
- Recalibrate when changing ranges or setup

## Development Patterns

### Firebase Remote Config Usage
```swift
// Feature flags
guard RemoteConfigService.shared.isSCSADataEnabled else { return }
guard RemoteConfigService.shared.isClaudeAIEnabled else { /* graceful degradation */ }

// Firebase-backed benchmarks (ALWAYS use this instead of PeakBenchmarks)
let percentage = CurrentPeakBenchmarks.percent(division: division, stageCode: stage.code, time: time)
```

### Error Handling
- SCSA operations: Guard with Remote Config checks
- Claude AI: Graceful degradation to statistical analysis
- BLE: Mock for testing, real hardware for production

### Orientation Management
- **RecordingView**: Forces landscape on appear, restores portrait on disappear
- **All other views**: Portrait-only
- **Implementation**: `AppDelegate.orientationLock` + `UIDevice.setValue` + `requestGeometryUpdate`

### Testing Guidelines
- Add tests for new features and business logic
- Use in-memory containers for SwiftData testing  
- Follow existing patterns: `test<Component>_<Scenario>_<ExpectedOutcome>`
- Maintain >80% coverage for business logic
- Use `@testable import GMJuice` for accessing internal components

---

**Last Updated**: November 23, 2025
**Compatible with**: iOS 18+, Xcode 16+, Firebase 12.6+