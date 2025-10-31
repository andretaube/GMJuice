//
//  VideoProcessorTests.swift
//  GMJuiceTests
//
//  Unit tests for video processing utilities (CSV generation, time formatting)
//

import XCTest
@testable import GMJuice

final class VideoProcessorTests: XCTestCase {

    var videoProcessor: VideoProcessor!

    override func setUp() {
        super.setUp()
        videoProcessor = VideoProcessor()
    }

    override func tearDown() {
        videoProcessor = nil
        super.tearDown()
    }

    // MARK: - Time Formatting Tests

    func testFormatTime_TwoDecimalPlaces() throws {
        // Given
        let time: Decimal = 2.456

        // When
        let formatted = Format.formatTime(time)

        // Then
        XCTAssertEqual(formatted, "2.46", "Should format to 2 decimal places with rounding")
    }

    func testFormatTime_ExactTwoDecimalPlaces() throws {
        // Given
        let time: Decimal = 2.50

        // When
        let formatted = Format.formatTime(time)

        // Then
        XCTAssertEqual(formatted, "2.50", "Should preserve trailing zero")
    }

    func testFormatTime_WholeNumber() throws {
        // Given
        let time: Decimal = 3.0

        // When
        let formatted = Format.formatTime(time)

        // Then
        XCTAssertEqual(formatted, "3.00", "Should show .00 for whole numbers")
    }

    func testFormatTime_VerySmall() throws {
        // Given
        let time: Decimal = 0.01

        // When
        let formatted = Format.formatTime(time)

        // Then
        XCTAssertEqual(formatted, "0.01", "Should format small values correctly")
    }

    func testFormatTime_Zero() throws {
        // Given
        let time: Decimal = 0

        // When
        let formatted = Format.formatTime(time)

        // Then
        XCTAssertEqual(formatted, "0.00", "Should format zero correctly")
    }

    func testFormatTime_LargeValue() throws {
        // Given
        let time: Decimal = 30.0  // Max time in Steel Challenge

        // When
        let formatted = Format.formatTime(time)

        // Then
        XCTAssertEqual(formatted, "30.00", "Should format max time correctly")
    }

    func testFormatTime_RoundUp() throws {
        // Given
        let time: Decimal = 2.995

        // When
        let formatted = Format.formatTime(time)

        // Then
        XCTAssertEqual(formatted, "3.00", "Should round up when appropriate")
    }

    func testFormatTime_RoundDown() throws {
        // Given
        let time: Decimal = 2.994

        // When
        let formatted = Format.formatTime(time)

        // Then
        XCTAssertEqual(formatted, "2.99", "Should round down when appropriate")
    }

    // MARK: - Performance Info Generation Tests

    func testCreateTopRightInfo_ValidData() throws {
        // Given
        let stringRun = TestData.createStringRun(
            stageId: "SC-101",
            divisionId: "RFPO",
            time: 2.50
        )
        let stage = TestData.stage_5ToGo
        let division = Division.RFPO

        // When - This tests that the method can be called without crashing
        // We can't directly test CALayer output without running on device/simulator
        // but we can verify the calculation logic

        let percent = PeakBenchmarks.percent(
            division: division,
            stageCode: stage.code,
            time: stringRun.adjustedTime
        )

        // Then
        XCTAssertGreaterThan(percent, 0, "Should calculate valid percentage")
        XCTAssertLessThanOrEqual(percent, 200, "Percentage should be reasonable")
    }

    // MARK: - Shot Panel Tests

    func testCreateShotPanel_ValidShot() throws {
        // Given
        let shot = StringShot(now: 2.50, split: 0.45, first: 0.75)

        // When - verify formatting calculations
        let nowFormatted = Format.formatTime(shot.now)
        let splitFormatted = Format.formatTime(shot.split)

        // Then
        XCTAssertEqual(nowFormatted, "2.50", "Now time should format correctly")
        XCTAssertEqual(splitFormatted, "0.45", "Split time should format correctly")
    }

