//
//  TrainView.swift
//  GMJuice
//

import SwiftUI
import Foundation

struct TrainView: View {
    @AppStorage("scsa_active_division") private var activeDivisionRaw: String = Division.RFPO.rawValue

    @State private var navigationPath = NavigationPath()
    @State private var showingTutorial = false
    @EnvironmentObject private var bleManager: BLEManager

    private let analytics = AnalyticsService.shared

    private var selectedDivision: Binding<Division> {
        Binding(
            get: { Division(rawValue: activeDivisionRaw) ?? .RFPO },
            set: { activeDivisionRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Division — horizontal, one line
                    GMLabel("Division")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Division.allCases) { div in
                                divisionPill(div)
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    // Stages
                    GMLabel("Stage")
                    VStack(spacing: 0) {
                        ForEach(Array(AllStages.enumerated()), id: \.element.id) { idx, stage in
                            Button {
                                analytics.trackStageSelection(stage: stage.code, division: selectedDivision.wrappedValue.rawValue, mode: "timer")
                                navigationPath.append(NavigationDestination.timer(stage: stage, division: selectedDivision.wrappedValue))
                            } label: {
                                stageRow(stage)
                            }
                            .buttonStyle(.plain)
                            if idx < AllStages.count - 1 {
                                Divider().overlay(Color.gmLine)
                            }
                        }
                    }
                    .background(Color.gmPanel)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.gmLine, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(16)
            }
            .gmScreenBackground()
            .navigationTitle("Train")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingTutorial = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .tint(.gmInk2)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink(value: TrainNavigationPill.timerLog) {
                        Text("Log").font(.system(size: 14, weight: .semibold))
                    }
                    NavigationLink(value: TrainNavigationPill.targetTimes) {
                        Text("Targets").font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .onAppear {
                analytics.trackScreen("TrainView")
                analytics.setDivisionProperty(selectedDivision.wrappedValue.rawValue)
            }
            .sheet(isPresented: $showingTutorial) {
                TrainTutorialView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .timer(let stage, let division):
                    RecordingView(
                        stage: stage,
                        division: division,
                        vm: RecordingViewModel(stageId: stage.code, divisionId: division.id)
                    )
                }
            }
            .navigationDestination(for: TrainNavigationPill.self) { pill in
                switch pill {
                case .timerLog: LogView()
                case .targetTimes: TargetTimesView()
                }
            }
        }
    }

    // MARK: - Pieces

    private func divisionPill(_ div: Division) -> some View {
        let isOn = selectedDivision.wrappedValue == div
        return Button {
            selectedDivision.wrappedValue = div
        } label: {
            Text(div.rawValue)
                .font(.system(size: 13, weight: isOn ? .semibold : .regular))
                .tracking(0.5)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isOn ? Color(gmHex: 0x1A1205) : Color.gmInk2)
                .background(isOn ? Color.gmAmber : Color.gmPanel2)
                .overlay(Capsule().strokeBorder(isOn ? Color.clear : Color.gmLine, lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func stageRow(_ stage: Stage) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(stage.code) · \(stage.name)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.gmInk)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.gmAmber)
                .frame(width: 30, height: 30)
                .background(Color.gmAmber.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gmAmber.opacity(0.35), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

// Navigation
enum TrainNavigationPill: Hashable {
    case timerLog
    case targetTimes
}

enum NavigationDestination: Hashable {
    case timer(stage: Stage, division: Division)
}

#Preview {
    TrainView()
        .environmentObject(BLEManager.shared)
}
