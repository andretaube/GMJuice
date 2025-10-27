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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Metric("Runs", "\(total)")
                Divider().frame(height: 28)
                Metric("Fist", Format.formatTime(fastestRun))
                Divider().frame(height: 28)
                Metric("Avg", Format.formatTime(avgRun))
                Divider().frame(height: 28)
                Metric("Slow", Format.formatTime(slowestRun))
                Divider().frame(height: 28)
                Metric("Fast 1st", Format.formatTime(fastestFirstShot))
                Divider().frame(height: 28)
                Metric("Avg 1st", Format.formatTime(avgFirstShot))
                Divider().frame(height: 28)
                Metric("Slow 1st", Format.formatTime(slowestFirstShot))
            }
        }
    }

    private func Metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.body)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}
