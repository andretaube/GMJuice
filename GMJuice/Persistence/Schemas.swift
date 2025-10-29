import SwiftData
import Foundation

// MARK: - V1
enum Schema001: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 2)
    
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

        // Tracks which targets were missed: 1-4 for plates, 5 for stop plate
        // Empty array = all hits (5 shots), [2, 4] = missed targets 2 and 4 (7 shots)
        // Stored as Data to avoid SwiftData/CoreData array persistence issues
        private var missedTargetsData: Data?

        var missedTargets: [Int] {
            get {
                guard let data = missedTargetsData else { return [] }
                return (try? JSONDecoder().decode([Int].self, from: data)) ?? []
            }
            set {
                missedTargetsData = try? JSONEncoder().encode(newValue)
            }
        }

        // No inverse, no sortBy here → avoids circular macro resolution
        @Relationship(deleteRule: .cascade)
        var stringShots: [StringShot] = []

        init(stageId: String, divisionId: String) {
            self.stageId = stageId
            self.divisionId = divisionId
            self.date = Date()
            self.time = 0
            self.missedTargetsData = nil
        }

        init(stageId: String, divisionId: String, date: Date, time: Decimal) {
            self.stageId = stageId
            self.divisionId = divisionId
            self.date = date
            self.time = time
            self.missedTargetsData = nil
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
