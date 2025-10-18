import SwiftData
import Foundation

// MARK: - V1
enum ShotsSchema001: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 1)
    

    // All @Model types that belong to this schema version
    static var models: [any PersistentModel.Type] { [StringShot.self] }

    @Model
    final class StringShot {
        var now: Double
        var split: Double
        var first: Double

        init(now: Double, split: Double, first: Double) {
            self.now = now
            self.split = split
            self.first = first
        }
    }
    
    @Model
    final class StringRun {
        var stageId: String
        var divisionId: String
        var date: Date
        var time: Double

        // No inverse, no sortBy here → avoids circular macro resolution
        @Relationship(deleteRule: .cascade)
        var stringShots: [StringShot] = []

        init(stageId: String, divisionId: String) {
            self.stageId = stageId
            self.divisionId = divisionId
            self.date = Date()
            self.time = 0
        }

        @Transient
        var orderedStringShots: [StringShot] {
            stringShots.sorted { $0.now < $1.now }
        }
    }
    
    @Model
    final class DivisionProfile {
        var division: Division
        var classification: ShooterClass = ShooterClass.U
        init(division: Division) { self.division = division }
    }
    
    @Model
    final class ShooterProfile {
        // Make it non-optional so TextField binding is simple
        var uspsaNumber: String = ""

        // Persisted relationship to division profiles
        @Relationship(deleteRule: .cascade)
        var divisions: [DivisionProfile] = []

        init(uspsaNumber: String = "") {
            self.uspsaNumber = uspsaNumber
        }

        // helpers
        func profile(for division: Division) -> DivisionProfile? {
            divisions.first { $0.division == division }
        }
        func ensureProfile(for division: Division) -> DivisionProfile {
            if let existing = profile(for: division) { return existing }
            let dp = DivisionProfile(division: division)
            divisions.append(dp)
            return dp
        }
        func removeDivision(_ division: Division) {
            divisions.removeAll { $0.division == division }
        }
    }
}

// MARK: - V2 (example: migrate to centiseconds as Int)
enum ShotsSchema002: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 2)
    
    static var models: [any PersistentModel.Type] { [StringShot.self] }

    @Model
    final class StringShot {
        var now: Decimal
        var split: Decimal
        var first: Decimal

        // keep legacy for one release if you want to read old data too
        var nowLegacy: Double?
        var splitLegacy: Double?
        var firstLegacy: Double?

        init(now: Decimal, split: Decimal, first: Decimal) {
            self.now = now
            self.split = split
            self.first = first
            self.splitLegacy = nil
            self.firstLegacy = nil
            self.nowLegacy = nil
        }
    }
    
    @Model
    final class StringRun {
        var stageId: String
        var divisionId: String
        var date: Date
        var time: Double

        // No inverse, no sortBy here → avoids circular macro resolution
        @Relationship(deleteRule: .cascade)
        var stringShots: [StringShot] = []

        init(stageId: String, divisionId: String) {
            self.stageId = stageId
            self.divisionId = divisionId
            self.date = Date()
            self.time = 0
        }

        @Transient
        var orderedStringShots: [StringShot] {
            stringShots.sorted { $0.now < $1.now }
        }
    }
    
    @Model
    final class DivisionProfile {
        var division: Division
        var classification: ShooterClass = ShooterClass.U
        init(division: Division) { self.division = division }
    }
    
    @Model
    final class ShooterProfile {
        // Make it non-optional so TextField binding is simple
        var uspsaNumber: String = ""

        // Persisted relationship to division profiles
        @Relationship(deleteRule: .cascade)
        var divisions: [DivisionProfile] = []

        init(uspsaNumber: String = "") {
            self.uspsaNumber = uspsaNumber
        }

        // helpers
        func profile(for division: Division) -> DivisionProfile? {
            divisions.first { $0.division == division }
        }
        func ensureProfile(for division: Division) -> DivisionProfile {
            if let existing = profile(for: division) { return existing }
            let dp = DivisionProfile(division: division)
            divisions.append(dp)
            return dp
        }
        func removeDivision(_ division: Division) {
            divisions.removeAll { $0.division == division }
        }
    }
}

struct ShotsMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ShotsSchemaV1.self, ShotsSchemaV2.self] }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: ShotsSchemaV1.self,
        toVersion: ShotsSchemaV2.self,
        willMigrate: { context in
            print("Starting custom migration from V1 to V2")
        },
        didMigrate: { context in
            print("Running custom migration from V1 to V2")
            let oldDescriptor = FetchDescriptor<ShotsSchemaV1.StringShot>()
            do {
                let oldShots = try context.fetch(oldDescriptor)
                for oldShot in oldShots {
                    let newShot = ShotsSchemaV2.StringShot(
                        now: Decimal(oldShot.now),
                        split: Decimal(oldShot.now),
                        first: Decimal(oldShot.first)
                        )
                    
                    context.insert(newShot)
                    print("Migrated shot: now=\(oldShot.now) -> now=\(newShot.now)")
                    try context.delete(model: ShotsSchemaV1.StringShot.self)
                }
            }
            catch {
                print("Error during custom migration: \(error)")
            }
        }
    )
}
