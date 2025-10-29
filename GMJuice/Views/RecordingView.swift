import SwiftUI
import Combine
import SwiftData
import UIKit

struct RecordingView: View {
    let stage: Stage
    let division: Division
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @ObservedObject private var announcer = Announcer.shared
    @ObservedObject private var recordingManager = RecordingManager.shared

    @StateObject private var vm: RecordingViewModel
    @State private var isOrientationReady = false
    @State private var autoAnnounceTask: Task<Void, Never>?
    @State private var lastAnnouncedShotCount = 0
    @State private var previousConnectionStatus: BLEConnectionStatus = .Disconnected

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
            if isOrientationReady {
                VStack {
                    HStack(alignment: .top, spacing: 16) {
                        leftColumn
                        timerDisplay.frame(maxWidth: .infinity).padding(.top, 40)
                        rightColumn
                    }
                    .frame(maxWidth: .infinity)

                    shotsAndSplits
                }
                .padding()
                .frame(maxWidth: .infinity)
            }

            if !isOrientationReady {
                // Show splash screen while rotating to landscape
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()

                    GeometryReader { geo in
                        let imageWidth = geo.size.width * 0.356
                        Image("GMJuiceRound")
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageWidth)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .navigationTitle(isOrientationReady ? "\(stage.name) – \(stage.code) - \(division)" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isOrientationReady ? .visible : .hidden, for: .navigationBar)
        .onChange(of: recordingManager.stringCounter) { _, _ in
            // Reset announcement tracking when a new string starts
            lastAnnouncedShotCount = 0
        }
        .onChange(of: recordingManager.shotCount) { old, new in
            // Only trigger when reaching or exceeding 5 shots for the first time
            if new >= 5 && new != lastAnnouncedShotCount {
                lastAnnouncedShotCount = new

                // Cancel any pending announcement
                autoAnnounceTask?.cancel()

                // Capture current string to avoid race condition
                guard let stringToAnnounce = recordingManager.currentString else {
                    return
                }

                // Schedule new announcement
                autoAnnounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)

                    guard !Task.isCancelled else { return }

                    let adjustedTime = stringToAnnounce.adjustedTime

                    // Calculate classification for this time
                    let pct = PeakBenchmarks.percent(division: division, stageCode: stage.code, time: adjustedTime)
                    let shooterClass = ShooterClass.shooterClass(percentage: pct)

                    print("📢 Auto-announcing time: \(adjustedTime) (\(shooterClass.rawValue))")
                    announcer.speak(text: "\(Format.formatTime(adjustedTime)), \(shooterClass.rawValue)")
                }
            }
        }
        .onChange(of: vm.connectionStatus) { oldStatus, newStatus in
            // Announce when timer connects (but not on initial connection or reconnections)
            if newStatus == .Connected && previousConnectionStatus != .Connected {
                print("📢 Timer connected")
                announcer.speak(text: "Timer connected")
            }
            previousConnectionStatus = newStatus
        }
        .onAppear() {
            // Reset announcement tracking
            lastAnnouncedShotCount = 0

            // Set initial connection status (no announcement on first appear)
            previousConnectionStatus = vm.connectionStatus

            // Start recording session
            recordingManager.startSession(stageId: stage.code, divisionId: division.id, modelContext: modelContext)

            // Lock to landscape orientation
            AppDelegate.orientationLock = .landscape

            // Safely get active window scene
            if let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
            } else {
                print("⚠️ Could not get window scene for orientation lock")
            }

            UIApplication.shared.isIdleTimerDisabled = true

            // Show content after rotation completes - increased delay for smoother transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isOrientationReady = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if vm.connectionStatus != .Connected {
                    Announcer.shared.speak(text: "Timer is not connected")
                } else {
                    Announcer.shared.speak(text: "\(stage.name), \(division)")
                }
            }
        }
        .onDisappear() {
            // Cancel pending announcement
            autoAnnounceTask?.cancel()

            // End recording session
            recordingManager.endSession()

            // Reset orientation state
            isOrientationReady = false

            // Reset to allow all orientations
            AppDelegate.orientationLock = .all

            // Safely get active window scene
            if let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .allButUpsideDown))
            } else {
                print("⚠️ Could not get window scene for orientation unlock")
            }

            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    // MARK: - Column Views
    
    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("#\(vm.counter)")
                .font(.title.bold())

            let time = vm.adjustedTime(for: vm.stringRun)

            infoTitle(icon: .init(systemName: "stopwatch"),
                      label: "Current",
                      color: Color.blue)

            if vm.stringRun.stringShots.count >= 5 {
                percentClass(division: division, stageCode: stage.code, time: time)
            } else {
                Text("1").hidden().font(.system(.title2, weight: .bold))
            }

            Spacer().frame(height: 8)
            infoTitle(icon: .init(systemName: "stopwatch"),
                      label: stage.strings == 5 ? "Best 4 of 5" : "Best 3 of 4",
                      color: Color.blue)

            if stage.strings <= vm.allRuns.count && vm.stringRun.stringShots.count >= 5 {
                percentClass(division: division, stageCode: stage.code, times: vm.times())
            } else {
                Text("1").hidden().font(.system(.title2, weight: .bold))
            }

        }
        .frame(minWidth: 150, alignment: .leading)

    }
    
    @State private var pulseAnimation: Bool = false

    private var timerDisplay: some View {
        let performanceLevel = getPerformanceLevel()
        let adjustedTime = vm.adjustedTime(for: vm.stringRun)

        return Text(Format.formatTime(adjustedTime))
            .monospacedDigit()
            .font(.system(size: 120, weight: .bold))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .foregroundStyle(timerColor(for: performanceLevel))
            .shadow(color: shadowColor(for: performanceLevel), radius: performanceLevel == .trophy ? 20 : (performanceLevel == .good ? 10 : (performanceLevel == .penalty ? 20 : 0)))
            .scaleEffect((performanceLevel == .trophy || performanceLevel == .penalty) && pulseAnimation ? 1.05 : 1.0)
            .onChange(of: vm.stringRun.stringShots.count) { old, new in
                if new >= 5 {
                    if performanceLevel == .trophy {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulseAnimation = true
                        }
                        announcer.playTrophySound()
                    } else if performanceLevel == .penalty {
                        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                            pulseAnimation = true
                        }
                    }
                } else {
                    pulseAnimation = false
                }
            }
    }
    
    private var rightColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 12) {
                timerConnectionStatus()
            }
            
            if let bestTime = vm.bestTime() {
                infoTitle(icon: .init(systemName: "thermometer.high"), label: "Fastest", color: Color.green)
                Text("Time: \(Format.formatTime(bestTime))")
                    .font(.system(.body, weight: .bold))
                    .monospacedDigit()
            }
            if let bestFirstShot = vm.bestFirstShot() {
                Text("1st: \(Format.formatTime(bestFirstShot))")
                    .font(.system(.body, weight: .bold))
                    .monospacedDigit()
            }
            
            Spacer().frame(height: 15)

            if vm.counter > 1 {
                if let worstTime = vm.worstTime() {
                    infoTitle(icon: .init(systemName: "thermometer.low"), label: "Slowest", color: Color.red)
                    Text("Time: \(Format.formatTime(worstTime))")
                        .font(.system(.body, weight: .bold))
                        .monospacedDigit()
                }
                if let worstFirstShot = vm.worstFirstShot() {
                    Text("1st: \(Format.formatTime(worstFirstShot))")
                        .font(.system(.body, weight: .bold))
                        .monospacedDigit()
                }
            }
            
        }
        .frame(minWidth: 150, alignment: .trailing)


    }
    
    private var shotsAndSplits: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Target indicators
            targetIndicators

            // Shots / Splits
            infoTitle(icon: .init(systemName: "list.number"), label: "Shots / Splits", color: Color.blue)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(vm.stringRun.orderedStringShots) { shot in
                        VStack(alignment: .leading, spacing: 4) {
                            // Top: cumulative offset
                            Text("\(Format.formatTime(shot.now))")
                                .font(.title2.bold())
                                .monospacedDigit()

                            // Bottom: split
                            Text("\(Format.formatTime(shot.split))")
                                .font(.headline)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 4)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        // Top: cumulative offset
                        Text("1")
                            .hidden()
                            .font(.title2.bold())
                            .monospacedDigit()

                        // Bottom: split
                        Text("1")
                            .hidden()
                            .font(.headline)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 4)

                }
            }
        }
    }

    private var targetIndicators: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { target in
                targetButton(for: target)
            }
        }
    }

    private func targetButton(for target: Int) -> some View {
        let isMissed = vm.stringRun.missedTargets.contains(target)
        let isStopPlate = target == 5

        return Button {
            toggleTargetMiss(target)
        } label: {
            Image(systemName: isMissed ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: isStopPlate ? 36 : 28))
                .foregroundColor(isMissed ? .red : .green)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Views

    private enum PerformanceLevel {
        case trophy  // Above class level
        case good    // At class level
        case normal  // Below class level or incomplete
        case penalty // 30-second penalty (should flash red)
    }

    private func getPerformanceLevel() -> PerformanceLevel {
        guard vm.stringRun.stringShots.count >= 5 else {
            return .normal
        }

        // Check for penalty first
        if vm.shouldFlashRed(for: vm.stringRun) {
            return .penalty
        }

        guard let classification = shooter?.classification(for: division) else {
            return .normal
        }

        // Use adjusted time for performance calculation
        let time = vm.adjustedTime(for: vm.stringRun)
        let pct = PeakBenchmarks.percent(division: division, stageCode: stage.code, time: time)
        let threshold = classification.percentThreshold
        let nextClassThreshold = classification.nextClassThreshold

        if pct >= nextClassThreshold {
            return .trophy
        } else if pct >= threshold {
            return .good
        } else {
            return .normal
        }
    }

    private func timerColor(for level: PerformanceLevel) -> Color {
        switch level {
        case .trophy:
            return .yellow
        case .good:
            return .green
        case .normal:
            return .primary
        case .penalty:
            return .red
        }
    }

    private func shadowColor(for level: PerformanceLevel) -> Color {
        switch level {
        case .trophy:
            return .yellow.opacity(0.8)
        case .good:
            return .green.opacity(0.6)
        case .normal:
            return .clear
        case .penalty:
            return .red.opacity(0.8)
        }
    }

    @ViewBuilder
    private func infoTitle(icon: Image, label: String, color: Color) -> some View {
        HStack {
            icon
            Text(label)
        }
        .font(.system(.body, weight: .medium))
        .foregroundStyle(color)
    }
    
    @ViewBuilder
    private func percentClass(division: Division, stageCode: String, time: Decimal) -> some View {
        let pct = PeakBenchmarks.percent(division: division, stageCode: stageCode, time: time)
        let percentDouble = NSDecimalNumber(decimal: pct).doubleValue
        let shooterClass = ShooterClass.shooterClass(percentage: pct)
        
        HStack {
            Text(String(format: "%.0f%% (%@)", percentDouble, shooterClass.rawValue))
                .font(.system(.body, weight: .bold))
            if let classification = shooter?.classification(for: division) {
                stringReward(percent: pct, shooterClass: classification)
                    .imageScale(.small)
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
                .font(.system(.body, weight: .bold))
            if let classification = shooter?.classification(for: division) {
                stringReward(percent: pct, shooterClass: classification)
                    .imageScale(.small)
            }
        }
    }
    
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
    // MARK: - Target Hit/Miss Toggle

    private func toggleTargetMiss(_ target: Int) {
        // Delegate to RecordingManager for proper model mutation
        recordingManager.toggleTargetMiss(target)

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Cancel any current announcement and announce adjusted time with classification after 1 second
        Announcer.shared.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let adjustedTime = vm.adjustedTime(for: vm.stringRun)

            // Calculate classification for this time
            let pct = PeakBenchmarks.percent(division: division, stageCode: stage.code, time: adjustedTime)
            let shooterClass = ShooterClass.shooterClass(percentage: pct)

            Announcer.shared.speak(text: "\(Format.formatTime(adjustedTime)), \(shooterClass.rawValue)")
        }
    }

}


