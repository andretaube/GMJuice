//
//  Stage.swift
//  GMJuice
//
//  Created by Andre Taube on 10/6/25.
//


import Foundation

public struct Stage: Identifiable, Hashable {
    public let id = UUID()
    public let code: String
    public let name: String
    public let strings: Int
    
    public init(code: String, name: String, strings: Int) {
        self.code = code
        self.name = name
        self.strings = strings
    }
}

public let AllStages: [Stage] = [
    .init(code: "SC-101", name: "5 To Go", strings: 5),
    .init(code: "SC-102", name: "Showdown", strings: 5),
    .init(code: "SC-103", name: "Smoke & Hope", strings: 5),
    .init(code: "SC-104", name: "Outer Limits", strings: 4),
    .init(code: "SC-105", name: "Accelerator", strings: 5),
    .init(code: "SC-106", name: "The Pendulum", strings: 5),
    .init(code: "SC-107", name: "Speed Option", strings: 5),
    .init(code: "SC-108", name: "Roundabout", strings: 5)
]

public func stageName(for code: String) -> String {
    getStage(for: code)?.name ?? code
}

public func getStage(for code: String) -> Stage? {
    AllStages.first(where: { $0.code == code })
}
