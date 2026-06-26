//
//  RecordingManagerIntegrationTests.swift
//  GMJuiceTests
//
//  Integration tests for the set-based RecordingManager workflow.
//  A "beep" is simulated via handleBeep(); shots via recordShot().
//

import XCTest
import SwiftData
@testable import GMJuice

@MainActor
final class RecordingManagerIntegrationTests: XCTestCase {

    var manager: RecordingManager!
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([
            StringShot.self,
            StringRun.self,
            StageRun.self,
            DivisionProfile.self,
            ShooterProfile.self,
            MatchScore.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)

        manager = RecordingManager.shared
        manager.startSession(stageId: "SC-101", divisionId: "RFPO", modelContext: context)
    }

    override func tearDown() async throws {
        manager.endSession()
        manager = nil
        context = nil
        container = nil
        try await super.tearDown()
    }

    /// Shoots one string with the given total time (5 shots, no misses → adjustedTime == total).
    private func shootString(total: Double) {
        manager.handleBeep() // finalize the previous string (if any) and start a new one
        for i in 1...5 {
            let now = Decimal(total * Double(i) / 5.0)
            manager.recordShot(now: now, split: Decimal(total / 5.0), first: Decimal(total / 5.0))
        }
    }

    // MARK: - Session

    func testStartSessionInitialState() {
        XCTAssertEqual(manager.currentSet.count, 0)
        XCTAssertNil(manager.currentString)
        XCTAssertFalse(manager.isRecording)
        XCTAssertTrue(manager.completedStages.isEmpty)
        XCTAssertEqual(manager.setSize, 5, "SC-101 has 5 strings per set")
    }

    func testEndSessionClearsState() {
        manager.handleBeep()
        manager.recordShot(now: 1.0, split: 1.0, first: 1.0)
        manager.endSession()
        XCTAssertNil(manager.currentString)
        XCTAssertEqual(manager.currentSet.count, 0)
        XCTAssertFalse(manager.isRecording)
    }

    // MARK: - String lifecycle

    func testBeepStartsString() {
        manager.handleBeep()
        XCTAssertTrue(manager.isRecording)
        XCTAssertNotNil(manager.currentString)
        XCTAssertEqual(manager.stringIndex, 1)
    }

    func testRecordShotsAccumulate() {
        manager.handleBeep()
        manager.recordShot(now: 0.90, split: 0.90, first: 0.90)
        manager.recordShot(now: 1.30, split: 0.40, first: 0.90)
        XCTAssertEqual(manager.shotCount, 2)
        XCTAssertEqual(manager.currentString?.stringShots.count, 2)
    }

    func testStringRollsIntoSetOnNextBeep() {
        shootString(total: 2.5)
        XCTAssertEqual(manager.currentSet.count, 0, "Not finalized until the next beep")
        manager.handleBeep()
        XCTAssertEqual(manager.currentSet.count, 1, "Previous string is now in the set")
        XCTAssertEqual(manager.stringIndex, 2)
    }

    // MARK: - Set scoring

    func testSetCompletesScoresBest4Of5AndPersists() throws {
        let totals = [2.5, 2.6, 2.4, 3.0, 2.3] // 3.0 is the worst → dropped
        for t in totals { shootString(total: t) }
        manager.handleBeep() // finalize the 5th string → set complete → score + persist

        XCTAssertEqual(manager.completedStages.count, 1, "Set should be scored once complete")
        XCTAssertEqual(manager.currentSet.count, 0, "Set resets for the next attempt")

        let stage = try XCTUnwrap(manager.completedStages.last)
        let best4 = 2.5 + 2.6 + 2.4 + 2.3
        XCTAssertEqual(NSDecimalNumber(decimal: stage.bestNTime).doubleValue, best4, accuracy: 0.001)
        XCTAssertEqual(stage.stringCount, 5)
        XCTAssertEqual(stage.strings.count, 5)

        let saved = try context.fetch(FetchDescriptor<StageRun>())
        XCTAssertEqual(saved.count, 1, "StageRun should be persisted")
    }

    func testOuterLimitsUsesFourStringsBest3() throws {
        manager.endSession()
        manager.startSession(stageId: "SC-104", divisionId: "RFPO", modelContext: context)
        XCTAssertEqual(manager.setSize, 4, "Outer Limits has 4 strings per set")

        let totals = [3.0, 3.5, 4.5, 3.2] // 4.5 worst → dropped, best 3 counted
        for t in totals { shootString(total: t) }
        manager.handleBeep()

        let stage = try XCTUnwrap(manager.completedStages.last)
        XCTAssertEqual(stage.stringCount, 4)
        let best3 = 3.0 + 3.5 + 3.2
        XCTAssertEqual(NSDecimalNumber(decimal: stage.bestNTime).doubleValue, best3, accuracy: 0.001)
    }

    func testHistoryGrowsAcrossSets() throws {
        for _ in 0..<2 {
            for t in [2.5, 2.5, 2.5, 2.5, 2.5] { shootString(total: t) }
            manager.handleBeep() // finalize each set
        }
        XCTAssertEqual(manager.completedStages.count, 2, "Two completed sets in history")
    }
}
