//
//  Division.swift
//  TrainingApp
//
//  Created by Andre Taube on 10/11/25.
//

import SwiftData

enum Division: String, CaseIterable, Codable, Identifiable, Hashable {
    case RFPI, RFPO
    case RFRI, RFRO
    case CO, LTD, OPN, PROD, SS, REV, ISR
    case PCCI, PCCO

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .RFPI: return "RFPI (Rimfire Pistol Iron)"
        case .RFPO: return "RFPO (Rimfire Pistol Open)"
        case .RFRI: return "RFRI (Rimfire Rifle Iron)"
        case .RFRO: return "RFRO (Rimfire Rifle Open)"
        case .CO:   return "CO (Carry Optics)"
        case .LTD:  return "LTD (Limited)"
        case .OPN:  return "OPN (Open)"
        case .PROD: return "PROD (Production)"
        case .SS:   return "SS (Single Stack)"
        case .REV:  return "REV (Revolver)"
        case .ISR:  return "ISR (Iron Sight Revolver)"
        case .PCCI: return "PCCI (PCC Iron)"
        case .PCCO: return "PCCO (PCC Open)"
        }
    }
}
