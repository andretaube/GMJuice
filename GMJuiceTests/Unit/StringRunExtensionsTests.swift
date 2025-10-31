//
//  StringRunExtensionsTests.swift
//  GMJuiceTests
//
//  Unit tests for StringRun penalty calculations and extensions
//

import XCTest
@testable import GMJuice

final class StringRunExtensionsTests: XCTestCase {

    // MARK: - Penalty Calculation Tests

    func testCalculatePenalty_NoMisses() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.missedTargets = []

        // When
        let (penalty, shouldFlash) = stringRun.calculatePenalty()

        // Then
        XCTAssertEqual(penalty, 0, "No misses should give zero penalty")
        XCTAssertFalse(shouldFlash, "No misses should not flash")
    }

    func testCalculatePenalty_OnePlateMiss() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.missedTargets = [2]  // Miss target 2

        // When
        let (penalty, shouldFlash) = stringRun.calculatePenalty()

        // Then
        XCTAssertEqual(penalty, 3, "One plate miss should be 3 seconds")
        XCTAssertFalse(shouldFlash, "3 second penalty should not flash")
    }

    func testCalculatePenalty_TwoPlateMisses() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.missedTargets = [2, 4]  // Miss targets 2 and 4

        // When
        let (penalty, shouldFlash) = stringRun.calculatePenalty()

        // Then
        XCTAssertEqual(penalty, 6, "Two plate misses should be 6 seconds")
        XCTAssertFalse(shouldFlash, "6 second penalty should not flash")
    }

    func testCalculatePenalty_ThreePlateMisses() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.missedTargets = [1, 2, 3]  // Miss three plates

        // When
        let (penalty, shouldFlash) = stringRun.calculatePenalty()

        // Then
        XCTAssertEqual(penalty, 9, "Three plate misses should be 9 seconds")
        XCTAssertFalse(shouldFlash, "9 second penalty should not flash")
    }

    func testCalculatePenalty_FourPlateMisses() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.missedTargets = [1, 2, 3, 4]  // Miss all four plates

        // When
        let (penalty, shouldFlash) = stringRun.calculatePenalty()

        // Then
        XCTAssertEqual(penalty, 12, "Four plate misses should be 12 seconds")
        XCTAssertFalse(shouldFlash, "12 second penalty should not flash")
    }

    func testCalculatePenalty_StopPlateMiss() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.missedTargets = [5]  // Miss stop plate (target 5)

        // When
        let (penalty, shouldFlash) = stringRun.calculatePenalty()

        // Then
        XCTAssertEqual(penalty, 30, "Stop plate miss should be 30 seconds")
        XCTAssertTrue(shouldFlash, "30 second penalty should flash red")
    }

    func testCalculatePenalty_StopPlatePlusOthers() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.missedTargets = [2, 4, 5]  // Miss two plates and stop plate

        // When
        let (penalty, shouldFlash) = stringRun.calculatePenalty()

        // Then
        // Would be 3 + 3 + 30 = 36, but capped at 30
        XCTAssertEqual(penalty, 30, "Penalty should be capped at 30 seconds")
        XCTAssertTrue(shouldFlash, "Should flash for max penalty")
    }

    func testCalculatePenalty_MaxPenalty() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.missedTargets = [1, 2, 3, 4, 5]  // Miss everything

        // When
        let (penalty, shouldFlash) = stringRun.calculatePenalty()

        // Then
        // Would be 3 + 3 + 3 + 3 + 30 = 42, but capped at 30
        XCTAssertEqual(penalty, 30, "Penalty should be capped at 30 seconds")
        XCTAssertTrue(shouldFlash, "Should flash for max penalty")
    }

    func testCalculatePenalty_TenPlateMisses() throws {
        // Given - edge case: exactly 10 plate misses (30 seconds)
        let stringRun = TestData.createStringRun()
        // Simulating 10 misses by adding duplicate entries (unrealistic but tests the math)
        stringRun.missedTargets = [1, 2, 3, 4, 1, 2, 3, 4, 1, 2]  // 10 misses = 30 seconds

        // When
        let (penalty, shouldFlash) = stringRun.calculatePenalty()

        // Then
        XCTAssertEqual(penalty, 30, "10 plate misses should equal 30 seconds")
        XCTAssertTrue(shouldFlash, "30 second penalty should flash")
    }

    // MARK: - Adjusted Time Tests

    func testAdjustedTime_NoMisses() throws {
        // Given
        let stringRun = TestData.createStringRun(time: 5.0)
        stringRun.missedTargets = []

        // When
        let adjustedTime = stringRun.adjustedTime

        // Then
        XCTAssertEqual(adjustedTime, 5.0, "Adjusted time should equal raw time with no misses")
    }

    func testAdjustedTime_OnePlateMiss() throws {
        // Given
        let stringRun = TestData.createStringRun(time: 5.0)
        stringRun.missedTargets = [2]

        // When
        let adjustedTime = stringRun.adjustedTime

        // Then
        XCTAssertEqual(adjustedTime, 8.0, "Adjusted time should be 5.0 + 3.0 = 8.0")
    }

    func testAdjustedTime_StopPlateMiss() throws {
        // Given
        let stringRun = TestData.createStringRun(time: 5.0)
        stringRun.missedTargets = [5]

        // When
        let adjustedTime = stringRun.adjustedTime

        // Then
        XCTAssertEqual(adjustedTime, 30.0, "Adjusted time should be capped at 30.0")
    }

    func testAdjustedTime_ExceedsCap() throws {
        // Given
        let stringRun = TestData.createStringRun(time: 25.0)
        stringRun.missedTargets = [1, 2, 3]  // 9 seconds penalty

        // When
        let adjustedTime = stringRun.adjustedTime

        // Then
        // Would be 25.0 + 9.0 = 34.0, but capped at 30.0
        XCTAssertEqual(adjustedTime, 30.0, "Adjusted time should be capped at 30.0")
    }

    func testAdjustedTime_FastTimeWithMisses() throws {
        // Given
        let stringRun = TestData.createStringRun(time: 2.0)
        stringRun.missedTargets = [3]

        // When
        let adjustedTime = stringRun.adjustedTime

        // Then
        XCTAssertEqual(adjustedTime, 5.0, "Fast time with miss: 2.0 + 3.0 = 5.0")
    }

    // MARK: - Flash Red Tests

    func testShouldFlashRed_NoMisses() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.missedTargets = []

        // When
        let shouldFlash = stringRun.shouldFlashRed

        // Then
        XCTAssertFalse(shouldFlash, "Should not flash with no misses")
    }

    func testShouldFlashRed_SmallPenalty() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.missedTargets = [2]

        // When
        let shouldFlash = stringRun.shouldFlashRed

        // Then
        XCTAssertFalse(shouldFlash, "Should not flash with small penalty")
    }

    func testShouldFlashRed_StopPlateMiss() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.missedTargets = [5]

        // When
        let shouldFlash = stringRun.shouldFlashRed

        // Then
        XCTAssertTrue(shouldFlash, "Should flash with stop plate miss")
    }

    func testShouldFlashRed_TenPlateMisses() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.missedTargets = [1, 2, 3, 4, 1, 2, 3, 4, 1, 2]  // 30 seconds

        // When
        let shouldFlash = stringRun.shouldFlashRed

        // Then
        XCTAssertTrue(shouldFlash, "Should flash with 30 second penalty")
    }

    // MARK: - Ordered Shots Tests

    func testOrderedStringShots_AlreadyOrdered() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.stringShots = [
            StringShot(now: 0.5, split: 0.5, first: 0.5),
            StringShot(now: 1.0, split: 0.5, first: 0.5),
            StringShot(now: 1.5, split: 0.5, first: 0.5)
        ]

        // When
        let ordered = stringRun.orderedStringShots

        // Then
        XCTAssertEqual(ordered.count, 3, "Should have 3 shots")
        XCTAssertEqual(ordered[0].now, 0.5, "First shot should be 0.5")
        XCTAssertEqual(ordered[1].now, 1.0, "Second shot should be 1.0")
        XCTAssertEqual(ordered[2].now, 1.5, "Third shot should be 1.5")
    }

    func testOrderedStringShots_NeedsSorting() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.stringShots = [
            StringShot(now: 1.5, split: 0.5, first: 0.5),
            StringShot(now: 0.5, split: 0.5, first: 0.5),
            StringShot(now: 1.0, split: 0.5, first: 0.5)
        ]

        // When
        let ordered = stringRun.orderedStringShots

        // Then
        XCTAssertEqual(ordered.count, 3, "Should have 3 shots")
        XCTAssertEqual(ordered[0].now, 0.5, "First shot should be earliest")
        XCTAssertEqual(ordered[1].now, 1.0, "Second shot should be middle")
        XCTAssertEqual(ordered[2].now, 1.5, "Third shot should be latest")
    }

    func testOrderedStringShots_EmptyArray() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.stringShots = []

        // When
        let ordered = stringRun.orderedStringShots

        // Then
        XCTAssertEqual(ordered.count, 0, "Should return empty array")
    }

    func testOrderedStringShots_SingleShot() throws {
        // Given
        let stringRun = TestData.createStringRun()
        stringRun.stringShots = [
            StringShot(now: 1.0, split: 0.5, first: 0.5)
        ]

        // When
        let ordered = stringRun.orderedStringShots

        // Then
        XCTAssertEqual(ordered.count, 1, "Should have 1 shot")
        XCTAssertEqual(ordered[0].now, 1.0, "Shot should be preserved")
    }

    func testOrderedStringShots_IdenticalTimes() throws {
        // Given - edge case: multiple shots with same time (shouldn't happen but test it)
        let stringRun = TestData.createStringRun()
        stringRun.stringShots = [
            StringShot(now: 1.0, split: 0.5, first: 0.5),
            StringShot(now: 1.0, split: 0.3, first: 0.5),
            StringShot(now: 1.0, split: 0.4, first: 0.5)
        ]

        // When
        let ordered = stringRun.orderedStringShots

        // Then
        XCTAssertEqual(ordered.count, 3, "Should have all 3 shots")
        XCTAssertTrue(ordered.allSatisfy { $0.now == 1.0 }, "All shots should have same time")
    }

    // MARK: - Integration Tests (Penalty + Performance)

    func testPenaltyAffectsPerformance() throws {
        // Given - fast time but with a miss
        let stringRun = TestData.createStringRun(
            stageId: "SC-101",
            divisionId: "RFPO",
            time: 2.0  // Very fast
        )
        stringRun.missedTargets = [2]  // But missed a plate

        let division = Division.RFPO
        let stageCode = "SC-101"

        // When
        let rawPercent = PeakBenchmarks.percent(
            division: division,
            stageCode: stageCode,
            time: stringRun.time
        )
        let adjustedPercent = PeakBenchmarks.percent(
            division: division,
            stageCode: stageCode,
            time: stringRun.adjustedTime
        )

        // Then
        XCTAssertGreaterThan(rawPercent, adjustedPercent, "Penalty should reduce performance")
        XCTAssertGreaterThan(
            rawPercent,
            95,
            "Raw time should be GM level"
        )
        XCTAssertLessThan(
            adjustedPercent,
            95,
            "Adjusted time with penalty should drop below GM"
        )
    }

    func testMultipleMissesStackPenalties() throws {
        // Given
        let stringRun = TestData.createStringRun(time: 3.0)

        // When - progressively add misses
        stringRun.missedTargets = [1]
        let penalty1 = stringRun.calculatePenalty().penalty

        stringRun.missedTargets = [1, 2]
        let penalty2 = stringRun.calculatePenalty().penalty

        stringRun.missedTargets = [1, 2, 3]
        let penalty3 = stringRun.calculatePenalty().penalty

        // Then
        XCTAssertEqual(penalty1, 3, "One miss = 3 seconds")
        XCTAssertEqual(penalty2, 6, "Two misses = 6 seconds")
        XCTAssertEqual(penalty3, 9, "Three misses = 9 seconds")
    }
}
