//
//  ShooterClassTests.swift
//  GMJuiceTests
//
//  Unit tests for ShooterClass classification and thresholds
//

import XCTest
@testable import GMJuice

final class ShooterClassTests: XCTestCase {

    // MARK: - Classification Logic Tests

    func testShooterClass_GM() throws {
        let testCases: [Decimal] = [95, 96, 100, 105, 110]

        for percentage in testCases {
            // When
            let classification = ShooterClass.shooterClass(percentage: percentage)

            // Then
            XCTAssertEqual(
                classification,
                .GM,
                "Percentage \(percentage) should classify as GM"
            )
        }
    }

    func testShooterClass_Master() throws {
        let testCases: [Decimal] = [85, 86, 90, 94, 94.99]

        for percentage in testCases {
            // When
            let classification = ShooterClass.shooterClass(percentage: percentage)

            // Then
            XCTAssertEqual(
                classification,
                .M,
                "Percentage \(percentage) should classify as Master"
            )
        }
    }

    func testShooterClass_A() throws {
        let testCases: [Decimal] = [75, 76, 80, 84, 84.99]

        for percentage in testCases {
            // When
            let classification = ShooterClass.shooterClass(percentage: percentage)

            // Then
            XCTAssertEqual(
                classification,
                .A,
                "Percentage \(percentage) should classify as A"
            )
        }
    }

    func testShooterClass_B() throws {
        let testCases: [Decimal] = [60, 61, 65, 70, 74, 74.99]

        for percentage in testCases {
            // When
            let classification = ShooterClass.shooterClass(percentage: percentage)

            // Then
            XCTAssertEqual(
                classification,
                .B,
                "Percentage \(percentage) should classify as B"
            )
        }
    }

    func testShooterClass_C() throws {
        let testCases: [Decimal] = [40, 41, 45, 50, 55, 59, 59.99]

        for percentage in testCases {
            // When
            let classification = ShooterClass.shooterClass(percentage: percentage)

            // Then
            XCTAssertEqual(
                classification,
                .C,
                "Percentage \(percentage) should classify as C"
            )
        }
    }

    func testShooterClass_D() throws {
        let testCases: [Decimal] = [2, 3, 10, 20, 30, 39, 39.99]

        for percentage in testCases {
            // When
            let classification = ShooterClass.shooterClass(percentage: percentage)

            // Then
            XCTAssertEqual(
                classification,
                .D,
                "Percentage \(percentage) should classify as D"
            )
        }
    }

    func testShooterClass_Unclassified() throws {
        let testCases: [Decimal] = [0, 0.5, 1, 1.5, 1.99]

        for percentage in testCases {
            // When
            let classification = ShooterClass.shooterClass(percentage: percentage)

            // Then
            XCTAssertEqual(
                classification,
                .U,
                "Percentage \(percentage) should classify as Unclassified"
            )
        }
    }

    // MARK: - Boundary Tests

