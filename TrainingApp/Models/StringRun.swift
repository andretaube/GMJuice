import Foundation
import SwiftData

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
