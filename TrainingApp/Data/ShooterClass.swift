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
