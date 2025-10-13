//
//  Shot.swift
//  TrainingApp
//
//  Created by Andre Taube on 10/6/25.
//

import Foundation
import SwiftData

@Model
final class StringShot {
    var now: Double
    var split: Double
    var first: Double

    @Relationship
    var parent: StringRun?

    init(now: Double, split: Double, first: Double) {
        self.now = now
        self.split = split
        self.first = first
    }
}
