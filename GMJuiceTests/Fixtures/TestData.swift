//
//  TestData.swift
//  GMJuiceTests
//
//  Test fixtures and sample data for unit tests
//

import Foundation
@testable import GMJuice

struct TestData {

    // MARK: - Stages

    static let stage_5ToGo = Stage(code: "SC-101", name: "5 To Go", strings: 5)
    static let stage_Showdown = Stage(code: "SC-102", name: "Showdown", strings: 5)
    static let stage_OuterLimits = Stage(code: "SC-104", name: "Outer Limits", strings: 4)

    // MARK: - Divisions

    static let allDivisions: [Division] = Division.allCases

    // MARK: - StringShot Data

    /// Create a sample StringShot
    static func createStringShot(
        now: Decimal = 2.5,
        split: Decimal = 0.5,
        first: Decimal = 0.75
    ) -> StringShot {
        return StringShot(now: now, split: split, first: first)
    }

    /// Create a sample string run with 5 shots
    static func createStringRun(
        stageId: String = "SC-101",
        divisionId: String = "RFPO",
        time: Decimal = 2.50,
        shots: [StringShot]? = nil
    ) -> StringRun {
        let run = StringRun(stageId: stageId, divisionId: divisionId)
        run.time = time

        if let shots = shots {
            run.stringShots = shots
        } else {
            // Create 5 sample shots
            run.stringShots = [
                StringShot(now: 0.50, split: 0.50, first: 0.50),
                StringShot(now: 1.00, split: 0.50, first: 0.50),
                StringShot(now: 1.50, split: 0.50, first: 0.50),
                StringShot(now: 2.00, split: 0.50, first: 0.50),
                StringShot(now: 2.50, split: 0.50, first: 0.50)
            ]
        }

        return run
    }

    /// Create a string run with penalties
    static func createStringRunWithPenalties(
        missedTargets: [Int]
    ) -> StringRun {
        let run = createStringRun()
        run.missedTargets = missedTargets
        return run
    }

    // MARK: - BLE Data

    /// Create sample BLE data for a beep event
    static func createBeepData() -> Data {
        let bytes: [UInt8] = [1, 5, 0, 0, 0, 0, 0, 0, 0, 0]
        return Data(bytes)
    }

    /// Create sample BLE data for a shot event
    static func createShotData(now: Decimal, split: Decimal, first: Decimal) -> Data {
        var bytes: [UInt8] = [1, 3, 0, 0]

        // Convert decimals to byte pairs
        let nowInt = NSDecimalNumber(decimal: now * Decimal(100)).intValue
        let splitInt = NSDecimalNumber(decimal: split * Decimal(100)).intValue
        let firstInt = NSDecimalNumber(decimal: first * Decimal(100)).intValue

        bytes.append(UInt8((nowInt >> 8) & 0xFF))  // high byte
        bytes.append(UInt8(nowInt & 0xFF))         // low byte
        bytes.append(UInt8((splitInt >> 8) & 0xFF))
        bytes.append(UInt8(splitInt & 0xFF))
        bytes.append(UInt8((firstInt >> 8) & 0xFF))
        bytes.append(UInt8(firstInt & 0xFF))

        return Data(bytes)
    }

    /// Create sample BLE data for stop waiting event
    static func createStopWaitingData() -> Data {
        let bytes: [UInt8] = [1, 8, 0, 0, 0, 0, 0, 0, 0, 0]
        return Data(bytes)
    }

    // MARK: - Benchmark Times

    /// GM benchmark time for RFPO SC-101 (5 To Go)
    static let rfpo_5ToGo_benchmark: Decimal = 8.75

    /// GM benchmark time for RFPO SC-104 (Outer Limits)
    static let rfpo_OuterLimits_benchmark: Decimal = 11.50

    // MARK: - Performance Calculations

    /// Calculate what time is needed for a specific percentage
    static func timeForPercent(benchmark: Decimal, strings: Int, percent: Decimal) -> Decimal {
        let peakPerUnit = benchmark / Decimal(strings - 1)
        return (peakPerUnit / percent) * 100
    }
}

// MARK: - Test Helpers

extension StringRun {
    /// Convenience for testing - check if two runs are equivalent
    func isEquivalent(to other: StringRun) -> Bool {
        return self.stageId == other.stageId &&
               self.divisionId == other.divisionId &&
               self.time == other.time &&
               self.stringShots.count == other.stringShots.count
    }
}

// MARK: - Decimal Assertions

/// Helper for comparing decimals in tests (with tolerance)
func assertDecimalEqual(
    _ actual: Decimal,
    _ expected: Decimal,
    tolerance: Decimal = 0.01,
    file: StaticString = #file,
    line: UInt = #line
) -> Bool {
    let diff = abs(actual - expected)
    return diff <= tolerance
}

/// Helper for formatting decimals in test output
func formatDecimal(_ value: Decimal, places: Int = 2) -> String {
    let nsNumber = NSDecimalNumber(decimal: value)
    return String(format: "%.\(places)f", nsNumber.doubleValue)
}
