//
//  PeakBenchmark.swift
//  TrainingApp
//
//  Created by Andre Taube on 10/7/25.
//

import Foundation

// Seed table for Steel Challenge using the Division enum
public var PeakBenchmarks: PeakTable = {
    var t = PeakTable()

    // MARK: - RFPO (Rimfire Pistol Open)
    t.set(division: .RFPO, stageCode: "SC-101", strings: 4, peakTime: 8.75)
    t.set(division: .RFPO, stageCode: "SC-102", strings: 4, peakTime: 7.50)
    t.set(division: .RFPO, stageCode: "SC-103", strings: 4, peakTime: 7.00)
    t.set(division: .RFPO, stageCode: "SC-104", strings: 3, peakTime: 11.50) // Outer Limits = 3
    t.set(division: .RFPO, stageCode: "SC-105", strings: 4, peakTime: 8.50)
    t.set(division: .RFPO, stageCode: "SC-106", strings: 4, peakTime: 9.50)
    t.set(division: .RFPO, stageCode: "SC-107", strings: 4, peakTime: 10.00)
    t.set(division: .RFPO, stageCode: "SC-108", strings: 4, peakTime: 7.50)

    // MARK: - RFPI (Rimfire Pistol Iron)
    t.set(division: .RFPI, stageCode: "SC-101", strings: 4, peakTime: 10.50)
    t.set(division: .RFPI, stageCode: "SC-102", strings: 4, peakTime: 9.00)
    t.set(division: .RFPI, stageCode: "SC-103", strings: 4, peakTime: 8.00)
    t.set(division: .RFPI, stageCode: "SC-104", strings: 3, peakTime: 13.00)
    t.set(division: .RFPI, stageCode: "SC-105", strings: 4, peakTime: 9.25)
    t.set(division: .RFPI, stageCode: "SC-106", strings: 4, peakTime: 11.00)
    t.set(division: .RFPI, stageCode: "SC-107", strings: 4, peakTime: 11.00)
    t.set(division: .RFPI, stageCode: "SC-108", strings: 4, peakTime: 8.25)

    // MARK: - RFRO (Rimfire Rifle Open)
    t.set(division: .RFRO, stageCode: "SC-101", strings: 4, peakTime: 9.50)
    t.set(division: .RFRO, stageCode: "SC-102", strings: 4, peakTime: 7.00)
    t.set(division: .RFRO, stageCode: "SC-103", strings: 4, peakTime: 7.00)
    t.set(division: .RFRO, stageCode: "SC-104", strings: 3, peakTime: 10.75)
    t.set(division: .RFRO, stageCode: "SC-105", strings: 4, peakTime: 8.50)
    t.set(division: .RFRO, stageCode: "SC-106", strings: 4, peakTime: 9.00)
    t.set(division: .RFRO, stageCode: "SC-107", strings: 4, peakTime: 9.00)
    t.set(division: .RFRO, stageCode: "SC-108", strings: 4, peakTime: 7.00)

    // MARK: - RFRI (Rimfire Rifle Iron)
    t.set(division: .RFRI, stageCode: "SC-101", strings: 4, peakTime: 9.75)
    t.set(division: .RFRI, stageCode: "SC-102", strings: 4, peakTime: 7.50)
    t.set(division: .RFRI, stageCode: "SC-103", strings: 4, peakTime: 7.50)
    t.set(division: .RFRI, stageCode: "SC-104", strings: 3, peakTime: 12.00)
    t.set(division: .RFRI, stageCode: "SC-105", strings: 4, peakTime: 9.00)
    t.set(division: .RFRI, stageCode: "SC-106", strings: 4, peakTime: 9.75)
    t.set(division: .RFRI, stageCode: "SC-107", strings: 4, peakTime: 10.00)
    t.set(division: .RFRI, stageCode: "SC-108", strings: 4, peakTime: 7.50)

    // MARK: - PCCO (PCC Open)
    t.set(division: .PCCO, stageCode: "SC-101", strings: 4, peakTime: 9.50)
    t.set(division: .PCCO, stageCode: "SC-102", strings: 4, peakTime: 7.00)
    t.set(division: .PCCO, stageCode: "SC-103", strings: 4, peakTime: 7.00)
    t.set(division: .PCCO, stageCode: "SC-104", strings: 3, peakTime: 11.25)
    t.set(division: .PCCO, stageCode: "SC-105", strings: 4, peakTime: 8.75)
    t.set(division: .PCCO, stageCode: "SC-106", strings: 4, peakTime: 9.00)
    t.set(division: .PCCO, stageCode: "SC-107", strings: 4, peakTime: 9.50)
    t.set(division: .PCCO, stageCode: "SC-108", strings: 4, peakTime: 7.50)

    // MARK: - PCCI (PCC Iron)
    t.set(division: .PCCI, stageCode: "SC-101", strings: 4, peakTime: 10.75)
    t.set(division: .PCCI, stageCode: "SC-102", strings: 4, peakTime: 8.50)
    t.set(division: .PCCI, stageCode: "SC-103", strings: 4, peakTime: 7.75)
    t.set(division: .PCCI, stageCode: "SC-104", strings: 3, peakTime: 12.25)
    t.set(division: .PCCI, stageCode: "SC-105", strings: 4, peakTime: 9.50)
    t.set(division: .PCCI, stageCode: "SC-106", strings: 4, peakTime: 10.50)
    t.set(division: .PCCI, stageCode: "SC-107", strings: 4, peakTime: 11.00)
    t.set(division: .PCCI, stageCode: "SC-108", strings: 4, peakTime: 8.00)

    // MARK: - CO (Carry Optics)
    t.set(division: .CO, stageCode: "SC-101", strings: 4, peakTime: 12.50)
    t.set(division: .CO, stageCode: "SC-102", strings: 4, peakTime: 9.75)
    t.set(division: .CO, stageCode: "SC-103", strings: 4, peakTime: 10.00)
    t.set(division: .CO, stageCode: "SC-104", strings: 3, peakTime: 13.75)
    t.set(division: .CO, stageCode: "SC-105", strings: 4, peakTime: 11.00)
    t.set(division: .CO, stageCode: "SC-106", strings: 4, peakTime: 12.75)
    t.set(division: .CO, stageCode: "SC-107", strings: 4, peakTime: 13.00)
    t.set(division: .CO, stageCode: "SC-108", strings: 4, peakTime: 9.75)

    // MARK: - LTD (Limited)
    t.set(division: .LTD, stageCode: "SC-101", strings: 4, peakTime: 12.50)
    t.set(division: .LTD, stageCode: "SC-102", strings: 4, peakTime: 9.50)
    t.set(division: .LTD, stageCode: "SC-103", strings: 4, peakTime: 9.50)
    t.set(division: .LTD, stageCode: "SC-104", strings: 3, peakTime: 13.50)
    t.set(division: .LTD, stageCode: "SC-105", strings: 4, peakTime: 10.50)
    t.set(division: .LTD, stageCode: "SC-106", strings: 4, peakTime: 12.50)
    t.set(division: .LTD, stageCode: "SC-107", strings: 4, peakTime: 12.50)
    t.set(division: .LTD, stageCode: "SC-108", strings: 4, peakTime: 9.50)

    // MARK: - OPN (Open)
    t.set(division: .OPN, stageCode: "SC-101", strings: 4, peakTime: 11.25)
    t.set(division: .OPN, stageCode: "SC-102", strings: 4, peakTime: 9.50)
    t.set(division: .OPN, stageCode: "SC-103", strings: 4, peakTime: 8.50)
    t.set(division: .OPN, stageCode: "SC-104", strings: 3, peakTime: 12.50)
    t.set(division: .OPN, stageCode: "SC-105", strings: 4, peakTime: 10.50)
    t.set(division: .OPN, stageCode: "SC-106", strings: 4, peakTime: 11.25)
    t.set(division: .OPN, stageCode: "SC-107", strings: 4, peakTime: 11.50)
    t.set(division: .OPN, stageCode: "SC-108", strings: 4, peakTime: 8.50)

    // MARK: - PROD (Production)
    t.set(division: .PROD, stageCode: "SC-101", strings: 4, peakTime: 13.00)
    t.set(division: .PROD, stageCode: "SC-102", strings: 4, peakTime: 10.00)
    t.set(division: .PROD, stageCode: "SC-103", strings: 4, peakTime: 10.00)
    t.set(division: .PROD, stageCode: "SC-104", strings: 3, peakTime: 14.00)
    t.set(division: .PROD, stageCode: "SC-105", strings: 4, peakTime: 11.50)
    t.set(division: .PROD, stageCode: "SC-106", strings: 4, peakTime: 13.00)
    t.set(division: .PROD, stageCode: "SC-107", strings: 4, peakTime: 13.00)
    t.set(division: .PROD, stageCode: "SC-108", strings: 4, peakTime: 10.00)

    // MARK: - SS (Single Stack)
    t.set(division: .SS, stageCode: "SC-101", strings: 4, peakTime: 13.25)
    t.set(division: .SS, stageCode: "SC-102", strings: 4, peakTime: 10.50)
    t.set(division: .SS, stageCode: "SC-103", strings: 4, peakTime: 10.25)
    t.set(division: .SS, stageCode: "SC-104", strings: 3, peakTime: 14.75)
    t.set(division: .SS, stageCode: "SC-105", strings: 4, peakTime: 11.75)
    t.set(division: .SS, stageCode: "SC-106", strings: 4, peakTime: 13.50)
    t.set(division: .SS, stageCode: "SC-107", strings: 4, peakTime: 13.50)
    t.set(division: .SS, stageCode: "SC-108", strings: 4, peakTime: 10.50)

    // MARK: - ISR (Iron Sight Revolver)
    t.set(division: .ISR, stageCode: "SC-101", strings: 4, peakTime: 13.50)
    t.set(division: .ISR, stageCode: "SC-102", strings: 4, peakTime: 12.00)
    t.set(division: .ISR, stageCode: "SC-103", strings: 4, peakTime: 10.50)
    t.set(division: .ISR, stageCode: "SC-104", strings: 3, peakTime: 15.75)
    t.set(division: .ISR, stageCode: "SC-105", strings: 4, peakTime: 13.00)
    t.set(division: .ISR, stageCode: "SC-106", strings: 4, peakTime: 14.25)
    t.set(division: .ISR, stageCode: "SC-107", strings: 4, peakTime: 14.00)
    t.set(division: .ISR, stageCode: "SC-108", strings: 4, peakTime: 11.00)

    // MARK: - OSR (Open Sight Revolver)
    t.set(division: .OSR, stageCode: "SC-101", strings: 4, peakTime: 12.25)
    t.set(division: .OSR, stageCode: "SC-102", strings: 4, peakTime: 10.50)
    t.set(division: .OSR, stageCode: "SC-103", strings: 4, peakTime: 10.00)
    t.set(division: .OSR, stageCode: "SC-104", strings: 3, peakTime: 14.25)
    t.set(division: .OSR, stageCode: "SC-105", strings: 4, peakTime: 12.75)
    t.set(division: .OSR, stageCode: "SC-106", strings: 4, peakTime: 13.50)
    t.set(division: .OSR, stageCode: "SC-107", strings: 4, peakTime: 12.75)
    t.set(division: .OSR, stageCode: "SC-108", strings: 4, peakTime: 10.50)

    return t

}()

