//
//  StringRun+Extensions.swift
//  GMJuice
//
//  Created by Andre Taube on 10/17/25.
//

extension StringRun {
    var orderedStringShots: [StringShot] {
        stringShots.sorted { $0.now < $1.now }
    }
}
