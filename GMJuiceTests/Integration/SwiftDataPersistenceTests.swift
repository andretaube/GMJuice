//
//  SwiftDataPersistenceTests.swift
//  GMJuiceTests
//
//  Integration tests for SwiftData model persistence and relationships
//

import XCTest
import SwiftData
@testable import GMJuice

final class SwiftDataPersistenceTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()

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
    }

    override func tearDownWithError() throws {
        modelContext = nil
        modelContainer = nil
        try super.tearDownWithError()
    }

    // MARK: - Basic CRUD Tests

    func testCreateStringRun() throws {
        // Given
        let stringRun = StringRun(stageId: "SC-101", divisionId: "RFPO")
        stringRun.time = 2.50

        // When
        modelContext.insert(stringRun)
        try modelContext.save()

        // Then
        let descriptor = FetchDescriptor<StringRun>()
        let runs = try modelContext.fetch(descriptor)
        XCTAssertEqual(runs.count, 1, "Should persist 1 run")
        XCTAssertEqual(runs.first?.stageId, "SC-101", "Stage ID should match")
        XCTAssertEqual(runs.first?.divisionId, "RFPO", "Division ID should match")
        XCTAssertEqual(runs.first?.time, 2.50, "Time should match")
    }

    func testReadStringRun() throws {
        // Given - create and save a run
        let stringRun = StringRun(stageId: "SC-102", divisionId: "CO")
        stringRun.time = 3.75
        modelContext.insert(stringRun)
        try modelContext.save()

        // When - fetch it back
        let descriptor = FetchDescriptor<StringRun>()
        let runs = try modelContext.fetch(descriptor)

        // Then
        XCTAssertEqual(runs.count, 1, "Should fetch 1 run")
        let fetchedRun = runs.first!
        XCTAssertEqual(fetchedRun.stageId, "SC-102", "Stage ID should match")
        XCTAssertEqual(fetchedRun.divisionId, "CO", "Division ID should match")
        XCTAssertEqual(fetchedRun.time, 3.75, "Time should match")
    }

    func testUpdateStringRun() throws {
        // Given
        let stringRun = StringRun(stageId: "SC-103", divisionId: "PROD")
        stringRun.time = 5.00
        modelContext.insert(stringRun)
        try modelContext.save()

        // When - update the time
        stringRun.time = 4.50
        try modelContext.save()

        // Then
        let descriptor = FetchDescriptor<StringRun>()
        let runs = try modelContext.fetch(descriptor)
        XCTAssertEqual(runs.count, 1, "Should still have 1 run")
        XCTAssertEqual(runs.first?.time, 4.50, "Time should be updated")
    }

    func testDeleteStringRun() throws {
        // Given
        let stringRun = StringRun(stageId: "SC-104", divisionId: "RFPO")
        modelContext.insert(stringRun)
        try modelContext.save()

        // When - delete the run
        modelContext.delete(stringRun)
        try modelContext.save()

        // Then
        let descriptor = FetchDescriptor<StringRun>()
        let runs = try modelContext.fetch(descriptor)
        XCTAssertEqual(runs.count, 0, "Should have no runs after deletion")
    }

    // MARK: - Relationship Tests

    func testStringRun_WithStringShots() throws {
        // Given
        let stringRun = StringRun(stageId: "SC-105", divisionId: "RFPI")
        stringRun.time = 2.50

        // Add 5 shots
        let shots = [
            StringShot(now: 0.50, split: 0.50, first: 0.50),
            StringShot(now: 1.00, split: 0.50, first: 0.50),
            StringShot(now: 1.50, split: 0.50, first: 0.50),
            StringShot(now: 2.00, split: 0.50, first: 0.50),
            StringShot(now: 2.50, split: 0.50, first: 0.50)
        ]
        stringRun.stringShots = shots

        // When
        modelContext.insert(stringRun)
        try modelContext.save()

        // Then
        let descriptor = FetchDescriptor<StringRun>()
        let runs = try modelContext.fetch(descriptor)
        XCTAssertEqual(runs.count, 1, "Should persist 1 run")
        XCTAssertEqual(runs.first?.stringShots.count, 5, "Run should have 5 shots")

        // Verify shot order is preserved
        let orderedShots = runs.first?.orderedStringShots ?? []
        XCTAssertEqual(orderedShots[0].now, 0.50, "First shot should be 0.50")
        XCTAssertEqual(orderedShots[4].now, 2.50, "Last shot should be 2.50")
    }

    func testCascadeDelete_StringRunDeletesShots() throws {
        // Given
        let stringRun = StringRun(stageId: "SC-106", divisionId: "OPN")
        stringRun.stringShots = [
            StringShot(now: 0.50, split: 0.50, first: 0.50),
            StringShot(now: 1.00, split: 0.50, first: 0.50)
        ]
        modelContext.insert(stringRun)
        try modelContext.save()

        // When - delete the run
        modelContext.delete(stringRun)
        try modelContext.save()

        // Then - shots should be deleted too (cascade)
        let runDescriptor = FetchDescriptor<StringRun>()
        let runs = try modelContext.fetch(runDescriptor)
        XCTAssertEqual(runs.count, 0, "Run should be deleted")

        let shotDescriptor = FetchDescriptor<StringShot>()
        let shots = try modelContext.fetch(shotDescriptor)
        XCTAssertEqual(shots.count, 0, "Shots should be cascade deleted")
    }

    // MARK: - Query Tests

    func testQuery_ByStageId() throws {
        // Given - create runs for different stages
        let run1 = StringRun(stageId: "SC-101", divisionId: "RFPO")
        let run2 = StringRun(stageId: "SC-102", divisionId: "RFPO")
        let run3 = StringRun(stageId: "SC-101", divisionId: "CO")

        modelContext.insert(run1)
        modelContext.insert(run2)
        modelContext.insert(run3)
        try modelContext.save()

        // When - query for SC-101
        var descriptor = FetchDescriptor<StringRun>(
            predicate: #Predicate { $0.stageId == "SC-101" }
        )
        let sc101Runs = try modelContext.fetch(descriptor)

        // Then
        XCTAssertEqual(sc101Runs.count, 2, "Should find 2 runs for SC-101")
    }

    func testQuery_ByDivision() throws {
        // Given
        let run1 = StringRun(stageId: "SC-101", divisionId: "RFPO")
        let run2 = StringRun(stageId: "SC-102", divisionId: "RFPO")
        let run3 = StringRun(stageId: "SC-103", divisionId: "CO")

        modelContext.insert(run1)
        modelContext.insert(run2)
        modelContext.insert(run3)
        try modelContext.save()

        // When - query for RFPO
        let descriptor = FetchDescriptor<StringRun>(
            predicate: #Predicate { $0.divisionId == "RFPO" }
        )
        let rfpoRuns = try modelContext.fetch(descriptor)

        // Then
        XCTAssertEqual(rfpoRuns.count, 2, "Should find 2 runs for RFPO")
    }

    func testQuery_ByDateRange() throws {
        // Given
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        let run1 = StringRun(stageId: "SC-101", divisionId: "RFPO", date: lastWeek, time: 2.0)
        let run2 = StringRun(stageId: "SC-102", divisionId: "RFPO", date: yesterday, time: 2.5)
        let run3 = StringRun(stageId: "SC-103", divisionId: "RFPO", date: now, time: 3.0)

        modelContext.insert(run1)
        modelContext.insert(run2)
        modelContext.insert(run3)
        try modelContext.save()

        // When - query for runs in last 3 days
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        let descriptor = FetchDescriptor<StringRun>(
            predicate: #Predicate { $0.date >= threeDaysAgo }
        )
        let recentRuns = try modelContext.fetch(descriptor)

        // Then
        XCTAssertEqual(recentRuns.count, 2, "Should find 2 runs in last 3 days")
    }

    func testQuery_SortByDate() throws {
        // Given - create runs with different dates
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        let run1 = StringRun(stageId: "SC-101", divisionId: "RFPO", date: now, time: 3.0)
        let run2 = StringRun(stageId: "SC-102", divisionId: "RFPO", date: lastWeek, time: 1.0)
        let run3 = StringRun(stageId: "SC-103", divisionId: "RFPO", date: yesterday, time: 2.0)

        modelContext.insert(run1)
        modelContext.insert(run2)
        modelContext.insert(run3)
        try modelContext.save()

        // When - query sorted by date descending
        var descriptor = FetchDescriptor<StringRun>()
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        let sortedRuns = try modelContext.fetch(descriptor)

        // Then
        XCTAssertEqual(sortedRuns.count, 3, "Should fetch all 3 runs")
        XCTAssertEqual(sortedRuns[0].time, 3.0, "Most recent should be first")
        XCTAssertEqual(sortedRuns[1].time, 2.0, "Yesterday should be second")
        XCTAssertEqual(sortedRuns[2].time, 1.0, "Oldest should be last")
    }

    // MARK: - Missed Targets Persistence Tests

    func testMissedTargets_Persistence() throws {
        // Given
        let stringRun = StringRun(stageId: "SC-107", divisionId: "LTD")
        stringRun.missedTargets = [2, 4, 5]

        // When
        modelContext.insert(stringRun)
        try modelContext.save()

        // Then - fetch and verify
        let descriptor = FetchDescriptor<StringRun>()
        let runs = try modelContext.fetch(descriptor)
        XCTAssertEqual(runs.count, 1, "Should persist 1 run")

        let missedTargets = runs.first?.missedTargets ?? []
        XCTAssertEqual(missedTargets.count, 3, "Should persist 3 missed targets")
        XCTAssertTrue(missedTargets.contains(2), "Should contain target 2")
        XCTAssertTrue(missedTargets.contains(4), "Should contain target 4")
        XCTAssertTrue(missedTargets.contains(5), "Should contain target 5")
    }

    func testMissedTargets_EmptyArray() throws {
        // Given
        let stringRun = StringRun(stageId: "SC-108", divisionId: "SS")
        stringRun.missedTargets = []

        // When
        modelContext.insert(stringRun)
        try modelContext.save()

        // Then
        let descriptor = FetchDescriptor<StringRun>()
        let runs = try modelContext.fetch(descriptor)
        XCTAssertEqual(runs.first?.missedTargets.count, 0, "Should persist empty array")
    }

    // MARK: - Shooter Profile Tests

    func testShooterProfile_CreateAndRead() throws {
        // Given
        let profile = ShooterProfile(uspsaNumber: "TM12345")

        // When
        modelContext.insert(profile)
        try modelContext.save()

        // Then
        let descriptor = FetchDescriptor<ShooterProfile>()
        let profiles = try modelContext.fetch(descriptor)
        XCTAssertEqual(profiles.count, 1, "Should persist 1 profile")
        XCTAssertEqual(profiles.first?.uspsaNumber, "TM12345", "USPSA number should match")
    }

    func testShooterProfile_WithDivisions() throws {
        // Given
        let profile = ShooterProfile(uspsaNumber: "TM12345")

        let rfpoDivision = DivisionProfile(division: .RFPO)
        rfpoDivision.classification = .GM

        let coDivision = DivisionProfile(division: .CO)
        coDivision.classification = .M

        profile.divisions = [rfpoDivision, coDivision]

        // When
        modelContext.insert(profile)
        try modelContext.save()

        // Then
        let descriptor = FetchDescriptor<ShooterProfile>()
        let profiles = try modelContext.fetch(descriptor)
        XCTAssertEqual(profiles.count, 1, "Should persist 1 profile")
        XCTAssertEqual(profiles.first?.divisions.count, 2, "Should have 2 divisions")

        let divs = profiles.first?.divisions ?? []
        XCTAssertTrue(divs.contains(where: { $0.division == .RFPO }), "Should have RFPO")
        XCTAssertTrue(divs.contains(where: { $0.division == .CO }), "Should have CO")
    }

    func testShooterProfile_CascadeDelete() throws {
        // Given
        let profile = ShooterProfile(uspsaNumber: "TM12345")
        let division = DivisionProfile(division: .RFPO)
        profile.divisions = [division]

        modelContext.insert(profile)
        try modelContext.save()

        // When - delete profile
        modelContext.delete(profile)
        try modelContext.save()

        // Then - divisions should be cascade deleted
        let profileDescriptor = FetchDescriptor<ShooterProfile>()
        let profiles = try modelContext.fetch(profileDescriptor)
        XCTAssertEqual(profiles.count, 0, "Profile should be deleted")

        let divisionDescriptor = FetchDescriptor<DivisionProfile>()
        let divisions = try modelContext.fetch(divisionDescriptor)
        XCTAssertEqual(divisions.count, 0, "Divisions should be cascade deleted")
    }

    // MARK: - Performance Tests

    func testBulkInsert_Performance() throws {
        // Measure time to insert 100 string runs
        measure {
            for i in 1...100 {
                let run = StringRun(
                    stageId: "SC-10\(i % 8 + 1)",
                    divisionId: "RFPO",
                    date: Date(),
                    time: Decimal(i) / 10.0
                )

                // Add 5 shots to each
                for j in 1...5 {
                    let shot = StringShot(
                        now: Decimal(j) * 0.5,
                        split: 0.5,
                        first: 0.5
                    )
                    run.stringShots.append(shot)
                }

                modelContext.insert(run)
            }

            do {
                try modelContext.save()
            } catch {
                XCTFail("Failed to save: \(error)")
            }
        }
    }

    func testBulkQuery_Performance() throws {
        // Given - insert 100 runs
        for i in 1...100 {
            let run = StringRun(
                stageId: "SC-10\(i % 8 + 1)",
                divisionId: "RFPO",
                date: Date(),
                time: Decimal(i) / 10.0
            )
            modelContext.insert(run)
        }
        try modelContext.save()

        // Measure query performance
        measure {
            let descriptor = FetchDescriptor<StringRun>()
            do {
                let _ = try modelContext.fetch(descriptor)
            } catch {
                XCTFail("Failed to fetch: \(error)")
            }
        }
    }
}
