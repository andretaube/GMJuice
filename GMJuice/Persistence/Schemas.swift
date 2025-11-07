import SwiftData
import Foundation

// MARK: - V4 (Current)
enum Schema004: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 5)

    static var models: [any PersistentModel.Type] {
        [
            StringShot.self,
            StringRun.self,
            DivisionProfile.self,
            ShooterProfile.self,
            SCMatchScore.self,
            TrackedShooter.self
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

        // Classification percentages from SCSA
        var currentPercentage: Decimal?
        var highPercentage: Decimal?
        var classificationDate: Date?

        init(division: Division) {
            self.division = division
        }
    }

    @Model
    final class ShooterProfile {
        var uspsaNumber: String = ""

        @Relationship(deleteRule: .cascade)
        var divisions: [DivisionProfile] = []

        init(uspsaNumber: String = "") {
            self.uspsaNumber = uspsaNumber
        }
    }

    // MARK: - Steel Challenge Match Score
    @Model
    final class SCMatchScore {
        @Attribute(.unique) var id: String  // stageCode-date timestamp
        var matchName: String
        var scoreDate: Date
        var stageCode: String      // SC-101, SC-102, etc.
        var stageName: String      // 5 To Go, Accelerator, etc.
        var divisionCode: String   // RFPO, RFPI, CO, etc.
        var time: Decimal
        var peakTime: Decimal
        var usedForClassification: Bool
        var memberNumber: String

        init(matchName: String, scoreDate: Date, stageCode: String, stageName: String, divisionCode: String, time: Decimal, peakTime: Decimal, usedForClassification: Bool, memberNumber: String) {
            self.id = "\(stageCode)-\(divisionCode)-\(Int(scoreDate.timeIntervalSince1970))"
            self.matchName = matchName
            self.scoreDate = scoreDate
            self.stageCode = stageCode
            self.stageName = stageName
            self.divisionCode = divisionCode
            self.time = time
            self.peakTime = peakTime
            self.usedForClassification = usedForClassification
            self.memberNumber = memberNumber
        }
    }

    // MARK: - Tracked Shooter (for manual comparisons)
    @Model
    final class TrackedShooter {
        @Attribute(.unique) var uspsaNumber: String
        var displayName: String
        var dateAdded: Date

        init(uspsaNumber: String, displayName: String) {
            self.uspsaNumber = uspsaNumber
            self.displayName = displayName
            self.dateAdded = Date()
        }
    }
}

// MARK: - V3 (Legacy)
enum Schema003: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 4)

    static var models: [any PersistentModel.Type] {
        [
            StringShot.self,
            StringRun.self,
            DivisionProfile.self,
            ShooterProfile.self,
            USPSAMatch.self,
            USPSAStageScore.self,
            USPSAClassifierScore.self
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

        // Classification percentages from SCSA
        var currentPercentage: Decimal?  // Current classification percentage
        var highPercentage: Decimal?     // Highest classification percentage ever achieved
        var classificationDate: Date?    // When the current classification was earned

        init(division: Division) {
            self.division = division
        }
    }

    @Model
    final class ShooterProfile {
        var uspsaNumber: String = ""

        @Relationship(deleteRule: .cascade)
        var divisions: [DivisionProfile] = []

        init(uspsaNumber: String = "") {
            self.uspsaNumber = uspsaNumber
        }
    }

    // MARK: - USPSA Match Data Models

    @Model
    final class USPSAMatch {
        var matchId: String  // USPSA match ID
        var matchName: String
        var matchDate: Date
        var club: String
        var location: String
        var division: String
        var memberNumber: String  // Which USPSA member this belongs to

        @Relationship(deleteRule: .cascade)
        var stages: [USPSAStageScore] = []

        // Overall match statistics
        var overallPlace: Int?
        var overallPercentage: Decimal?
        var totalPoints: Decimal = 0
        var totalTime: Decimal = 0

        init(matchId: String, matchName: String, matchDate: Date, club: String, location: String, division: String, memberNumber: String) {
            self.matchId = matchId
            self.matchName = matchName
            self.matchDate = matchDate
            self.club = club
            self.location = location
            self.division = division
            self.memberNumber = memberNumber
        }
    }

    @Model
    final class USPSAStageScore {
        var stageNumber: Int
        var stageName: String
        var points: Decimal
        var time: Decimal
        var hitFactor: Decimal

        // Scoring breakdown
        var alphas: Int = 0
        var charlies: Int = 0
        var deltas: Int = 0
        var mikes: Int = 0
        var noshootsHit: Int = 0
        var procedurals: Int = 0

        // Stage placement
        var stagePlace: Int?
        var stagePercentage: Decimal?

        init(stageNumber: Int, stageName: String, points: Decimal, time: Decimal, hitFactor: Decimal) {
            self.stageNumber = stageNumber
            self.stageName = stageName
            self.points = points
            self.time = time
            self.hitFactor = hitFactor
        }
    }

    @Model
    final class USPSAClassifierScore {
        var classifierId: String  // e.g., "SC-101"
        var classifierName: String
        var date: Date
        var division: String
        var memberNumber: String

        // Score details
        var points: Decimal
        var time: Decimal          // My time
        var peakTime: Decimal      // Benchmark/peak time
        var hitFactor: Decimal
        var percentage: Decimal    // Percentage of high hit factor

        // Where it was shot
        var matchId: String?
        var matchName: String

        // Whether this score was used for classification
        var usedForClassification: Bool

        init(classifierId: String, classifierName: String, date: Date, division: String, memberNumber: String, points: Decimal, time: Decimal, peakTime: Decimal, hitFactor: Decimal, percentage: Decimal, matchName: String, usedForClassification: Bool) {
            self.classifierId = classifierId
            self.classifierName = classifierName
            self.date = date
            self.division = division
            self.memberNumber = memberNumber
            self.points = points
            self.time = time
            self.peakTime = peakTime
            self.hitFactor = hitFactor
            self.percentage = percentage
            self.matchName = matchName
            self.usedForClassification = usedForClassification
        }
    }
}