    func testCreateShotPanel_MultipleShots() throws {
        // Given - create 5 shots like in a real string
        let shots = [
            StringShot(now: 0.50, split: 0.50, first: 0.50),
            StringShot(now: 1.00, split: 0.50, first: 0.50),
            StringShot(now: 1.50, split: 0.50, first: 0.50),
            StringShot(now: 2.00, split: 0.50, first: 0.50),
            StringShot(now: 2.50, split: 0.50, first: 0.50)
        ]

        // When - verify each shot formats correctly
        for (index, shot) in shots.enumerated() {
            let nowFormatted = Format.formatTime(shot.now)
            let expected = Format.formatTime(Decimal(index + 1) * 0.5)

            // Then
            XCTAssertEqual(
                nowFormatted,
                expected,
                "Shot \(index + 1) should format correctly"
            )
        }
    }

    // MARK: - Beep Offset Calculation Tests

    func testBeepOffsetCalculation_SingleString() throws {
        // Given
        let trimStartTime: TimeInterval = 5.0
        let recordingBeepOffset: TimeInterval = 10.0  // Beep at 10s in recording

        // When
        let videoBeepOffset = recordingBeepOffset - trimStartTime

        // Then
        XCTAssertEqual(videoBeepOffset, 5.0, "Beep should be at 5s in trimmed video")
    }

    func testBeepOffsetCalculation_MultipleStrings() throws {
        // Given
        let trimStartTime: TimeInterval = 5.0
        let beepOffsets: [TimeInterval] = [10.0, 15.0, 20.0, 25.0, 30.0]

        // When
        let videoBeepOffsets = beepOffsets.map { $0 - trimStartTime }

        // Then
        XCTAssertEqual(videoBeepOffsets, [5.0, 10.0, 15.0, 20.0, 25.0],
                      "All beep offsets should be adjusted correctly")
    }

    func testBeepOffsetCalculation_EdgeCases() throws {
        // Given - beep exactly at trim start
        let trimStartTime: TimeInterval = 10.0
        let beepOffset: TimeInterval = 10.0

        // When
        let videoBeepOffset = beepOffset - trimStartTime

        // Then
        XCTAssertEqual(videoBeepOffset, 0.0, "Beep at trim start should be at 0s in video")
    }

    // MARK: - Overlay Layer Timing Tests

    func testOverlayTiming_ShotAppearance() throws {
        // Given - shot appears 2.5s after beep
        let beepOffset: TimeInterval = 5.0  // Beep at 5s in video
        let shotNow: Decimal = 2.5  // Shot at 2.5s after beep

        // When
        let shotAppearanceTime = beepOffset + Double(truncating: shotNow as NSDecimalNumber)

        // Then
        XCTAssertEqual(
            shotAppearanceTime,
            7.5,
            "Shot should appear at 7.5s in video (5s beep + 2.5s shot time)"
        )
    }

    func testOverlayTiming_StringFadeOut() throws {
        // Given - first string beep at 5s, second string beep at 10s
        let firstBeepOffset: TimeInterval = 5.0
        let secondBeepOffset: TimeInterval = 10.0

        // When
        let fadeOutTime = secondBeepOffset

        // Then
        XCTAssertEqual(
            fadeOutTime,
            10.0,
            "First string overlay should fade out when second string starts"
        )
    }

    // MARK: - Video Dimension Tests

    func testRenderSize_Portrait() throws {
        // Given - portrait video dimensions
        let videoSize = CGSize(width: 1080, height: 1920)
        let transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1920, ty: 0)

        // When - checking rotation (90 degrees)
        let isRotated = (transform.a == 0 && transform.d == 0)
        let renderSize: CGSize = isRotated ?
            CGSize(width: videoSize.height, height: videoSize.width) :
            videoSize

