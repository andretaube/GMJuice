import SwiftData
import Foundation

// MARK: - V1
enum Schema001: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 1)
    
    static var models: [any PersistentModel.Type] {
        [
            StringShot.self,
            StringRun.self,
            DivisionProfile.self,
            ShooterProfile.self
        ]
    }

    @Model
    final class StringShot {
        var now: Decimal
        var split: Decimal
        var first: Decimal

        init(now: Decimal, split: Decimal, first: Decimal) {
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
        var time: Decimal

        // No inverse, no sortBy here → avoids circular macro resolution
        @Relationship(deleteRule: .cascade)
        var stringShots: [StringShot] = []

        init(stageId: String, divisionId: String) {
            self.stageId = stageId
            self.divisionId = divisionId
            self.date = Date()
            self.time = 0
        }
        
        init(stageId: String, divisionId: String, date: Date, time: Decimal) {
            self.stageId = stageId
            self.divisionId = divisionId
            self.date = date
            self.time = time
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
    }
}
