//
//  FormatUtilsTests.swift
//  GMJuiceTests
//
//  Unit tests for Format utility functions
//

import XCTest
@testable import GMJuice

final class FormatUtilsTests: XCTestCase {

    // MARK: - Basic Formatting Tests

    func testFormatTime_StandardTime() throws {
        let testCases: [(Decimal, String)] = [
            (0.00, "0.00"),
            (0.01, "0.01"),
            (0.99, "0.99"),
            (1.00, "1.00"),
            (1.50, "1.50"),
            (2.34, "2.34"),
            (9.99, "9.99"),
            (10.00, "10.00"),
            (30.00, "30.00")
        ]

        for (input, expected) in testCases {
            // When
            let result = Format.formatTime(input)

            // Then
            XCTAssertEqual(
                result,
                expected,
                "Format.formatTime(\(input)) should equal '\(expected)'"
            )
        }
    }

    func testFormatTime_RoundingUp() throws {
        let testCases: [(Decimal, String)] = [
            (0.995, "1.00"),   // Round up at .995
            (1.995, "2.00"),   // Round up at .995
            (2.345, "2.35"),   // Round up at .005
            (9.999, "10.00")   // Round up
        ]

        for (input, expected) in testCases {
            // When
            let result = Format.formatTime(input)

            // Then
            XCTAssertEqual(
                result,
                expected,
                "Format.formatTime(\(input)) should round to '\(expected)'"
            )
        }
    }

    func testFormatTime_RoundingDown() throws {
        let testCases: [(Decimal, String)] = [
            (0.004, "0.00"),   // Round down below .005
            (0.994, "0.99"),   // Round down below .995
            (1.994, "1.99"),   // Round down below .995
            (2.344, "2.34")    // Round down below .345
        ]

        for (input, expected) in testCases {
            // When
            let result = Format.formatTime(input)

            // Then
            XCTAssertEqual(
                result,
                expected,
                "Format.formatTime(\(input)) should round to '\(expected)'"
            )
        }
    }

    func testFormatTime_TrailingZeros() throws {
        // Verify trailing zeros are preserved
        let testCases: [(Decimal, String)] = [
            (1.00, "1.00"),
            (2.10, "2.10"),
            (3.20, "3.20"),
            (10.00, "10.00"),
            (10.10, "10.10")
        ]

        for (input, expected) in testCases {
            // When
            let result = Format.formatTime(input)

            // Then
            XCTAssertEqual(
                result,
                expected,
                "Format.formatTime(\(input)) should preserve trailing zeros: '\(expected)'"
            )
            XCTAssertEqual(
                result.count,
                expected.count,
                "Formatted string should have same length as expected"
            )
        }
    }

    func testFormatTime_LeadingZero() throws {
        // Verify leading zero is present for values < 1
        let testCases: [(Decimal, String)] = [
            (0.01, "0.01"),
            (0.10, "0.10"),
            (0.50, "0.50"),
            (0.99, "0.99")
        ]

        for (input, expected) in testCases {
            // When
            let result = Format.formatTime(input)

            // Then
            XCTAssertEqual(
                result,
                expected,
                "Format.formatTime(\(input)) should include leading zero: '\(expected)'"
            )
            XCTAssertTrue(
                result.hasPrefix("0."),
                "Result should start with '0.'"
            )
        }
    }

    func testFormatTime_ExtremeValues() throws {
        let testCases: [(Decimal, String)] = [
            (0.001, "0.00"),        // Very small
            (0.0001, "0.00"),       // Extremely small
            (99.99, "99.99"),       // Large but reasonable
            (100.00, "100.00"),     // Century mark
            (999.99, "999.99")      // Very large
        ]

        for (input, expected) in testCases {
            // When
            let result = Format.formatTime(input)

            // Then
            XCTAssertEqual(
                result,
                expected,
                "Format.formatTime(\(input)) should handle extreme value: '\(expected)'"
            )
        }
    }

    func testFormatTime_NegativeValues() throws {
        // While negative times shouldn't occur in practice, test handling
        let testCases: [(Decimal, String)] = [
            (-0.01, "-0.01"),
            (-1.00, "-1.00"),
            (-10.50, "-10.50")
        ]

        for (input, expected) in testCases {
            // When
            let result = Format.formatTime(input)

            // Then
            XCTAssertEqual(
                result,
                expected,
                "Format.formatTime(\(input)) should handle negative: '\(expected)'"
            )
        }
    }