#if DEBUG
import SwiftUI
import SwiftData

// MARK: - Preview
@MainActor
struct RecordingView_Previews: PreviewProvider {
    
    
    static var previews: some View {

        let stage = AllStages[0]
        let division = Division.RFPO
        
        let container = try! ModelContainer(
            for: StringRun.self, StringShot.self, ShooterProfile.self, DivisionProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        
        let shooterProfile = ShooterProfile(uspsaNumber: "A12345")
        shooterProfile.setClassification(.M, for: division)
        container.mainContext.insert(shooterProfile)
                
        // Example run with a few shots
        let r1 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r1.time = 2.09
        r1.date = Date()
        
        let r2 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r2.time = 5.64
        r2.date = Date()+1
        
        let r3 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r3.time = 1.71
        r3.date = Date()+2
        
        let r4 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r4.time = 1.53
        r4.date = Date()+3
        
        let r5 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r5.time = 2.10
        r5.date = Date()+4
        r5.missedTargets = [3, 4]  // Missed targets 3 and 4

        r5.stringShots = [
            StringShot(now: 0.9, split: 0.9, first: 0.9),
            StringShot(now: 1.32, split: 0.57, first: 0.9),
            StringShot(now: 1.86, split: 0.54, first: 0.9),
            StringShot(now: 2.36, split: 0.50, first: 0.9),
            StringShot(now: 3.36, split: 1.00, first: 0.9),
        ]
                
        let vm = RecordingViewModel(stageId: stage.code, divisionId: division.rawValue)
        vm.allRuns = [r1, r2, r3, r4, r5]

        vm.stringRun = vm.allRuns.last!
        vm.counter = vm.allRuns.count

        
        // Mute the announcer in previews
        Announcer.shared.isEnabled = false

        return TabView {
            NavigationStack {
                RecordingView(stage: stage, division: division, vm: vm)
            }
            .tabItem {
                Label("Train", systemImage: "target")
            }
            
            Text("Log")
                .tabItem {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
            
            Text("Profile")
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
            
            Text("Settings")
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .modelContainer(container)
        .environment(DeviceOrientationManager())
    }
}
#endif
