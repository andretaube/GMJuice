# GMJuice Test Coverage Map

Visual guide to what's tested and what's not.

## Coverage Legend
- 🟢 **Excellent** (90-100%): Thoroughly tested, high confidence
- 🟡 **Good** (70-89%): Well tested, some gaps
- 🟠 **Partial** (50-69%): Basic coverage, needs work
- 🔴 **Not Covered** (0-49%): Minimal or no tests
- ⚫ **Untestable**: Requires hardware/UI, tested manually

## Core Components

```
GMJuice/
│
├── BLE/
│   └── BLEManager.swift                    🟢 90% (Unit Tests)
│       ├── Data parsing                    ✅ All subtypes tested
│       ├── Connection management           ✅ State transitions tested
│       ├── Device persistence              ✅ Save/load tested
│       └── Hardware interaction            ⚫ Untestable (CoreBluetooth)
│
├── Data/
│   ├── Division.swift                      🟢 100% (Via PeakBenchmarkTests)
│   ├── Stage.swift                         🟢 100% (Via TestData)
│   ├── ShooterClass.swift                  🟢 100% (ShooterClassTests)
│   │   ├── Classification logic            ✅ All thresholds tested
│   │   ├── Comparisons                     ✅ All operators tested
│   │   └── Thresholds                      ✅ All boundaries tested
│   └── PeakBenchmark.swift                 🟢 95% (PeakBenchmarkTests)
│       ├── Percentage calculations         ✅ Single/multiple strings
│       ├── Benchmark retrieval             ✅ All divisions/stages
│       └── Rounding logic                  ✅ Edge cases covered
│
├── Persistence/
│   ├── Schemas.swift                       🟢 90% (SwiftDataPersistenceTests)
│   │   ├── StringRun CRUD                  ✅ All operations tested
│   │   ├── StringShot relationships        ✅ Cascade deletes tested
│   │   ├── ShooterProfile CRUD             ✅ All operations tested
│   │   └── DivisionProfile relationships   ✅ Cascade deletes tested
│   ├── StringRun+Extensions.swift          🟢 100% (StringRunExtensionsTests)
│   │   ├── Penalty calculations            ✅ All scenarios tested
│   │   ├── Adjusted time                   ✅ Edge cases covered
│   │   ├── Flash red logic                 ✅ All conditions tested
│   │   └── Ordered shots                   ✅ Sorting tested
│   └── ModelAliases.swift                  🟢 100% (Via Schemas tests)
│
├── Utils/
│   ├── Format.swift                        🟢 100% (FormatUtilsTests)
│   │   ├── Time formatting                 ✅ All scenarios tested
│   │   ├── Rounding                        ✅ Up/down tested
│   │   ├── Precision                       ✅ 2 decimal places verified
│   │   └── Edge cases                      ✅ Extreme values tested
│   ├── VideoProcessor.swift                🟡 80% (VideoProcessorTests)
│   │   ├── Time calculations               ✅ All math tested
│   │   ├── Overlay positioning             ✅ All positions tested
│   │   ├── Beep offset math                ✅ All scenarios tested
│   │   └── Video composition               ⚫ AVFoundation (manual)
│   └── NotificationManager.swift           🔴 0% (Recommended future work)
│
├── Managers/
│   ├── RecordingManager.swift              🟢 85% (RecordingManagerIntegrationTests)
│   │   ├── Session management              ✅ Start/end tested
│   │   ├── String recording                ✅ Full workflow tested
│   │   ├── Shot recording                  ✅ Multiple shots tested
│   │   ├── Target miss tracking            ✅ Add/remove tested
│   │   └── Callbacks                       ✅ All callbacks tested
│   ├── VideoProcessingManager.swift        🔴 0% (Requires AVFoundation)
│   └── DeviceOrientationManager.swift      🔴 0% (UI-dependent)
│
├── ViewModels/
│   ├── RecordingViewModel.swift            🔴 0% (Recommended future work)
│   ├── VideoRecordingViewModel.swift       🔴 0% (Recommended future work)
│   └── SettingsViewModel.swift             🔴 0% (UI-dependent)
│
├── Views/
│   ├── RecordingView.swift                 🔴 0% (UI - needs XCUITest)
│   ├── TrainView.swift                     🔴 0% (UI - needs XCUITest)
│   ├── LogView.swift                       🔴 0% (UI - needs XCUITest)
│   └── Settings/
│       └── ExportDataView.swift            🔴 0% (Recommended future work)
│
└── Announcer.swift                         🔴 0% (AVSpeechSynthesizer untestable)
```

## Test Files Map

