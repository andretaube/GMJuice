//
//  ShooterClass.swift
//  GMJuice
//
//  Created by Andre Taube on 10/11/25.
//

import SwiftData
import Foundation

enum ShooterClass: String, CaseIterable, Hashable, Codable, Identifiable {
    case GM, M, A, B, C, D, U
    var id: Self { self }
}

extension ShooterClass: Comparable {
    
    // MARK: - Thresholds
    
    /// Minimum percentage to achieve this classification
    var percentThreshold: Decimal {
        switch self {
        case .GM: return 95
        case .M:  return 85
        case .A:  return 75
        case .B:  return 60
        case .C:  return 40
        case .D:  return 2
        case .U:  return 0
        }
    }
    
    /// Percentage needed to reach the next higher classification
    var nextClassThreshold: Decimal {
        switch self {
        case .GM: return 100  // Beat the benchmark
        case .M:  return 95   // Reach GM
        case .A:  return 85   // Reach M
        case .B:  return 75   // Reach A
        case .C:  return 60   // Reach B
        case .D:  return 40   // Reach C
        case .U:  return 2    // Reach D
        }
    }
    
    // MARK: - Ranges
    
    /// Percentage range for this classification (for UI/display purposes)
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
    
    // MARK: - Ranking
    
    /// Numeric rank for comparison (higher is better)
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
    
    // MARK: - Classification Logic
    
    /// Determine shooter class from a percentage score
    static func shooterClass(percentage: Decimal) -> ShooterClass {
        switch percentage {
        case 95...:   return .GM
        case 85..<95: return .M
        case 75..<85: return .A
        case 60..<75: return .B
        case 40..<60: return .C
        case 2..<40:  return .D
        default:      return .U
        }
    }
    
    // MARK: - Display
    
    /// Full name of the classification
    var displayName: String {
        switch self {
        case .GM: return "Grand Master"
        case .M:  return "Master"
        case .A:  return "A Class"
        case .B:  return "B Class"
        case .C:  return "C Class"
        case .D:  return "D Class"
        case .U:  return "Unclassified"
        }
    }
}
