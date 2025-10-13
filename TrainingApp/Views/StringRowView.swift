//
//  StringRowView.swift
//  TrainingApp
//
//  Created by Andre Taube on 10/6/25.
//
import SwiftUI
import Combine

// MARK: - String Row (aligned columns via Grid)

struct StringRowView: View {
    let run: StringRun
    let index: Int

    var body: some View {
        let shots = run.orderedStringShots

        HStack(alignment: .top, spacing: 12) {
            // Left: ID (timestamp of first shot if available, else start)
            VStack(alignment: .leading, spacing: 2) {
                Text(timestampString(run.date))
                    .font(.headline)
                Text("#\(index)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 20, alignment: .leading)
            .padding(.top, 2)

            // Middle: two rows with aligned columns using Grid
//            Group {
                if shots.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No shots yet").foregroundStyle(.secondary)
                        Text(" ").hidden() // keep right column vertically aligned
                    }
                } else {
                    // Horizontal scroll if many columns
                    ScrollView(.horizontal, showsIndicators: false) {
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                            // Row 1: shot times (offsets)
                            GridRow {
                                ForEach(shots) { (shot) in
                                    Text(timeString(shot.now))
                                        .monospacedDigit()
                                        .gridColumnAlignment(.trailing)
                                }
                            }
                            // Row 2: split times (no "+")
                            GridRow {
                                ForEach(shots) { (shot) in
                                    Text(timeString(shot.split))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .gridColumnAlignment(.trailing)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
//            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(timeString(run.time))
                    .font(.headline).bold()
                    .frame(minWidth: 10, alignment: .trailing)
                    .padding(.top, 2)
                
                if shots.count >= 5, let last = shots.last {
                    if let division = Division(rawValue: run.divisionId) {
                        let text = PeakBenchmarks.percentClass(
                            division: division,
                            stageCode: run.stageId,
                            lastShotTime: last.now);
                        Text(text)
                            .font(.headline.bold())
                    }
                } else {
                    Text(" ").font(.headline.bold())
                }
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
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