    // MARK: - Precision Tests

    func testFormatTime_TwoDecimalPrecision() throws {
        // Verify exactly 2 decimal places in all cases
        let testCases: [Decimal] = [
            0.00, 0.1, 0.12, 0.123, 1.0, 1.2, 1.23, 1.234, 10.0, 10.5
        ]

        for input in testCases {
            // When
            let result = Format.formatTime(input)

            // Then
            let components = result.split(separator: ".")
            if components.count == 2 {
                XCTAssertEqual(
                    components[1].count,
                    2,
                    "Format.formatTime(\(input)) should have exactly 2 decimal places"
                )
            } else {
                XCTFail("Format.formatTime(\(input)) should contain a decimal point")
            }
        }
    }

    func testFormatTime_ConsistentFormatting() throws {
        // Test that repeated calls return same result
        let value: Decimal = 2.456

        // When
        let result1 = Format.formatTime(value)
        let result2 = Format.formatTime(value)
        let result3 = Format.formatTime(value)

        // Then
        XCTAssertEqual(result1, result2, "Results should be consistent")
        XCTAssertEqual(result2, result3, "Results should be consistent")
    }

    // MARK: - Real-World Scenario Tests

    func testFormatTime_TypicalSteelChallengeTime() throws {
        // Test typical Steel Challenge times (1-10 seconds)
        let testCases: [(Decimal, String)] = [
            (1.23, "1.23"),   // Fast shot
            (2.34, "2.34"),   // Good string
            (3.45, "3.45"),   // Average string
            (4.56, "4.56"),   // Slower string
            (8.75, "8.75"),   // Multi-string time
            (10.00, "10.00")  // Slow multi-string
        ]

        for (input, expected) in testCases {
            // When
            let result = Format.formatTime(input)

            // Then
            XCTAssertEqual(
                result,
                expected,
                "Should format typical Steel Challenge time correctly"
            )
        }
    }

    func testFormatTime_ShotSplitTimes() throws {
        // Test typical split times (0.3 - 1.0 seconds)
        let testCases: [(Decimal, String)] = [
            (0.30, "0.30"),   // Very fast split
            (0.35, "0.35"),   // Fast split
            (0.40, "0.40"),   // Good split
            (0.45, "0.45"),   // Average split
            (0.50, "0.50"),   // Standard split
            (0.75, "0.75"),   // Slower split
            (1.00, "1.00")    // Slow split
        ]

        for (input, expected) in testCases {
            // When
            let result = Format.formatTime(input)

            // Then
            XCTAssertEqual(
                result,
                expected,
                "Should format split time correctly"
            )
        }
    }

    func testFormatTime_PenaltyTimes() throws {
        // Test penalty-related times
        let testCases: [(Decimal, String)] = [
            (3.00, "3.00"),   // Single plate miss
            (6.00, "6.00"),   // Two plate misses
            (9.00, "9.00"),   // Three plate misses
            (30.00, "30.00")  // Maximum penalty
        ]

        for (input, expected) in testCases {
            // When
            let result = Format.formatTime(input)

            // Then
            XCTAssertEqual(
                result,
                expected,
                "Should format penalty time correctly"
            )
        }
    }

    // MARK: - Format Style Tests

    func testTwoDecimalPlacesStyle_IsStatic() throws {
        // Verify the style is properly initialized
        let style = Format.twoDecimalPlaces

        // When
        let result1 = Decimal(1.23).formatted(style)
        let result2 = Decimal(4.56).formatted(style)

        // Then
        XCTAssertEqual(result1, "1.23", "Style should format correctly")
        XCTAssertEqual(result2, "4.56", "Style should format consistently")
    }

    func testFormatTime_ThreadSafety() throws {
        // Test that Format.formatTime can be called from multiple threads safely
        let expectation = expectation(description: "Concurrent formatting")
        expectation.expectedFulfillmentCount = 10

        for i in 1...10 {
            DispatchQueue.global().async {
                let value = Decimal(i)
                let result = Format.formatTime(value)
                XCTAssertNotNil(result, "Should format from any thread")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