/// Benchmark for a division+stage: e.g. strings: 4, peakTime: 8.75 (seconds)
public struct PeakBenchmark: Codable, Hashable {
    public var strings: Int
    public var peakTime: Double   // total time for `strings` strings

    public init(strings: Int, peakTime: Double) {
        self.strings = strings
        self.peakTime = peakTime
    }

    /// Average time per string (lower is better).
    public var stringPace: Double {
        guard strings > 0 else { return 0 }
        return peakTime / Double(strings)
    }

    /// Strings per second (higher is better).
    public var stringsPerSecond: Double {
        guard peakTime > 0 else { return 0 }
        return Double(strings) / peakTime
    }
}

/// A table of peak benchmarks keyed by Division → stageCode.
public struct PeakTable: Codable {
    private var store: [Division: [String: PeakBenchmark]] = [:] // division -> stageCode -> benchmark

    public init() {}
    init(seed: [Division: [String: PeakBenchmark]]) { self.store = seed }

    // MARK: - Access

    func get(division: Division, stageCode: String) -> PeakBenchmark? {
        store[division]?[stageCode]
    }

    subscript(_ division: Division, _ stageCode: String) -> PeakBenchmark? {
        get { store[division]?[stageCode] }
        set {
            if let value = newValue {
                var stages = store[division] ?? [:]
                stages[stageCode] = value
                store[division] = stages
            } else {
                // remove
                store[division]?[stageCode] = nil
                if store[division]?.isEmpty == true {
                    store[division] = nil
                }
            }
        }
    }

