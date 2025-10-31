//
//  RecordingManagerIntegrationTests.swift
//  GMJuiceTests
//
//  Integration tests for RecordingManager workflow with mock BLE
//

import XCTest
import SwiftData
@testable import GMJuice

@MainActor
final class RecordingManagerIntegrationTests: XCTestCase {

    var recordingManager: RecordingManager!
    var mockBLE: MockBLEManager!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
        let schema = Schema([
            StringRun.self,
            StringShot.self,
            DivisionProfile.self,
            ShooterProfile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)

        // Create recording manager and mock BLE
        recordingManager = RecordingManager.shared
        mockBLE = MockBLEManager()
    }

    override func tearDown() async throws {
        recordingManager.endSession()
        recordingManager = nil
        mockBLE = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Session Management Tests

    func testStartSession() throws {
        // Given
        let stageId = "SC-101"
        let divisionId = "RFPO"

        // When
        recordingManager.startSession(
            stageId: stageId,
            divisionId: divisionId,
            modelContext: modelContext
        )

        // Then
        XCTAssertEqual(recordingManager.stringCounter, 0, "Should start with counter at 0")
        XCTAssertEqual(recordingManager.allStrings.count, 0, "Should start with no strings")
        XCTAssertFalse(recordingManager.isRecording, "Should not be recording yet")
    }

    func testEndSession() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        recordingManager.startString()

        // When
        recordingManager.endSession()

        // Then
        XCTAssertFalse(recordingManager.isRecording, "Should not be recording")
        XCTAssertEqual(recordingManager.stringCounter, 0, "Counter should be reset")
        XCTAssertEqual(recordingManager.allStrings.count, 0, "Strings should be cleared")
        XCTAssertNil(recordingManager.currentString, "Current string should be nil")
    }

    // MARK: - String Recording Tests