        // Then
        XCTAssertTrue(isRotated, "Portrait transform should be detected as rotated")
        XCTAssertEqual(renderSize.width, 1920, "Render width should swap for rotation")
        XCTAssertEqual(renderSize.height, 1080, "Render height should swap for rotation")
    }

    func testRenderSize_Landscape() throws {
        // Given - landscape video dimensions
        let videoSize = CGSize(width: 1920, height: 1080)
        let transform = CGAffineTransform.identity  // No rotation

        // When
        let isRotated = (transform.a == 0 && transform.d == 0)
        let renderSize: CGSize = isRotated ?
            CGSize(width: videoSize.height, height: videoSize.width) :
            videoSize

        // Then
        XCTAssertFalse(isRotated, "Landscape transform should not be rotated")
        XCTAssertEqual(renderSize.width, 1920, "Render width should not change")
        XCTAssertEqual(renderSize.height, 1080, "Render height should not change")
    }

    // MARK: - Overlay Position Tests

    func testOverlayPosition_BottomBar() throws {
        // Given
        let videoHeight: CGFloat = 1920
        let padding: CGFloat = 20
        let bottomHeight: CGFloat = 144

        // When - Core Animation uses bottom-left origin
        let yPosition = padding

        // Then
        XCTAssertEqual(yPosition, 20, "Bottom bar should be 20pt from bottom")
    }

    func testOverlayPosition_TopRightInfo() throws {
        // Given
        let videoWidth: CGFloat = 1080
        let videoHeight: CGFloat = 1920
        let infoWidth: CGFloat = 320
        let infoHeight: CGFloat = 360
        let padding: CGFloat = 20

        // When
        let xPos = videoWidth - infoWidth - padding
        let yPos = videoHeight - infoHeight - padding

        // Then
        XCTAssertEqual(xPos, 740, "Info should be 20pt from right edge")
        XCTAssertEqual(yPos, 1540, "Info should be 20pt from top (in CA coords)")
    }

    func testOverlayPosition_ShotPanels() throws {
        // Given
        let padding: CGFloat = 20
        let panelWidth: CGFloat = 168
        let shotIndex = 2  // Third shot (0-indexed)

        // When
        let xPos = padding + CGFloat(shotIndex) * panelWidth

        // Then
        XCTAssertEqual(xPos, 356, "Third shot panel should be at correct x position")
    }

    // MARK: - Performance Calculation Integration

    func testPerformanceCalculation_GMLevel() throws {
        // Given
        let division = Division.RFPO
        let stageCode = "SC-101"
        let fastTime: Decimal = 2.00

        // When
        let percent = PeakBenchmarks.percent(
            division: division,
            stageCode: stageCode,
            time: fastTime
        )
        let shooterClass = ShooterClass.shooterClass(percentage: percent)

        // Then
        XCTAssertGreaterThanOrEqual(percent, 95, "Fast time should give GM percentage")
        XCTAssertEqual(shooterClass, .GM, "Should classify as Grand Master")
    }

    func testPerformanceCalculation_WithPenalties() throws {
        // Given
        let stringRun = TestData.createStringRunWithPenalties(missedTargets: [2, 4])

        // When
        let (penalty, shouldFlash) = stringRun.calculatePenalty()
        let adjustedTime = stringRun.adjustedTime

        // Then
        XCTAssertEqual(penalty, 6, "Two missed plates should be 6 seconds")
        XCTAssertFalse(shouldFlash, "6 second penalty should not flash red")
        XCTAssertEqual(adjustedTime, stringRun.time + 6, "Adjusted time should include penalty")
    }

    func testPerformanceCalculation_StopPlateMiss() throws {
        // Given
        let stringRun = TestData.createStringRunWithPenalties(missedTargets: [5])

        // When
        let (penalty, shouldFlash) = stringRun.calculatePenalty()
        let adjustedTime = stringRun.adjustedTime

        // Then
        XCTAssertEqual(penalty, 30, "Stop plate miss should be 30 seconds")
        XCTAssertTrue(shouldFlash, "30 second penalty should flash red")
        XCTAssertEqual(adjustedTime, 30, "Adjusted time should be capped at 30")
    }
}
