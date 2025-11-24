//
//  PeakBenchmarkTests.swift
//  GMJuiceTests
//
//  Unit tests for performance calculation and shooter classification
//

import XCTest
@testable import GMJuice

final class PeakBenchmarkTests: XCTestCase {

    // MARK: - Benchmark Retrieval Tests

    func testGetBenchmark_ValidDivisionAndStage() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"

        // When
        let benchmark = PeakBenchmarks.get(division: division, stageCode: stageCode)

        // Then
        XCTAssertNotNil(benchmark, "Should retrieve benchmark for valid division/stage")
        XCTAssertEqual(benchmark?.peakTime, 8.75, "RFPO SC-101 benchmark should be 8.75")
        XCTAssertEqual(benchmark?.strings, 5, "SC-101 should have 5 strings")
    }

    func testGetBenchmark_AllStagesExist() throws {
        // Verify all stage codes exist for all divisions
        for division in Division.allCases {
            for stageCode in ["SC-101", "SC-102", "SC-103", "SC-104", "SC-105", "SC-106", "SC-107", "SC-108"] {
                let benchmark = PeakBenchmarks.get(division: division, stageCode: stageCode)
                XCTAssertNotNil(
                    benchmark,
                    "Benchmark should exist for \(division.rawValue) \(stageCode)"
                )
            }
        }
    }

    func testGetBenchmark_InvalidStage() throws {
        // Given
        let division = Division.RFPO
        let invalidStageCode = "SC-999"

        // When
        let benchmark = PeakBenchmarks.get(division: division, stageCode: invalidStageCode)

        // Then
        XCTAssertNil(benchmark, "Should return nil for invalid stage code")
    }


    // MARK: - Single String Percentage Tests

    func testPercent_SingleString_ExactMatch() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"
        let benchmark = PeakBenchmarks.get(division: division, stageCode: stageCode)!

        // Calculate expected time for exactly 100%
        // peakPerUnit = benchmark.peakTime / (strings - 1) = 8.75 / 4 = 2.1875
        let peakPerUnit = benchmark.peakTime / Decimal(benchmark.strings - 1)
        let exactTime = peakPerUnit

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, time: exactTime)

        // Then
        XCTAssertEqual(percent, 100, "Exact benchmark time should give 100%")
    }

    func testPercent_SingleString_GMLevel() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"
        let time: Decimal = 2.00  // Fast time for 5 To Go

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, time: time)

        // Then
        XCTAssertGreaterThanOrEqual(percent, 95, "Fast time should give GM percentage")
        let shooterClass = ShooterClass.shooterClass(percentage: percent)
        XCTAssertEqual(shooterClass, .GM, "Should classify as GM")
    }

    func testPercent_SingleString_MasterLevel() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"
        let time: Decimal = 2.40  // Good time, should be Master level

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, time: time)

        // Then
        XCTAssertGreaterThanOrEqual(percent, 85, "Should be at least Master level")
        XCTAssertLessThan(percent, 95, "Should be below GM level")
        let shooterClass = ShooterClass.shooterClass(percentage: percent)
        XCTAssertEqual(shooterClass, .M, "Should classify as Master")
    }

    func testPercent_SingleString_SlowTime() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"
        let time: Decimal = 5.00  // Slow time

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, time: time)

        // Then
        XCTAssertLessThan(percent, 60, "Slow time should be below B class")
        let shooterClass = ShooterClass.shooterClass(percentage: percent)
        XCTAssertTrue([.C, .D, .U].contains(shooterClass), "Should classify as C or below")
    }

    func testPercent_SingleString_ZeroTime() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"
        let time: Decimal = 0

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, time: time)

        // Then
        XCTAssertEqual(percent, 0, "Zero time should give 0%")
    }

    func testPercent_SingleString_NegativeTime() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"
        let time: Decimal = -1.0

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, time: time)

        // Then
        XCTAssertEqual(percent, 0, "Negative time should give 0%")
    }

    // MARK: - Multiple Strings Percentage Tests (Best N of M)

    func testPercent_MultipleStrings_BestFourOfFive() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"  // 5 strings, benchmark 8.75
        let times: [Decimal] = [2.0, 2.1, 2.2, 2.3, 3.0] // Last one is slowest

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, times: times)

        // Then
        // Should use best 4: 2.0 + 2.1 + 2.2 + 2.3 = 8.6
        // percent = (8.75 / 8.6) * 100 = 101.74 (rounded to 102)
        XCTAssertGreaterThanOrEqual(percent, 100, "Good times should exceed benchmark")
        XCTAssertEqual(percent, 102, "Should calculate correct percentage")
    }

    func testPercent_MultipleStrings_InsufficientStrings() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"  // Requires 5 strings
        let times: [Decimal] = [2.0, 2.1, 2.2] // Only 3 strings

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, times: times)

        // Then
        XCTAssertEqual(percent, 0, "Insufficient strings should give 0%")
    }

    func testPercent_MultipleStrings_ExactlyEnoughStrings() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"  // Requires 5 strings
        let times: [Decimal] = [2.0, 2.1, 2.2, 2.3, 2.4]

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, times: times)

        // Then
        XCTAssertGreaterThan(percent, 0, "Should calculate with exactly 5 strings")
    }

    func testPercent_MultipleStrings_MoreThanNeeded() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"  // Requires 5 strings
        let times: [Decimal] = [2.5, 2.4, 2.3, 2.2, 2.1, 2.0] // 6 strings

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, times: times)

        // Then
        // Should use last 5: [2.4, 2.3, 2.2, 2.1, 2.0]
        // Best 4 of those: 2.3 + 2.2 + 2.1 + 2.0 = 8.6
        XCTAssertGreaterThan(percent, 0, "Should use most recent strings")
    }

    func testPercent_MultipleStrings_OuterLimits() throws {
        // Given - SC-104 (Outer Limits) only has 4 strings
        let division = Division.RFPO
        let stageCode = "SC-104"
        let times: [Decimal] = [3.0, 3.1, 3.2, 3.3]

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, times: times)

        // Then
        // Best 3 of 4: 3.0 + 3.1 + 3.2 = 9.3
        // Benchmark is 11.50
        // percent = (11.50 / 9.3) * 100 = 123.66 (rounded to 124)
        XCTAssertGreaterThanOrEqual(percent, 100, "Good times on Outer Limits should exceed benchmark")
    }

    func testPercent_MultipleStrings_AllZeros() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"
        let times: [Decimal] = [0, 0, 0, 0, 0]

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, times: times)

        // Then
        XCTAssertEqual(percent, 0, "All zero times should give 0%")
    }

    // MARK: - Cross-Division Tests

    func testPercent_DifferentDivisions_SameStage() throws {
        // Given - same stage, different divisions have different benchmarks
        let stageCode = "SC-101"
        let time: Decimal = 2.50

        let rfpoPercent = PeakBenchmarks.percent(division: .RFPO, stageCode: stageCode, time: time)
        let prodPercent = PeakBenchmarks.percent(division: .PROD, stageCode: stageCode, time: time)

        // Then
        // RFPO benchmark is 8.75 (faster)
        // PROD benchmark is 13.00 (slower)
        // Same time should give lower percentage for harder division (RFPO)
        XCTAssertLessThan(
            rfpoPercent,
            prodPercent,
            "RFPO should be more competitive than PROD for same time"
        )
    }

    // MARK: - Percentage Rounding Tests

    func testPercent_Rounding() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"

        // Use a time that will produce a fractional percentage
        // peakPerUnit = 8.75 / 4 = 2.1875
        // time = 2.20
        // percent = (2.1875 / 2.20) * 100 = 99.43...
        let time: Decimal = 2.20

        // When
        let percent = PeakBenchmarks.percent(division: division, stageCode: stageCode, time: time)

        // Then
        // Should round to nearest integer
        XCTAssertEqual(percent, 99, "Should round to nearest integer")

        // Verify it's actually an integer (no decimal places)
        let decimalPlaces = percent.significantFractionalDecimalDigits
        XCTAssertEqual(decimalPlaces, 0, "Percentage should be rounded to integer")
    }
}

// Helper extension for checking decimal places
extension Decimal {
    var significantFractionalDecimalDigits: Int {
        return max(-exponent, 0)
    }
}