    func testStartString() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )

        let expectation = expectation(description: "String started callback")
        recordingManager.onStringStarted = { _ in
            expectation.fulfill()
        }

        // When
        recordingManager.startString()

        // Then
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(recordingManager.isRecording, "Should be recording")
        XCTAssertEqual(recordingManager.stringCounter, 1, "Should increment counter")
        XCTAssertNotNil(recordingManager.currentString, "Should have current string")
        XCTAssertEqual(recordingManager.allStrings.count, 1, "Should add to allStrings")
    }

    func testRecordShot() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        recordingManager.startString()

        let expectation = expectation(description: "Shot recorded callback")
        recordingManager.onShotRecorded = { shot, count in
            if count == 1 {
                expectation.fulfill()
            }
        }

        // When
        recordingManager.recordShot(now: 0.50, split: 0.50, first: 0.50)

        // Then
        wait(for: [expectation], timeout: 0.5)
        XCTAssertEqual(recordingManager.shotCount, 1, "Should have 1 shot")
        XCTAssertEqual(recordingManager.currentString?.stringShots.count, 1, "String should have 1 shot")
        XCTAssertEqual(recordingManager.currentString?.time, 0.50, "String time should be updated")
    }

    func testRecordMultipleShots() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        recordingManager.startString()

        // When - record 5 shots
        for i in 1...5 {
            let time = Decimal(i) * 0.5
            recordingManager.recordShot(now: time, split: 0.5, first: 0.5)
        }

        // Then
        XCTAssertEqual(recordingManager.shotCount, 5, "Should have 5 shots")
        XCTAssertEqual(recordingManager.currentString?.stringShots.count, 5, "String should have 5 shots")
        XCTAssertEqual(recordingManager.currentString?.time, 2.5, "String time should be 2.5")
    }

    func testFinishString_WithEnoughShots() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        recordingManager.startString()

        let expectation = expectation(description: "String completed callback")
        recordingManager.onStringCompleted = { _ in
            expectation.fulfill()
        }

        // Record 5 shots
        for i in 1...5 {
            let time = Decimal(i) * 0.5
            recordingManager.recordShot(now: time, split: 0.5, first: 0.5)
        }

        // When
        recordingManager.finishString()

        // Then
        wait(for: [expectation], timeout: 0.5)
        XCTAssertFalse(recordingManager.isRecording, "Should not be recording")

        // Verify saved to database
        let descriptor = FetchDescriptor<StringRun>()
        let savedRuns = try modelContext.fetch(descriptor)
        XCTAssertEqual(savedRuns.count, 1, "Should save 1 run to database")
        XCTAssertEqual(savedRuns.first?.stringShots.count, 5, "Saved run should have 5 shots")
    }

    func testFinishString_WithoutEnoughShots() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        recordingManager.startString()

        // Record only 3 shots (not enough)
        for i in 1...3 {
            let time = Decimal(i) * 0.5
            recordingManager.recordShot(now: time, split: 0.5, first: 0.5)
        }

        // When
        recordingManager.finishString()

        // Then
        XCTAssertFalse(recordingManager.isRecording, "Should not be recording")

        // Verify NOT saved to database
        let descriptor = FetchDescriptor<StringRun>()
        let savedRuns = try modelContext.fetch(descriptor)
        XCTAssertEqual(savedRuns.count, 0, "Should not save incomplete string")
    }

    func testCancelString() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        recordingManager.startString()
        recordingManager.recordShot(now: 0.50, split: 0.50, first: 0.50)

        let expectation = expectation(description: "String cancelled callback")
        recordingManager.onStringCancelled = {
            expectation.fulfill()
        }

        // When
        recordingManager.cancelString()

        // Then
        wait(for: [expectation], timeout: 0.5)
        XCTAssertFalse(recordingManager.isRecording, "Should not be recording")
        XCTAssertEqual(recordingManager.stringCounter, 0, "Counter should be decremented")
        XCTAssertEqual(recordingManager.allStrings.count, 0, "String should be removed")
        XCTAssertNil(recordingManager.currentString, "Current string should be nil")
    }

    // MARK: - Target Miss Tracking Tests

    func testToggleTargetMiss_AddMiss() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        recordingManager.startString()

        // When
        recordingManager.toggleTargetMiss(2)

        // Then
        XCTAssertTrue(
            recordingManager.currentString?.missedTargets.contains(2) ?? false,
            "Should mark target 2 as missed"
        )
    }

    func testToggleTargetMiss_RemoveMiss() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        recordingManager.startString()
        recordingManager.toggleTargetMiss(2)

        // When - toggle again to remove
        recordingManager.toggleTargetMiss(2)

        // Then
        XCTAssertFalse(
            recordingManager.currentString?.missedTargets.contains(2) ?? true,
            "Should remove target 2 from misses"
        )
    }

    func testToggleTargetMiss_MultipleMisses() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        recordingManager.startString()

        // When
        recordingManager.toggleTargetMiss(2)
        recordingManager.toggleTargetMiss(4)
        recordingManager.toggleTargetMiss(5)

        // Then
        let misses = recordingManager.currentString?.missedTargets ?? []
        XCTAssertEqual(misses.count, 3, "Should have 3 misses")
        XCTAssertTrue(misses.contains(2), "Should contain target 2")
        XCTAssertTrue(misses.contains(4), "Should contain target 4")
        XCTAssertTrue(misses.contains(5), "Should contain target 5")
    }

    func testToggleTargetMiss_InvalidTarget() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        recordingManager.startString()

        // When - try invalid targets
        recordingManager.toggleTargetMiss(0)   // Invalid
        recordingManager.toggleTargetMiss(6)   // Invalid
        recordingManager.toggleTargetMiss(-1)  // Invalid

        // Then
        let misses = recordingManager.currentString?.missedTargets ?? []
        XCTAssertEqual(misses.count, 0, "Should not add invalid targets")
    }

    // MARK: - Multiple Strings Workflow Tests

    func testMultipleStringsWorkflow() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )

        // When - record 3 complete strings
        for stringNum in 1...3 {
            recordingManager.startString()

            for shotNum in 1...5 {
                let time = Decimal(shotNum) * 0.5
                recordingManager.recordShot(now: time, split: 0.5, first: 0.5)
            }

            recordingManager.finishString()
        }

        // Then
        XCTAssertEqual(recordingManager.stringCounter, 3, "Should have recorded 3 strings")

        let descriptor = FetchDescriptor<StringRun>()
        let savedRuns = try modelContext.fetch(descriptor)
        XCTAssertEqual(savedRuns.count, 3, "Should save 3 runs to database")
    }

    func testStartNewString_AutoFinishesPrevious() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        recordingManager.startString()

        // Record 5 shots in first string
        for i in 1...5 {
            let time = Decimal(i) * 0.5
            recordingManager.recordShot(now: time, split: 0.5, first: 0.5)
        }

        // When - start new string without explicitly finishing
        // (This simulates BLE beep triggering new string)
        if recordingManager.isRecording {
            recordingManager.finishString()
        }
        recordingManager.startString()

        // Then
        XCTAssertTrue(recordingManager.isRecording, "Should be recording new string")
        XCTAssertEqual(recordingManager.stringCounter, 2, "Should be on string 2")
        XCTAssertEqual(recordingManager.shotCount, 0, "New string should have 0 shots")

        let descriptor = FetchDescriptor<StringRun>()
        let savedRuns = try modelContext.fetch(descriptor)
        XCTAssertEqual(savedRuns.count, 1, "Should have saved first string")
    }

    // MARK: - Error Handling Tests

    func testRecordShot_NotRecording() throws {
        // Given - no active session
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        // Don't start string

        // When
        recordingManager.recordShot(now: 0.50, split: 0.50, first: 0.50)

        // Then
        XCTAssertEqual(recordingManager.shotCount, 0, "Shot should be ignored")
    }

    func testFinishString_NoCurrentString() throws {
        // Given - no active string
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )

        // When
        recordingManager.finishString()

        // Then - should not crash, just log warning
        XCTAssertFalse(recordingManager.isRecording, "Should not be recording")
    }

    func testStartString_NoSession() throws {
        // Given - no session started

        // When
        recordingManager.startString()

        // Then - should not crash, just log warning
        XCTAssertFalse(recordingManager.isRecording, "Should not start recording")
        XCTAssertNil(recordingManager.currentString, "Should not have current string")
    }

    // MARK: - Cleanup Tests

    func testEndSession_ClearsCallbacks() throws {
        // Given
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )

        var callbackFired = false
        recordingManager.onStringStarted = { _ in
            callbackFired = true
        }

        // When
        recordingManager.endSession()

        // Callbacks should be cleared, so trying to start string shouldn't fire them
        recordingManager.startSession(
            stageId: "SC-101",
            divisionId: "RFPO",
            modelContext: modelContext
        )
        recordingManager.startString()

        // Then
        XCTAssertFalse(callbackFired, "Callback should be cleared after endSession")
    }
}