// MARK: - V2 (Legacy)
enum Schema002: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 3)

    static var models: [any PersistentModel.Type] {
        [
            StringShot.self,
            StringRun.self,
            DivisionProfile.self,
            ShooterProfile.self,
            USPSAMatch.self,
            USPSAStageScore.self,
            USPSAClassifierScore.self
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

        // Classification percentages from SCSA
        var currentPercentage: Decimal?  // Current classification percentage
        var highPercentage: Decimal?     // Highest classification percentage ever achieved
        var classificationDate: Date?    // When the current classification was earned

        init(division: Division) {
            self.division = division
        }
    }

    @Model
    final class ShooterProfile {
        var uspsaNumber: String = ""

        @Relationship(deleteRule: .cascade)
        var divisions: [DivisionProfile] = []

        init(uspsaNumber: String = "") {
            self.uspsaNumber = uspsaNumber
        }
    }

    // MARK: - USPSA Match Data Models

    @Model
    final class USPSAMatch {
        var matchId: String  // USPSA match ID
        var matchName: String
        var matchDate: Date
        var club: String
        var location: String
        var division: String
        var memberNumber: String  // Which USPSA member this belongs to

        @Relationship(deleteRule: .cascade)
        var stages: [USPSAStageScore] = []

        // Overall match statistics
        var overallPlace: Int?
        var overallPercentage: Decimal?
        var totalPoints: Decimal = 0
        var totalTime: Decimal = 0

        init(matchId: String, matchName: String, matchDate: Date, club: String, location: String, division: String, memberNumber: String) {
            self.matchId = matchId
            self.matchName = matchName
            self.matchDate = matchDate
            self.club = club
            self.location = location
            self.division = division
            self.memberNumber = memberNumber
        }
    }

    @Model
    final class USPSAStageScore {
        var stageNumber: Int
        var stageName: String
        var points: Decimal
        var time: Decimal
        var hitFactor: Decimal

        // Scoring breakdown
        var alphas: Int = 0
        var charlies: Int = 0
        var deltas: Int = 0
        var mikes: Int = 0
        var noshootsHit: Int = 0
        var procedurals: Int = 0

        // Stage placement
        var stagePlace: Int?
        var stagePercentage: Decimal?

        init(stageNumber: Int, stageName: String, points: Decimal, time: Decimal, hitFactor: Decimal) {
            self.stageNumber = stageNumber
            self.stageName = stageName
            self.points = points
            self.time = time
            self.hitFactor = hitFactor
        }
    }

    @Model
    final class USPSAClassifierScore {
        var classifierId: String  // e.g., "CM-06-01"
        var classifierName: String
        var date: Date
        var division: String
        var memberNumber: String

        // Score details
        var points: Decimal
        var time: Decimal
        var hitFactor: Decimal
        var percentage: Decimal  // Percentage of high hit factor

        // Where it was shot
        var matchId: String?
        var matchName: String

        init(classifierId: String, classifierName: String, date: Date, division: String, memberNumber: String, points: Decimal, time: Decimal, hitFactor: Decimal, percentage: Decimal, matchName: String) {
            self.classifierId = classifierId
            self.classifierName = classifierName
            self.date = date
            self.division = division
            self.memberNumber = memberNumber
            self.points = points
            self.time = time
            self.hitFactor = hitFactor
            self.percentage = percentage
            self.matchName = matchName
        }
    }
}

// MARK: - V1 (Legacy)
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