    // MARK: - Mutation helpers

    mutating func set(division: Division, stageCode: String, strings: Int, peakTime: Double) {
        self[division, stageCode] = PeakBenchmark(strings: strings, peakTime: peakTime)
    }

    // MARK: - Single-string classification (pass last shot time)

    /// Returns something like "87% (A)" for a single-string performance vs the peak pace.
    func percentClass(division: Division,
                             stageCode: String,
                             lastShotTime: Double) -> String {
        // Caller should ensure ≥5 shots; we just compute.
        guard lastShotTime > 0,
              let bm = get(division: division, stageCode: stageCode),
              bm.strings > 0 else { return "" }

        // Compare your single-string total time to the peak per-string pace.
        let peakPerString = bm.peakTime / Double(bm.strings)
        let percent = (peakPerString / lastShotTime) * 100.0

        let rounded = percent.isFinite ? percent.rounded() : 0
        return String(format: "%.0f%% (%@)", rounded, grade(for: percent))
    }

    private func grade(for percent: Double) -> String {
        switch percent {
        case 95...:   return "GM"
        case 85..<95: return "M"
        case 75..<85: return "A"
        case 60..<75: return "B"
        case 40..<60: return "C"
        case 2..<40:  return "D"
        default:      return "U"
        }
    }
}