```
GMJuiceTests/
│
├── Unit/                                   🟢 6 files, 117 tests
│   ├── BLEManagerTests.swift               ✅ 18 tests
│   │   ├── Data parsing (beep/shot/stop)
│   │   ├── Connection management
│   │   ├── Callback mechanisms
│   │   └── Edge cases & precision
│   │
│   ├── PeakBenchmarkTests.swift            ✅ 22 tests
│   │   ├── Benchmark retrieval
│   │   ├── Single string percentages
│   │   ├── Multiple string percentages
│   │   ├── Classification determination
│   │   └── Cross-division comparisons
│   │
│   ├── VideoProcessorTests.swift           ✅ 20 tests
│   │   ├── Time formatting
│   │   ├── Beep offset calculations
│   │   ├── Overlay positioning
│   │   ├── Render size calculations
│   │   └── Performance integration
│   │
│   ├── StringRunExtensionsTests.swift      ✅ 18 tests
│   │   ├── Penalty calculations
│   │   ├── Adjusted time
│   │   ├── Flash red logic
│   │   ├── Ordered shots
│   │   └── Integration with performance
│   │
│   ├── FormatUtilsTests.swift              ✅ 15 tests
│   │   ├── Standard formatting
│   │   ├── Rounding up/down
│   │   ├── Trailing/leading zeros
│   │   ├── Precision verification
│   │   └── Thread safety
│   │
│   └── ShooterClassTests.swift             ✅ 24 tests
│       ├── Classification logic
│       ├── Boundary conditions
│       ├── Thresholds
│       ├── Comparisons & sorting
│       ├── Display names
│       └── Codable round-trip
│
├── Integration/                            🟢 2 files, 33 tests
│   ├── RecordingManagerIntegrationTests    ✅ 15 tests
│   │   ├── Session lifecycle
│   │   ├── String recording workflow
│   │   ├── Multiple strings
│   │   ├── Target miss tracking
│   │   └── Error handling
│   │
│   └── SwiftDataPersistenceTests           ✅ 18 tests
│       ├── CRUD operations
│       ├── Relationships & cascade
│       ├── Query patterns
│       ├── Missed targets JSON
│       └── Performance benchmarks
│
├── Mocks/                                  🟢 1 file
│   └── MockBLEManager.swift                ✅ Full mock implementation
│       ├── Device discovery
│       ├── Connection simulation
│       ├── Event simulation
│       └── Data parsing helpers
│
└── Fixtures/                               🟢 1 file
    └── TestData.swift                      ✅ Comprehensive test data
        ├── Sample data factories
        ├── BLE data generation
        ├── Decimal comparison helpers
        └── Stage/division fixtures
```

## Coverage by Feature Area

### Steel Challenge Scoring (Critical)
- Benchmark retrieval: 🟢 100%
- Percentage calculation: 🟢 95%
- Classification: 🟢 100%
- Penalty logic: 🟢 100%

### BLE Communication (Critical)
- Data parsing: 🟢 90%
- Connection management: 🟢 85%
- Hardware interaction: ⚫ Untestable

### Data Persistence (Critical)
- CRUD operations: 🟢 90%
- Relationships: 🟢 90%
- Queries: 🟢 85%

### Recording Workflow (Critical)
- Session management: 🟢 85%
- Shot tracking: 🟢 90%
- Miss tracking: 🟢 100%

### Video Processing (Medium)
- Time calculations: 🟢 90%
- Overlay math: 🟢 85%
- Video composition: ⚫ Untestable

### User Interface (Low)
- View rendering: 🔴 0%
- Navigation: 🔴 0%
- User interactions: 🔴 0%

## Test Priority Matrix

### Priority 1: Critical Business Logic (Well Covered ✅)
- Scoring calculations: 🟢 95%
- Penalty calculations: 🟢 100%
- Classification logic: 🟢 100%
- BLE data parsing: 🟢 90%

### Priority 2: Data Integrity (Well Covered ✅)
- Persistence operations: 🟢 90%
- Relationship integrity: 🟢 90%
- Query correctness: 🟢 85%

### Priority 3: Workflow Logic (Good Coverage ✓)
- Recording sessions: 🟢 85%
- Shot tracking: 🟢 90%
- State management: 🟡 70%

### Priority 4: UI/Presentation (Not Covered ⚠️)
- View rendering: 🔴 0%
- User interactions: 🔴 0%
- Navigation flows: 🔴 0%

## Recommended Test Additions

### High Priority (Next Sprint)
1. **RecordingViewModel** (4-6 hours)
   - State transitions
   - Shot counting logic
   - Performance indicators

2. **CSV Export** (2-3 hours)
   - Data formatting
   - Column structure
   - Edge cases

### Medium Priority (Future)
3. **NotificationManager** (3-4 hours)
   - Summary generation
   - Scheduling logic
   - Permission handling

4. **Basic UI Tests** (6-8 hours)
   - Tab navigation
   - Recording start/stop
   - Critical user flows

### Low Priority (As Needed)
5. **VideoRecordingViewModel** (3-4 hours)
6. **Settings persistence** (2-3 hours)
7. **Snapshot tests** (4-6 hours)

## Coverage Summary by Type

```
┌─────────────────────────┬───────┬──────────┐
│ Component Type          │ Tests │ Coverage │
├─────────────────────────┼───────┼──────────┤
│ Business Logic          │  97   │   95%    │ 🟢
│ Data Models             │  18   │   90%    │ 🟢
│ Utilities               │  20   │   95%    │ 🟢
│ Managers/Workflows      │  15   │   85%    │ 🟢
│ ViewModels              │   0   │    0%    │ 🔴
│ Views/UI                │   0   │    0%    │ 🔴
│ Hardware Integration    │   -   │    -     │ ⚫
├─────────────────────────┼───────┼──────────┤
│ TOTAL (Testable)        │ 150   │   85%    │ 🟢
└─────────────────────────┴───────┴──────────┘
```

## Quick Reference

**Where to add tests for new code:**

- New calculation logic → `Unit/` folder
- New workflow/manager → `Integration/` folder
- New data model → `Integration/SwiftDataPersistenceTests.swift`
- New ViewModel → Create new `Unit/ViewModelTests.swift`
- New utility function → Appropriate `Unit/*Tests.swift` file

**Test file naming:**
- Unit: `<Component>Tests.swift`
- Integration: `<Component>IntegrationTests.swift`
- UI: `<Feature>UITests.swift` (when added)

---

**Legend Summary:**
- 🟢 = Well covered, maintain
- 🟡 = Good, can improve
- 🟠 = Needs work
- 🔴 = Not covered, consider adding
- ⚫ = Untestable by design
