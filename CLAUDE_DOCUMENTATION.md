# GMJuice - Claude Development Documentation

This comprehensive document consolidates all Claude Code development guidance and documentation for the GMJuice iOS app.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Development Commands](#development-commands)
4. [Firebase Configuration](#firebase-configuration)
5. [Test Framework](#test-framework)
6. [Setup Instructions](#setup-instructions)
7. [Shot Detection Calibration](#shot-detection-calibration)

---

## Project Overview

GMJuice is an iOS SwiftUI application for tracking Steel Challenge shooting performance. It connects to an AMG timer via Bluetooth Low Energy (BLE) to record shot times, calculate performance percentages against USPSA benchmarks, and provide real-time audio feedback through text-to-speech announcements.

### Key Features
- **BLE Timer Integration**: Connects to AMG shot timers for automatic shot detection
- **Performance Analysis**: Calculates percentages against USPSA GM benchmarks
- **AI-Powered Coaching**: Uses Claude API for personalized coaching recommendations
- **Firebase Remote Config**: Feature flags for Profile/Analysis tabs and SCSA data
- **Shot Detection**: Advanced audio analysis for hit/miss detection
- **Video Recording**: Overlay shot data on recorded videos
- **Data Export**: CSV export of shooting data

---

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
- **PeakBenchmark.swift**: Seed data of GM benchmark times for each division+stage combination. Includes `PeakTable` which calculates performance percentages against benchmarks. Now supports Firebase Remote Config for remote benchmark updates.

### Recording Flow
The core recording workflow ties together BLE, ViewModels, and persistence:

1. User navigates to `RecordingView` with selected stage and division
2. `RecordingViewModel` subscribes to `BLEManager.onBeep` and `BLEManager.onShot` callbacks
3. On beep → creates new `StringRun` and increments counter
4. On shot → appends `StringShot` to current run with now/split/first times
5. When 5 shots recorded → `RecordingView.onChange` inserts run into SwiftData, announces time
6. View displays live performance percentage by comparing to `CurrentPeakBenchmarks` (Firebase-backed) based on shooter's classification

### View Layer Organization
- **RootTabs.swift**: Tab navigation with Train, Log, Profile, Settings (Profile/Analysis tabs controlled by Firebase Remote Config)
- **RecordingView.swift**: Main recording interface with automatic landscape orientation. Shows live timer, performance indicators (trophy/thumbs up/down), best/worst times, shots/splits
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

---

## Development Commands

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

**Note:** This project is best developed in Xcode. Open `GMJuice.xcodeproj` in Xcode for the full development experience including simulator testing and debugging.

### Running Tests
```bash
# Run all tests
xcodebuild test -project GMJuice.xcodeproj -scheme GMJuice -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -project GMJuice.xcodeproj -scheme GMJuice -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:GMJuiceTests/BLEManagerTests

# Run with code coverage
xcodebuild test -project GMJuice.xcodeproj -scheme GMJuice -destination 'platform=iOS Simulator,name=iPhone 15' -enableCodeCoverage YES
```

---

## Firebase Configuration

### Current Status ✅
Firebase Remote Config is **FULLY IMPLEMENTED** with real Firebase SDK!

### What's Implemented ✅
- ✅ `RemoteConfigService` - Complete service with real Firebase Remote Config
- ✅ `PeakBenchmarksService` - Firebase-backed benchmark data with local fallback
- ✅ `RemoteConfigKey` enum for type-safe key management
- ✅ Profile tab conditional visibility in `RootTabs`
- ✅ Analysis tab conditional visibility with smart fallback logic
- ✅ SCSA data import controls across all scraping operations
- ✅ Claude AI controls with graceful degradation to statistical analysis
- ✅ Debug controls in Settings (DEBUG builds only)
- ✅ Integration with app startup in `AppInitializer`

### Remote Config Parameters

Configure these parameters in Firebase Console:

1. **Profile Tab Control:**
   - **Parameter key:** `ProfileEnabled`
   - **Data type:** Boolean
   - **Default value:** `true`

2. **Analysis Tab Control:**
   - **Parameter key:** `AnalysisEnabled`
   - **Data type:** Boolean
   - **Default value:** `true`

3. **SCSA Data Control:**
   - **Parameter key:** `SCSADataEnabled`
   - **Data type:** Boolean
   - **Default value:** `true`

4. **Claude AI Control:**
   - **Parameter key:** `ClaudeAIEnabled`
   - **Data type:** Boolean
   - **Default value:** `true`

5. **Peak Benchmarks Data:**
   - **Parameter key:** `peak_benchmarks`
   - **Data type:** JSON
   - **Default value:** Use `PeakBenchmarksService.shared.generateFirebaseJSON()` to get the JSON

### Tab Visibility Logic
| ProfileEnabled | AnalysisEnabled | Profile Tab | Analysis Tab | Notes |
|---------------|----------------|-------------|--------------|--------|
| ✅ true | ✅ true | Show | Show | Both tabs visible |
| ✅ true | ❌ false | Show | Hide | Only Profile visible |
| ❌ false | ✅ true | Hide | Show | Analysis overrides setting |
| ❌ false | ❌ false | Hide | Show | Analysis forced enabled |

**Key:** When Profile is disabled, Analysis is always enabled regardless of AnalysisEnabled setting.

---

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
├── Fixtures/                   # Test data and utilities
│   └── TestData.swift                  # Sample data, helpers
└── README.md                   # Comprehensive documentation
```

### Test Coverage by Component

#### Excellent Coverage (90-100%)
- **PeakBenchmarks**: ~95% coverage
- **StringRun Extensions**: ~100% coverage  
- **Format Utils**: ~100% coverage
- **ShooterClass**: ~100% coverage

#### Strong Coverage (80-90%)
- **BLEManager**: ~90% coverage (parsing logic)
- **RecordingManager**: ~85% coverage (workflow)
- **SwiftData Models**: ~90% coverage

#### Good Coverage (70-80%)
- **VideoProcessor**: ~80% coverage (utilities)

### Running Tests in Xcode

#### One-Time Setup (Required)
1. Open `GMJuice.xcodeproj` in Xcode
2. Add Test Target: File > New > Target > Unit Testing Bundle
3. Name: `GMJuiceTests`, Target: `GMJuice`
4. Add test files to target with proper membership
5. Enable testability in Build Settings

#### Running Tests
- `⌘U` - Run all tests
- Click diamond icon - Run specific test/file
- Product > Scheme > Edit Scheme > Test > Enable Code Coverage

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

---

## Setup Instructions

### API Key Configuration

The app uses the Anthropic API for AI-powered coaching features.

#### 1. Get Your API Key
1. Visit https://console.anthropic.com/settings/keys
2. Create a new API key (starts with `sk-ant-api03-...`)
3. Copy the key

#### 2. Configure the Key Locally

Edit `Config.xcconfig`:
```bash
# Replace with your actual API key
ANTHROPIC_API_KEY = sk-ant-api03-your-actual-key-here
```

#### 3. Link Config File in Xcode (One-time setup)

1. Open `GMJuice.xcodeproj` in Xcode
2. Select the project in the navigator
3. In the "Info" tab, find "Configurations" section
4. For both **Debug** and **Release**:
   - Under "GMJuice" target, select `Config` from dropdown

#### 4. Verify Setup

Build and run the app. The `CoachingService` will read the key from the build-time injected `Info.plist`.

### How It Works

- `Config.xcconfig` defines `ANTHROPIC_API_KEY = your-key`
- At build time, Xcode injects this into `Info.plist`
- `Info.plist` contains `<string>$(ANTHROPIC_API_KEY)</string>`
- The app reads the resolved value at runtime
- `Config.xcconfig` is in `.gitignore` so your key stays secret

---

## Shot Detection Calibration

### Overview

The calibration system allows you to tune the shot detection algorithm to your specific shooting environment. Every range is different, and factors like microphone position, target distances, target types, and ambient noise all affect detection accuracy.

### Why Calibrate?

While the default thresholds are based on real-world data (7 hits and 2 misses), your setup may differ:
- **Different distances**: Outer Limits has 25+ yard shots vs. 7-yard close shots
- **Different targets**: Size and material affect the "ding" sound
- **Different microphone**: Position relative to shooter and targets
- **Different environment**: Indoor vs. outdoor, noise levels

### How to Use

#### 1. Access Calibration
```
Settings → Shot Detection → Calibrate Detection
```

#### 2. Follow the Wizard

**Step 1: Introduction**
- Read the instructions
- Understand the requirements (minimum 10 hits, 10 misses)
- Tap "Start Calibration"

**Step 2: Distance Selection**
- Choose the distance to your target:
  - Close (7-10 yards)
  - Medium (10-15 yards)
  - Far (15-25 yards)
  - Very Far (25+ yards)
- Tap "Ready to Fire"

**Step 3: Fire and Label**
1. App displays "Listening..." with pulsing waveform icon
2. **Fire your shot** (live fire required!)
3. App automatically detects the shot
4. Displays acoustic analysis (ratio, delay)
5. **Mark the shot**:
   - Tap green "HIT" if you hit the steel
   - Tap red "MISS" if you missed
6. App returns to distance selection

**Step 4: Repeat**
- Continue firing and labeling shots
- Progress badges show: Hits ✓ / Misses ✓
- Mix distances for comprehensive calibration
- Minimum: 10 hits + 10 misses
- Recommended: 15-20 of each for better accuracy

**Step 5: Analyze**
- When minimum requirements met, "Finish & Analyze" button appears
- Tap to analyze your data
- View detailed statistics

**Step 6: Review Results**
The analysis shows:
- **Total samples**: Number of shots collected
- **Hit ratio range**: Min, max, and average secondary amplitude ratios for hits
- **Miss ratio range**: Min, max, and average for misses
- **Recommended threshold**: Calculated optimal value
- **Separation**: Distance between hit and miss averages (higher = better)
- **Confidence**: 0-100% based on data quality

**Step 7: Apply or Discard**
- Tap "Apply Calibration" to use the new thresholds
- Or tap "Done" to discard and keep current settings

### Understanding the Data

#### Secondary Amplitude Ratio
The key metric for hit vs. miss detection:
- **Hits**: Two spikes (gunshot + steel ding), ratio typically 0.40-0.95
- **Misses**: One spike (gunshot only), ratio typically <0.25

#### Good Calibration Indicators
✅ **High separation** (>0.40): Clear distinction between hits and misses
✅ **High confidence** (>80%): Minimal overlap between hit and miss ranges
✅ **Consistent ranges**: Tight min-max spread within each category

#### Warning Signs
⚠️ **Low separation** (<0.20): Overlapping ranges, may need more samples
⚠️ **Low confidence** (<50%): Inconsistent data, check microphone position
⚠️ **Wide ranges**: Large variation, may need to separate by distance

### Best Practices

#### Sample Collection
1. **Be honest**: Label shots accurately (it's for training, not bragging!)
2. **Vary distances**: Include shots from different ranges
3. **Consistent setup**: Use the same microphone position throughout
4. **Minimize noise**: Avoid calibrating on a busy range if possible
5. **More is better**: 20+ of each gives more reliable thresholds

#### When to Recalibrate
- Moving to a new range
- Changing microphone position
- Different target setup
- Detection seems inaccurate
- Every few months as a tune-up

#### Pro Tips
- Calibrate at the range you use most
- Start with medium distance, then add close/far
- If you shoot Outer Limits often, include "very far" samples
- Save multiple calibration sessions for different ranges
- Test after calibration: fire 5 known hits/misses and verify

### Technical Details

#### Data Collected Per Shot
- Peak amplitude
- Secondary amplitude ratio (primary metric)
- Delay between gunshot and steel ding (ms)
- High frequency energy (>2kHz)
- RMS energy

#### Threshold Calculation
```
Optimal threshold = missAvg + (separation × 0.6)
```
- Places threshold 60% of the way from miss average to hit average
- Biased toward avoiding false positives (better to miss a hit than call a miss a hit)
- Confidence based on minimum separation between hit min and miss max

#### Storage
- All calibration sessions saved to UserDefaults
- Can view previous sessions (future feature)
- Persists across app restarts

### Troubleshooting

#### "Not detecting shots"
- Ensure Shot Detection is enabled in Settings
- Check microphone permissions
- Increase sensitivity slider
- Verify timer is reporting shots (BLE connection)

#### "Ratios all very low (<0.20)"
- Microphone too far from targets
- Targets too far away
- Try closer distances first
- Check if steel plates are making audible "ding"

#### "Ratios all very high (>0.80) even for misses"
- Microphone too close to targets
- Background noise creating false secondary peaks
- Move microphone farther from targets
- Calibrate in quieter conditions

#### "Inconsistent results"
- Collect more samples (30+ each)
- Ensure consistent microphone position
- Separate by distance (calibrate each distance separately - future feature)
- Check for environmental factors (wind, other shooters)

---

## Important Instructions

### Code Guidelines
- **Do what has been asked; nothing more, nothing less**
- **NEVER create files unless they're absolutely necessary for achieving your goal**
- **ALWAYS prefer editing an existing file to creating a new one**
- **NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User**

### Development Practices
- Follow existing code conventions and patterns
- Use existing libraries and utilities already in the codebase
- Check that dependencies are available before using them
- Never commit secrets or API keys to the repository
- DO NOT ADD comments unless specifically asked
- Run lint and typecheck commands after making changes if available

### Firebase Remote Config Usage
- Use `RemoteConfigService.shared.isProfileEnabled` for Profile tab visibility
- Use `RemoteConfigService.shared.isAnalysisEnabled` for Analysis tab visibility (with smart fallback)
- Use `RemoteConfigService.shared.isSCSADataEnabled` to guard SCSA data operations
- Use `RemoteConfigService.shared.isClaudeAIEnabled` to control Claude AI features
- Use `CurrentPeakBenchmarks` instead of `PeakBenchmarks` for Firebase-backed benchmark data

### Testing
- Add tests for new features and business logic
- Use in-memory containers for SwiftData testing
- Follow existing test patterns and naming conventions
- Maintain >80% coverage for business logic
- Use `@testable import GMJuice` for accessing internal components

---

**Last Updated**: November 23, 2025
**Compatible with**: iOS 18+, Xcode 16+, Firebase 12.6+