    func testShooterClass_BoundaryAtGM() throws {
        // Test exact boundary values
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 94.99), .M, "94.99 should be Master")
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 95.00), .GM, "95.00 should be GM")
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 95.01), .GM, "95.01 should be GM")
    }

    func testShooterClass_BoundaryAtMaster() throws {
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 84.99), .A, "84.99 should be A")
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 85.00), .M, "85.00 should be Master")
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 85.01), .M, "85.01 should be Master")
    }

    func testShooterClass_BoundaryAtA() throws {
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 74.99), .B, "74.99 should be B")
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 75.00), .A, "75.00 should be A")
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 75.01), .A, "75.01 should be A")
    }

    func testShooterClass_BoundaryAtB() throws {
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 59.99), .C, "59.99 should be C")
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 60.00), .B, "60.00 should be B")
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 60.01), .B, "60.01 should be B")
    }

    func testShooterClass_BoundaryAtC() throws {
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 39.99), .D, "39.99 should be D")
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 40.00), .C, "40.00 should be C")
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 40.01), .C, "40.01 should be C")
    }

    func testShooterClass_BoundaryAtD() throws {
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 1.99), .U, "1.99 should be U")
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 2.00), .D, "2.00 should be D")
        XCTAssertEqual(ShooterClass.shooterClass(percentage: 2.01), .D, "2.01 should be D")
    }

    // MARK: - Threshold Tests

    func testPercentThreshold_AllClasses() throws {
        // Verify threshold values
        XCTAssertEqual(ShooterClass.GM.percentThreshold, 95)
        XCTAssertEqual(ShooterClass.M.percentThreshold, 85)
        XCTAssertEqual(ShooterClass.A.percentThreshold, 75)
        XCTAssertEqual(ShooterClass.B.percentThreshold, 60)
        XCTAssertEqual(ShooterClass.C.percentThreshold, 40)
        XCTAssertEqual(ShooterClass.D.percentThreshold, 2)
        XCTAssertEqual(ShooterClass.U.percentThreshold, 0)
    }

    func testNextClassThreshold_AllClasses() throws {
        // Verify next class threshold values
        XCTAssertEqual(ShooterClass.GM.nextClassThreshold, 100, "GM next is 100%")
        XCTAssertEqual(ShooterClass.M.nextClassThreshold, 95, "Master next is GM at 95%")
        XCTAssertEqual(ShooterClass.A.nextClassThreshold, 85, "A next is Master at 85%")
        XCTAssertEqual(ShooterClass.B.nextClassThreshold, 75, "B next is A at 75%")
        XCTAssertEqual(ShooterClass.C.nextClassThreshold, 60, "C next is B at 60%")
        XCTAssertEqual(ShooterClass.D.nextClassThreshold, 40, "D next is C at 40%")
        XCTAssertEqual(ShooterClass.U.nextClassThreshold, 2, "U next is D at 2%")
    }

    // MARK: - Rank/Comparison Tests

    func testRank_AllClasses() throws {
        XCTAssertEqual(ShooterClass.GM.rank, 7)
        XCTAssertEqual(ShooterClass.M.rank, 6)
        XCTAssertEqual(ShooterClass.A.rank, 5)
        XCTAssertEqual(ShooterClass.B.rank, 4)
        XCTAssertEqual(ShooterClass.C.rank, 3)
        XCTAssertEqual(ShooterClass.D.rank, 2)
        XCTAssertEqual(ShooterClass.U.rank, 1)
    }

    func testComparable_LessThan() throws {
        // Higher classes should be > lower classes
        XCTAssertTrue(ShooterClass.GM > ShooterClass.M)
        XCTAssertTrue(ShooterClass.M > ShooterClass.A)
        XCTAssertTrue(ShooterClass.A > ShooterClass.B)
        XCTAssertTrue(ShooterClass.B > ShooterClass.C)
        XCTAssertTrue(ShooterClass.C > ShooterClass.D)
        XCTAssertTrue(ShooterClass.D > ShooterClass.U)
    }

    func testComparable_GreaterThan() throws {
        // Lower classes should be < higher classes
        XCTAssertTrue(ShooterClass.U < ShooterClass.D)
        XCTAssertTrue(ShooterClass.D < ShooterClass.C)
        XCTAssertTrue(ShooterClass.C < ShooterClass.B)
        XCTAssertTrue(ShooterClass.B < ShooterClass.A)
        XCTAssertTrue(ShooterClass.A < ShooterClass.M)
        XCTAssertTrue(ShooterClass.M < ShooterClass.GM)
    }

    func testComparable_Equal() throws {
        XCTAssertEqual(ShooterClass.GM, ShooterClass.GM)
        XCTAssertEqual(ShooterClass.M, ShooterClass.M)
        XCTAssertEqual(ShooterClass.U, ShooterClass.U)
    }

    func testSorting() throws {
        // Given - unsorted array of classes
        var classes: [ShooterClass] = [.C, .GM, .U, .A, .M, .B, .D]

        // When - sort
        classes.sort()

        // Then - should be in ascending order (U to GM)
        XCTAssertEqual(classes, [.U, .D, .C, .B, .A, .M, .GM])
    }

    // MARK: - Display Name Tests

    func testDisplayName_AllClasses() throws {
        XCTAssertEqual(ShooterClass.GM.displayName, "Grand Master")
        XCTAssertEqual(ShooterClass.M.displayName, "Master")
        XCTAssertEqual(ShooterClass.A.displayName, "A Class")
        XCTAssertEqual(ShooterClass.B.displayName, "B Class")
        XCTAssertEqual(ShooterClass.C.displayName, "C Class")
        XCTAssertEqual(ShooterClass.D.displayName, "D Class")
        XCTAssertEqual(ShooterClass.U.displayName, "Unclassified")
    }

    func testRawValue_AllClasses() throws {
        XCTAssertEqual(ShooterClass.GM.rawValue, "GM")
        XCTAssertEqual(ShooterClass.M.rawValue, "M")
        XCTAssertEqual(ShooterClass.A.rawValue, "A")
        XCTAssertEqual(ShooterClass.B.rawValue, "B")
        XCTAssertEqual(ShooterClass.C.rawValue, "C")
        XCTAssertEqual(ShooterClass.D.rawValue, "D")
        XCTAssertEqual(ShooterClass.U.rawValue, "U")
    }

    // MARK: - Percent Range Tests

    func testPercentRange_GM() throws {
        let range = ShooterClass.GM.percentRange
        XCTAssertTrue(range.contains(95.0))
        XCTAssertTrue(range.contains(100.0))
        XCTAssertTrue(range.contains(150.0))
        XCTAssertFalse(range.contains(94.9))
    }

    func testPercentRange_Master() throws {
        let range = ShooterClass.M.percentRange
        XCTAssertTrue(range.contains(85.0))
        XCTAssertTrue(range.contains(90.0))
        XCTAssertTrue(range.contains(94.9))
        XCTAssertFalse(range.contains(84.9))
        XCTAssertFalse(range.contains(95.0))
    }

    func testPercentRange_Unclassified() throws {
        let range = ShooterClass.U.percentRange
        XCTAssertTrue(range.contains(0.0))
        XCTAssertTrue(range.contains(1.0))
        XCTAssertTrue(range.contains(1.9))
        XCTAssertFalse(range.contains(2.0))
    }

    // MARK: - CaseIterable Tests

    func testAllCases() throws {
        let allCases = ShooterClass.allCases
        XCTAssertEqual(allCases.count, 7, "Should have 7 classification levels")
        XCTAssertTrue(allCases.contains(.GM))
        XCTAssertTrue(allCases.contains(.M))
        XCTAssertTrue(allCases.contains(.A))
        XCTAssertTrue(allCases.contains(.B))
        XCTAssertTrue(allCases.contains(.C))
        XCTAssertTrue(allCases.contains(.D))
        XCTAssertTrue(allCases.contains(.U))
    }

    // MARK: - Integration with Performance Calculation

    func testClassification_WithPeakBenchmark() throws {
        // Given - RFPO SC-101 (5 To Go)
        let division = Division.RFPO
        let stageCode = "SC-101"

        // Test various performance levels
        let testCases: [(time: Decimal, expectedClass: ShooterClass)] = [
            (1.80, .GM),    // Exceptional time
            (2.00, .GM),    // Strong GM
            (2.45, .M),     // Master level (~89% of per-string peak)
            (2.80, .A),     // A class
            (3.50, .B),     // B class
            (5.00, .C),     // C class
            (8.00, .D),     // D class
            (15.00, .D)     // Very slow — single-string % bottoms out at D
        ]
        // (A single string can't reach 'U' (<2%); that would need ~110s+.)

        for (time, expectedClass) in testCases {
            // When
            let percent = PeakBenchmarks.percent(
                division: division,
                stageCode: stageCode,
                time: time
            )
            let actualClass = ShooterClass.shooterClass(percentage: percent)

            // Then
            XCTAssertEqual(
                actualClass,
                expectedClass,
                "Time \(time) should classify as \(expectedClass.rawValue)"
            )
        }
    }

    // MARK: - Codable Tests

    func testCodable_Encode() throws {
        // Given
        let classification = ShooterClass.GM

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(classification)
        let jsonString = String(data: data, encoding: .utf8)

        // Then
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString?.contains("GM") ?? false)
    }

    func testCodable_Decode() throws {
        // Given
        let jsonString = "\"GM\""
        let data = jsonString.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let classification = try decoder.decode(ShooterClass.self, from: data)

        // Then
        XCTAssertEqual(classification, .GM)
    }

    func testCodable_RoundTrip() throws {
        // Test all classes
        for originalClass in ShooterClass.allCases {
            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(originalClass)

            let decoder = JSONDecoder()
            let decodedClass = try decoder.decode(ShooterClass.self, from: data)

            // Then
            XCTAssertEqual(decodedClass, originalClass)
        }
    }
}
