//
//  SummaryRow.swift
//  GMJuice
//
//  Created by Andre Taube on 10/7/25.
//
import SwiftUI
import SwiftData

public struct SummaryView: View {
    let total: Int
    let fastestRun: Decimal
    let avgRun: Decimal
    let slowestRun: Decimal
    let fastestFirstShot: Decimal
    let avgFirstShot: Decimal
    let slowestFirstShot: Decimal

    public var body: some View {
        HStack {
            Metric("Runs", "\(total)")
            Divider().frame(height: 28)
            Metric("Fastest", "\(fastestRun)")
            Divider().frame(height: 28)
            Metric("Avg", "\(avgRun)")
            Divider().frame(height: 28)
            Metric("Slowest", "\(slowestRun)")
            Divider().frame(height: 28)
            Metric("Fastest 1st Shot", "\(fastestFirstShot)")
            Divider().frame(height: 28)
            Metric("Avg 1st Shot", "\(avgFirstShot)")
            Divider().frame(height: 28)
            Metric("Slowest 1st Shot", "\(slowestFirstShot)")
        }
    }

    private func Metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body).monospacedDigit()
        }
    }
}
