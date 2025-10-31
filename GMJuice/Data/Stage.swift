//
//  Stage.swift
//  GMJuice
//
//  Created by Andre Taube on 10/6/25.
//


import Foundation

// Plate types used in Steel Challenge
public enum PlateType: Hashable {
    case round10  // 10 inch round plate
    case round12  // 12 inch round plate
    case square   // Square plate
}

// Coordinate position for target layout visualization
// x: 0.0 = left, 1.0 = right
// y: 0.0 = back, 1.0 = front
public struct TargetPosition: Hashable {
    let x: Double       // 0.0 to 1.0 (left to right)
    let y: Double       // 0.0 to 1.0 (back to front)
    let plateType: PlateType  // Type of plate

    public init(x: Double, y: Double, plateType: PlateType = .round10) {
        self.x = x
        self.y = y
        self.plateType = plateType
    }
}

public struct Stage: Identifiable, Hashable {
    public let id = UUID()
    public let code: String
    public let name: String
    public let strings: Int
    public let targetLayout: [TargetPosition]  // Position of each target using normalized coordinates

    public init(code: String, name: String, strings: Int, targetLayout: [TargetPosition]) {
        self.code = code
        self.name = name
        self.strings = strings
        self.targetLayout = targetLayout
    }
}

public let AllStages: [Stage] = [
    // SC-101: 5 To Go - Arc with stop plate in center
    .init(code: "SC-101", name: "5 To Go", strings: 5, targetLayout: [
        TargetPosition(x: 0.0, y: 0.1, plateType: .round10),
        TargetPosition(x: 0.25, y: 0.35, plateType: .round10),
        TargetPosition(x: 0.5, y: 0.60, plateType: .round10),
        TargetPosition(x: 0.75, y: 0.85, plateType: .round10),
        TargetPosition(x: 1.0, y: 0.0, plateType: .round12)
    ]),

    // SC-102: Showdown - Straight line, equal distance
    .init(code: "SC-102", name: "Showdown", strings: 5, targetLayout: [
        TargetPosition(x: 0.0, y: 1.0, plateType: .square),
        TargetPosition(x: 0.25, y: 0.0, plateType: .round10),
        TargetPosition(x: 0.75, y: 0.0, plateType: .round10),
        TargetPosition(x: 1.0, y: 1.0, plateType: .square),
        TargetPosition(x: 0.5, y: 0.5, plateType: .round12),
    ]),

    // SC-103: Smoke & Hope - 4 corners + center stop plate
    .init(code: "SC-103", name: "Smoke & Hope", strings: 5, targetLayout: [
        TargetPosition(x: 0.0, y: 0.25, plateType: .square),
        TargetPosition(x: 0.25, y: 0.5, plateType: .square),
        TargetPosition(x: 0.75, y: 0.5, plateType: .square),
        TargetPosition(x: 1.0, y: 0.25, plateType: .square),
        TargetPosition(x: 0.5, y: 1.0, plateType: .round12)
    ]),

    // SC-104: Outer Limits - 4 strings, spread out
    .init(code: "SC-104", name: "Outer Limits", strings: 4, targetLayout: [
        TargetPosition(x: 0.0, y: 0.5, plateType: .round12),
        TargetPosition(x: 0.25, y: 1.0, plateType: .square),
        TargetPosition(x: 0.75, y: 1.0, plateType: .square),
        TargetPosition(x: 1.00, y: 0.5, plateType: .round12),
        TargetPosition(x: 0.50, y: 0.0, plateType: .round12)
    ]),

    // SC-105: Accelerator - Progressive distance
    .init(code: "SC-105", name: "Accelerator", strings: 5, targetLayout: [
        TargetPosition(x: 0.0, y: 0.0, plateType: .round10),
        TargetPosition(x: 0.25, y: 0.0, plateType: .square),
        TargetPosition(x: 0.75, y: 1.0, plateType: .round12),
        TargetPosition(x: 1.00, y: 1.0, plateType: .square),
        TargetPosition(x: 0.5, y: 0.5, plateType: .round12)
    ]),

    // SC-106: The Pendulum - Pendulum arc
    .init(code: "SC-106", name: "The Pendulum", strings: 5, targetLayout: [
        TargetPosition(x: 0.0, y: 1.0, plateType: .round12),
        TargetPosition(x: 0.25, y: 1.0, plateType: .round10),
        TargetPosition(x: 0.75, y: 1.0, plateType: .round10),
        TargetPosition(x: 1.0, y: 1.0, plateType: .round12),
        TargetPosition(x: 0.5, y: 0.5, plateType: .round12)
    ]),

    // SC-107: Speed Option - Spread with options
    .init(code: "SC-107", name: "Speed Option", strings: 5, targetLayout: [
        TargetPosition(x: 0.00, y: 0.20, plateType: .round12),
        TargetPosition(x: 0.30, y: 0.45, plateType: .round12),
        TargetPosition(x: 0.80, y: 0.20, plateType: .round12),
        TargetPosition(x: 1.00, y: 0.45, plateType: .round12),
        TargetPosition(x: 0.1, y: 1.0, plateType: .square)
    ]),

    // SC-108: Roundabout - Circular arrangement
    .init(code: "SC-108", name: "Roundabout", strings: 5, targetLayout: [
        TargetPosition(x: 0.0, y: 1.0, plateType: .round12),
        TargetPosition(x: 0.25, y: 0.0, plateType: .round12),
        TargetPosition(x: 0.90, y: 1.0, plateType: .round12),
        TargetPosition(x: 1.0, y: 0.0, plateType: .round12),
        TargetPosition(x: 0.5, y: 0.5, plateType: .round12)
    ])
]

public func stageName(for code: String) -> String {
    getStage(for: code)?.name ?? code
}

public func getStage(for code: String) -> Stage? {
    AllStages.first(where: { $0.code == code })
}
