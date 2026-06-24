//
//  TargetTimesView.swift
//  GMJuice
//
//  Static reference ("range card"): pick a division, see the total and per-string
//  target time for every stage at each classification level. Not based on the
//  user's own performance — pure benchmark reference. Reads CurrentPeakBenchmarks
//  (Firebase-backed with local fallback), so it works offline.
//

import SwiftUI

struct TargetTimesView: View {
    @State private var selectedDivision: Division = .RFPI

    private let classes: [ShooterClass] = [.C, .B, .A, .M, .GM]
    private let divisions: [Division] = [.RFPO, .RFPI, .OPN, .CO, .PROD, .SS, .ISR, .OSR]

    private let stageColWidth: CGFloat = 92
    private let colWidth: CGFloat = 72

    var body: some View {
        VStack(spacing: 0) {
            // Division selector — horizontal, one line
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(divisions, id: \.self) { div in
                        let isOn = selectedDivision == div
                        Button {
                            selectedDivision = div
                        } label: {
                            Text(div.rawValue)
                                .font(.subheadline)
                                .fontWeight(isOn ? .semibold : .regular)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isOn ? Color.orange : Color(.systemGray5))
                                .foregroundStyle(isOn ? Color.white : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }

            Divider()

            Text("Total time, with per-string time below it — what each class needs.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                Grid(alignment: .center, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        headerCell("Stage", leading: true)
                        ForEach(classes, id: \.self) { headerCell($0.rawValue) }
                        headerCell("Peak")
                    }
                    .background(Color(.systemGray6))

                    ForEach(AllStages) { stage in
                        Divider().gridCellColumns(classes.count + 2)
                        GridRow {
                            stageCell(stage)
                            ForEach(classes, id: \.self) { cls in
                                valueCell(total: total(stage, cls.percentThreshold), counted: counted(stage))
                            }
                            peakCell(stage)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color.gmBg.ignoresSafeArea())
        .navigationTitle("Target Times")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Calculations

    /// Number of scored strings for a stage (best N-1 of N): 4 for most, 3 for Outer Limits.
    private func counted(_ stage: Stage) -> Decimal { Decimal(max(stage.strings - 1, 1)) }

    private func peak(_ stage: Stage) -> Decimal? {
        CurrentPeakBenchmarks.get(division: selectedDivision, stageCode: stage.code)?.peakTime
    }

    /// Target total time to reach a classification percentage: peak / percent * 100.
    private func total(_ stage: Stage, _ percent: Decimal) -> Decimal? {
        guard let p = peak(stage), percent > 0 else { return nil }
        return p / percent * 100
    }

    private func fmt(_ d: Decimal) -> String {
        String(format: "%.2f", NSDecimalNumber(decimal: d).doubleValue)
    }

    // MARK: - Cells

    @ViewBuilder private func headerCell(_ text: String, leading: Bool = false) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(width: leading ? stageColWidth : colWidth, alignment: leading ? .leading : .center)
            .padding(.vertical, 10)
            .padding(.leading, leading ? 12 : 0)
    }

    @ViewBuilder private func stageCell(_ stage: Stage) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(stage.code).font(.caption.weight(.semibold))
            Text(stage.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(width: stageColWidth, alignment: .leading)
        .padding(.leading, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder private func valueCell(total: Decimal?, counted: Decimal) -> some View {
        if let total {
            VStack(spacing: 1) {
                Text(fmt(total)).font(.subheadline.weight(.medium)).monospacedDigit()
                Text(fmt(total / counted)).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
            .frame(width: colWidth)
            .padding(.vertical, 7)
        } else {
            Text("—").foregroundStyle(.secondary).frame(width: colWidth).padding(.vertical, 7)
        }
    }

    @ViewBuilder private func peakCell(_ stage: Stage) -> some View {
        if let p = peak(stage) {
            VStack(spacing: 1) {
                Text(fmt(p)).font(.subheadline.weight(.medium)).foregroundStyle(.yellow).monospacedDigit()
                Text(fmt(p / counted(stage))).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
            .frame(width: colWidth)
            .padding(.vertical, 7)
        } else {
            Text("—").foregroundStyle(.secondary).frame(width: colWidth).padding(.vertical, 7)
        }
    }
}
