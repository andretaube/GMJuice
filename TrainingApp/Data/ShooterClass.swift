//
//  ShooterClass.swift
//  TrainingApp
//
//  Created by Andre Taube on 10/11/25.
//


import SwiftData

enum ShooterClass: String, CaseIterable, Hashable, Codable, Identifiable {
    case GM, M, A, B, C, D, U
    var id: Self { self }
}

extension ShooterClass: Comparable {
    
    var percentRange: Range<Double> {
        switch self {
        case .GM: return 95..<1000
        case .M:  return 85..<95
        case .A:  return 75..<85
        case .B:  return 60..<75
        case .C:  return 40..<60
        case .D:  return 2..<40
        case .U:  return 0..<2
        }
    }
    
    var rank: Int {
        switch self {
        case .GM: return 7
        case .M:  return 6
        case .A:  return 5
        case .B:  return 4
        case .C:  return 3
        case .D:  return 2
        case .U:  return 1
        }
    }
    
    static func < (lhs: ShooterClass, rhs: ShooterClass) -> Bool {
        lhs.rank < rhs.rank
    }
}
