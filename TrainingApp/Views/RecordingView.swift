import SwiftUI
import Combine
import SwiftData

struct RecordingView: View {
    let stage: Stage
    let division: Division

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @ObservedObject private var announcer = Announcer.shared
    
    @StateObject private var vm: RecordingViewModel

    @MainActor
    init(stage: Stage, division: Division) {
        self.stage = stage
        self.division = division
        _vm = StateObject(wrappedValue: RecordingViewModel(stageId: stage.code, divisionId: division.id))
    }


    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        // Display count of shots as the "run index" proxy
                        Text("#\(vm.counter)")
                            .font(.title.bold())

                        if vm.stringRun.stringShots.count >= 5 {
                            let time = vm.stringRun.time
                            let text = PeakBenchmarks.percentClass(
                                division: division,
                                stageCode: stage.code,
                                lastShotTime: time
                            )
                            Text(text).font(.title.bold())
                        } else {
                            Text(" ").font(.title.bold())
                        }
                    }
                    .padding(.leading, 8)

                    Spacer()
                }
                .padding(.top, 8)

                Spacer()

                // Big centered "timer" shows the latest offset (or 0.00)
                let time = vm.stringRun.time
                Text(timeString(time))
                    .monospacedDigit()
                    .font(.system(size: 200, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                Spacer()

                // Shots row
                if !vm.stringRun.stringShots.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            // Shots row
                            ScrollView(.horizontal, showsIndicators: false) {

                                HStack(spacing: 12) {
                                    ForEach(vm.stringRun.orderedStringShots) { shot in

                                        VStack(spacing: 4) {
                                            // Top: cumulative offset
                                            Text(timeString(shot.now))
                                                .font(.headline.bold())
                                                .monospacedDigit()

                                            // Bottom: split
                                            Text(timeString(shot.split))
                                                .font(.headline)
                                                .monospacedDigit()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .overlay(alignment: .trailing) {
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(height: 88) // a bit taller for two rows
                            .padding(.bottom)

                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 60)
                    .padding(.bottom)
                } else {
                    Text(" ")
                        .hidden()
                        .frame(height: 60)
                        .padding(.bottom)
                }
            }
            .navigationTitle("\(stage.name) – \(stage.code)")
        }
        .onChange(of: vm.stringRun.stringShots.count) { old, new in
            do {
        
                if old < 5 && new >= 5 {
                    modelContext.insert(vm.stringRun)
                    Announcer.shared.speak(text: timeString(vm.stringRun.time))
                    
                    Announcer.shared.speak(text: PeakBenchmarks.percentClass(
                        division: division,
                        stageCode: stage.code,
                        lastShotTime: vm.stringRun.time))
                    
                    try modelContext.save()
                }

                else if new > 5 && new > old {
                    modelContext.insert(vm.stringRun)
                    Announcer.shared.speak(text: timeString(vm.stringRun.time))
                    Announcer.shared.speak(text: PeakBenchmarks.percentClass(
                        division: division,
                        stageCode: stage.code,
                        lastShotTime: vm.stringRun.time))
                    try modelContext.save()
                }

            } catch {
                print("Failed to save StringRun: \(error.localizedDescription)")
            }
            
        }
    }


    // MARK: - Helpers

    private func timeString(_ t: Double) -> String {
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        let hundredths = Int((t - floor(t)) * 100)
        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, seconds, hundredths)
        } else {
            return String(format: "%d.%02d", seconds, hundredths)
        }
    }
}
