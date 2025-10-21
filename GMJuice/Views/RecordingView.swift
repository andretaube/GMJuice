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
    
    @Query private var shooterProfiles: [ShooterProfile]
    private var shooter: ShooterProfile? {
        shooterProfiles.first
    }

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
        
        ZStack {
            
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 8) { // row 1
                    
                    // Column 1: Shot index and Percent Class
                    VStack(alignment: .leading, spacing: 2) {
                        Text("#\(vm.counter)")
                            .font(.title.bold())
                        
                        let time = vm.stringRun.time
                        
                        
                        if time > 0 {
                            infoTitle(icon: .init(systemName: "stopwatch"),
                                      label: "Current Run",
                                      color: Color.blue)
                            
                            percentClass(division: division, stageCode: stage.code, time: time)
                                                        
                        }

                        if time > 0 {
                            Spacer().frame(height: 8)
                            
                            infoTitle(icon: .init(systemName: "stopwatch"),
                                      label: stage.strings == 5 ? "Best 4 of Last 5" : "Best 3 of Last 4",
                                      color: Color.blue)
                            
                            percentClass(division: division, stageCode: stage.code, times: vm.times())
                        }
                        
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    
                    // Column 2: Big Timer
                    let time = vm.stringRun.time
                    GeometryReader { geo in
                        Text(Format.formatTime(time))
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
                        timerConnectionStatus()
                        
                        if let bestTime = vm.bestTime() {
                            infoTitle(icon: .init(systemName: "thermometer.high"), label: "Fastest", color: Color.green)
                            Text("Time: \(Format.formatTime(bestTime))")
                                .font(.system(.subheadline, weight: .medium))
                                .monospacedDigit()
                        }
                        if let bestFirstShot = vm.bestFirstShot() {
                            Text("1st: \(Format.formatTime(bestFirstShot))")
                                .font(.system(.subheadline, weight: .medium))
                                .monospacedDigit()
                        }
                        
                        Spacer().frame(height: 15)

                        if vm.counter > 1 {
                            if let worstTime = vm.worstTime() {
                                infoTitle(icon: .init(systemName: "thermometer.low"), label: "Slowest", color: Color.red)
                                Text("Time: \(Format.formatTime(worstTime))")
                                    .font(.system(.subheadline, weight: .medium))
                                    .monospacedDigit()
                            }
                            if let worstFirstShot = vm.worstFirstShot() {
                                Text("1st: \(Format.formatTime(worstFirstShot))")
                                    .font(.system(.subheadline, weight: .medium))
                                    .monospacedDigit()
                            }
                        }
                        
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    
                    
                } // end of row 1
                
                VStack(alignment: .leading, spacing: -12) { // row 2 - reduced spacing
                    if vm.stringRun.orderedStringShots.count > 0 {
                        infoTitle(icon: .init(systemName: "list.number"), label: "Shots / Splits", color: Color.blue)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(vm.stringRun.orderedStringShots) { shot in
                                VStack(spacing: 4) {
                                    // Top: cumulative offset
                                    Text("\(Format.formatTime(shot.now))")
                                        .font(.headline.bold())
                                        .monospacedDigit()
                                    
                                    // Bottom: split
                                    Text("\(Format.formatTime(shot.split))")
                                        .font(.headline)
                                        .monospacedDigit()
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding(.top, 0) // Add slight top padding to content
                    }
                    .frame(height: 88)
                }// end of row 2
            }
            .navigationTitle("\(stage.name) – \(stage.code) - \(division)")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: vm.stringRun.stringShots.count) { old, new in
                do {
                    if new >= 5 {
                        modelContext.insert(vm.stringRun)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            Announcer.shared.speak(text: "\(vm.stringRun.time)")
                        }
                        
                        try modelContext.save()
                    }
                } catch {
                    print("Failed to save StringRun: \(error.localizedDescription)")
                }
            }
            .onAppear() {
                UIApplication.shared.isIdleTimerDisabled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if vm.connectionStatus != .Connected {
                        Announcer.shared.speak(text: "Timer is not connected")
                    } else {
                        Announcer.shared.speak(text: "\(stage.name), \(division)")
                    }
                }
            }
            .onDisappear() {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
    
    @ViewBuilder
    private func infoTitle(icon: Image, label: String, color: Color) -> some View {
        HStack {
            icon
            Text(label)
        }
        .font(.system(.subheadline, weight: .medium))
        .foregroundStyle(color)
    }
    
    @ViewBuilder
    private func percentClass(division: Division, stageCode: String, time: Decimal) -> some View {
        let pct = PeakBenchmarks.percent(division: division, stageCode: stageCode, time: time)
        let percentDouble = NSDecimalNumber(decimal: pct).doubleValue
        let shooterClass = ShooterClass.shooterClass(percentage: pct)
        
        HStack {
            Text(String(format: "%.0f%% (%@)", percentDouble, shooterClass.rawValue))
            if let classification = shooter?.classification(for: division) {
                stringReward(percent: pct, shooterClass: classification)
                    .imageScale(.medium)
            }
        }
    }
    
    @ViewBuilder
    private func percentClass(division: Division, stageCode: String, times: [Decimal]) -> some View {
        let pct = PeakBenchmarks.percent(division: division, stageCode: stageCode, times: times)
        let percentDouble = NSDecimalNumber(decimal: pct).doubleValue
        let shooterClass = ShooterClass.shooterClass(percentage: pct)
        
        HStack {
            Text(String(format: "%.0f%% (%@)", percentDouble, shooterClass.rawValue))
            if let classification = shooter?.classification(for: division) {
                stringReward(percent: pct, shooterClass: classification)
                    .imageScale(.medium)
            }
        }
    }
    
    @ViewBuilder
    private func timerConnectionStatus() -> some View {
        Image(systemName: "timer")
            .foregroundColor(
                vm.connectionStatus == .Connected ? .green :
                vm.connectionStatus == .Disconnected ? .red :
                vm.connectionStatus == .Connecting ? .orange : .gray
            )
    }
    
    @ViewBuilder
    private func stringReward(
        percent: Decimal,
        shooterClass: ShooterClass
    ) -> some View {
        let threshold = shooterClass.percentThreshold
        let nextClassThreshold = shooterClass.nextClassThreshold
        
        if percent >= nextClassThreshold {
            // Shooting above your class level - trophy!
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)
        } else if percent >= threshold {
            // At your class level - thumbs up
            Image(systemName: "hand.thumbsup.fill")
                .foregroundStyle(.green)
        } else {
            // Below your class level - thumbs down
            Image(systemName: "hand.thumbsdown.fill")
                .foregroundStyle(.red)
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
        
        let shooterProfile = ShooterProfile(uspsaNumber: "A12345")
        shooterProfile.setClassification(.M, for: .RFPO)
        container.mainContext.insert(shooterProfile)
                
        // Example run with a few shots
        let sampleRun1 = StringRun(stageId: Stage.preview.code, divisionId: Division.preview.rawValue)
        sampleRun1.time = 2.12
        sampleRun1.date = Date()

        sampleRun1.stringShots = [
            StringShot(now: 0.75, split: 0.75, first: 0.75),
            StringShot(now: 1.32, split: 0.57, first: 0.75),
            StringShot(now: 1.86, split: 0.54, first: 0.75),
            StringShot(now: 2.36, split: 0.50, first: 0.75),
            StringShot(now: 2.26, split: 0.20, first: 0.75),
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
        vm.allRuns = [sampleRun1, sampleRun1, sampleRun1, sampleRun2, sampleRun1, sampleRun2, sampleRun1, sampleRun1]

        vm.stringRun = vm.allRuns.last!
        vm.counter = vm.allRuns.count

        
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
