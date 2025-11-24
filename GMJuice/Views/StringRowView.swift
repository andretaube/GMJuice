//
//  StringRowView.swift
//  GMJuice
//
//  Created by Andre Taube on 10/6/25.
//
import SwiftUI
import Combine

// MARK: - String Row (aligned columns via Grid)

struct StringRowView: View {
    let run: StringRun
    let index: Int
    let isBest: Bool

    var body: some View {
        let shots = run.orderedStringShots

        HStack(alignment: .top, spacing: 12) {
            // Left: ID (timestamp of first shot if available, else start)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("#\(index)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if isBest {
                        Image(systemName: "trophy.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Best run")
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(timestampString(run.date))
                    .font(.headline)
            }
            .frame(minWidth: 20, alignment: .leading)
            .padding(.top, 2)

            if shots.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No shots yet").foregroundStyle(.secondary)
                    Text(" ").hidden() // keep right column vertically aligned
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    // Horizontal scroll if many columns
                    ScrollView(.horizontal, showsIndicators: false) {
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                            // Row 1: shot times (offsets)
                            GridRow {
                                ForEach(shots) { (shot) in
                                    Text(Format.formatTime(shot.now))
                                        .monospacedDigit()
                                        .foregroundStyle(.primary)
                                        .gridColumnAlignment(.trailing)
                                }
                            }
                            // Row 2: split times (no "+")
                            GridRow {
                                ForEach(shots) { (shot) in
                                    Text(Format.formatTime(shot.split))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .gridColumnAlignment(.trailing)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    // Row 3: miss indicator
                    if !run.missedTargets.isEmpty {
                        Text(missIndicator)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.formatTime(run.adjustedTime))
                    .font(.headline).bold()
                    .frame(minWidth: 10, alignment: .trailing)
                    .padding(.top, 2)

                if shots.count >= 5 {
                    if let division = Division(rawValue: run.divisionId) {
                        percentClass(division: division, stageCode: run.stageId, time: run.adjustedTime)
                    }
                } else {
                    Text(" ").font(.headline.bold())
                }
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
    
    @ViewBuilder
    private func percentClass(division: Division, stageCode: String, time: Decimal) -> some View {
        let pct = CurrentPeakBenchmarks.percent(division: division, stageCode: stageCode, time: time)
        let percentDouble = NSDecimalNumber(decimal: pct).doubleValue
        let shooterClass = ShooterClass.shooterClass(percentage: pct)

        Text(String(format: "%.0f%% (%@)", percentDouble, shooterClass.rawValue))
    }

    // Miss indicator (e.g., "2M S" = 2 misses + stop, "3M" = 3 misses, "S" = stop only)
    private var missIndicator: String {
        let regularMisses = run.missedTargets.filter { $0 != 5 }.count
        let stopMissed = run.missedTargets.contains(5)

        var result = ""
        if regularMisses > 0 {
            result += "\(regularMisses)M"
        }
        if stopMissed {
            if !result.isEmpty {
                result += " "
            }
            result += "S"
        }
        return result
    }

    // Helpers

    private func computeSplits(from offsets: [TimeInterval]) -> [TimeInterval] {
        guard !offsets.isEmpty else { return [] }
        var out: [TimeInterval] = []
        for i in offsets.indices {
            if i == 0 { out.append(offsets[i]) }
            else { out.append(offsets[i] - offsets[i - 1]) }
        }
        return out
    }

    private func timeString(_ t: TimeInterval) -> String {
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        let hundredths = Int((t - floor(t)) * 100)
        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, seconds, hundredths)
        } else {
            return String(format: "%d.%02d", seconds, hundredths)
        }
    }

    private func timestampString(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "h:mm a"
        df.amSymbol = "am"
        df.pmSymbol = "pm"
        return df.string(from: date)
    }
}
