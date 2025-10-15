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
    
    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

public let AllStages: [Stage] = [
    .init(code: "SC-101", name: "5 To Go"),
    .init(code: "SC-102", name: "Showdown"),
    .init(code: "SC-103", name: "Smoke & Hope"),
    .init(code: "SC-104", name: "Outer Limits"),
    .init(code: "SC-105", name: "Accelerator"),
    .init(code: "SC-106", name: "The Pendulum"),
    .init(code: "SC-107", name: "Speed Option"),
    .init(code: "SC-108", name: "Roundabout")
]

public func stageName(for code: String) -> String {
    AllStages.first(where: { $0.code == code })?.name ?? code
}
