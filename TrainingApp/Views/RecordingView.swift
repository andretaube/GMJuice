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
    
    @Query private var profiles: [ShooterProfile]

    @MainActor
    init(stage: Stage, division: Division, vm: RecordingViewModel? = nil) {
        self.stage = stage
        self.division = division
        
        if let vm {
            _vm = StateObject(wrappedValue: vm)
        }
        else {
            _vm = StateObject(wrappedValue: RecordingViewModel(stageId: stage.code, divisionId: division.id))
        }
    }


    var body: some View {
        
        let classification = profiles.first?
            .profile(for: division)?
            .classification ?? .U
        ZStack {
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 8) { // row 1
                    
                    // Column 1: Shot index and Percent Class
                    VStack(alignment: .leading, spacing: 2) {
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
                            
                            performanceIcon(for: time, classification: classification)
                                .padding(.top, 4)
                        } else {
                            Text(" ").font(.title.bold())
                        }
                        
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    
                    // Column 2: Big Timer
                    let time = vm.stringRun.time
                    GeometryReader { geo in
                        Text(timeString(time))
                            .monospacedDigit()
                            .font(.system(size: geo.size.height * 1.0, weight: .bold)) // scale with height
                            .lineLimit(1)
                            .scaleEffect(1.3)
                            .minimumScaleFactor(0.1)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    
                    // Column 3
                    VStack(alignment: .trailing, spacing: 2) {
                        if let bestTime = vm.bestTime() {
                            Text("🏁 Run: \(timeString(bestTime))")
                                .font(.title3.bold())
                                .monospacedDigit()
                        }
                        if let bestFirstShot = vm.bestFirstShot() {
                            Text("⚡️ 1st: \(timeString(bestFirstShot))")
                                .font(.title3.bold())
                                .monospacedDigit()
                        }
                        
                        Spacer().frame(height: 15)
                        
                        if let worstTime = vm.worstTime() {
                            Text("🐌 Run: \(timeString(worstTime))")
                                .font(.title3.bold())
                                .monospacedDigit()
                        }
                        if let worstFirstShot = vm.worstFirstShot() {
                            Text("💤 1st: \(timeString(worstFirstShot))")
                                .font(.title3.bold())
                                .monospacedDigit()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    
                    
                } // end of row 1
                
                HStack { // row 2
                    ScrollView(.horizontal, showsIndicators: false) {
                        
                        HStack {
                            ForEach(vm.stringRun.orderedStringShots) { shot in
                                
                                VStack(spacing: 8) {
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
                                .overlay(alignment: .leading) {
                                }
                            }
                        }
                    }
                    .frame(height: 88) // a bit taller for two rows
                    .padding(.bottom)
                }
            }// end of row 2
            .navigationTitle("\(stage.name) – \(stage.code) - \(division)")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: vm.stringRun.stringShots.count) { old, new in
                do {
                    if new >= 5 {
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
    
    @ViewBuilder
    private func performanceIcon(for time: Double, classification: ShooterClass) -> some View {
        let percent = PeakBenchmarks.percent(
            division: division,
            stageCode: stage.code,
            time: time
        )

        let stringClass = PeakTable.shooterClass(percentage: percent)
        
        if ( stringClass > classification ) {
            Text("🏆").font(.system(size: 50)).fixedSize()
        } else if ( classification == stringClass) {
            Text("🥈").font(.system(size: 50)).fixedSize()
        }
        else {
            Text("💀").font(.system(size: 50)).fixedSize()
        }
    }

}


#if DEBUG
import SwiftUI
import SwiftData

// MARK: - Sample data just for previews
extension Stage {
    static let preview = AllStages[0]
}
extension Division {
    static let preview: Division = .RFPO
}

// MARK: - Preview
@MainActor
struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        // In-memory SwiftData store for previews
        let container = try! ModelContainer(
            for: StringRun.self, StringShot.self, ShooterProfile.self, DivisionProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
                
        // Example run with a few shots
        let sampleRun = StringRun(stageId: Stage.preview.code, divisionId: Division.preview.rawValue)
        sampleRun.time = 2.36
        sampleRun.date = Date()

        sampleRun.stringShots = [
            StringShot(now: 0.75, split: 0.75, first: 0.75),
            StringShot(now: 1.32, split: 0.57, first: 0.75),
            StringShot(now: 1.86, split: 0.54, first: 0.75),
            StringShot(now: 2.36, split: 0.50, first: 0.75),
            StringShot(now: 2.56, split: 0.20, first: 0.75),
        ]
        
        // bad run
        
        let sampleRun2 = StringRun(stageId: Stage.preview.code, divisionId: Division.preview.rawValue)
        sampleRun2.time = 3.36
        sampleRun2.date = Date()

        sampleRun2.stringShots = [
            StringShot(now: 0.9, split: 0.9, first: 0.9),
            StringShot(now: 1.32, split: 0.57, first: 0.9),
            StringShot(now: 1.86, split: 0.54, first: 0.9),
            StringShot(now: 2.36, split: 0.50, first: 0.9),
            StringShot(now: 3.36, split: 1.00, first: 0.9),
        ]
                
        let vm = RecordingViewModel(stageId: Stage.preview.code, divisionId: Division.preview.rawValue)
        vm.stringRun = sampleRun
        vm.counter = 2
        vm.allRuns = [sampleRun, sampleRun2]

        // Mute the announcer in previews
        Announcer.shared.isEnabled = false

        return NavigationStack {
            RecordingView(stage: .preview, division: .preview, vm: vm)
                .modelContainer(container)
                .padding()
        }
    }
}
#endif
