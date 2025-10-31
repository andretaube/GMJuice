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
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                RecordingLeftColumn(stage: stage, division: division, vm: vm, style: .default, shooter: shooter)
                VStack(spacing: 8) {
                    RecordingTimerDisplay(fontSize: 240, vm: vm, division: division, stage: stage, shooter: shooter, style: .default, announcer: announcer)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    // Hit/miss indicators right after time
                    RecordingTargetIndicators(stage: stage, missedTargets: vm.stringRun.missedTargets, onToggleMiss: toggleTargetMiss, style: .default)
                }
                .frame(maxWidth: .infinity)
                RecordingRightColumn(vm: vm, style: .default)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer(minLength: 8)

            RecordingShotsAndSplits(vm: vm, style: .default)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: [])
        .navigationTitle("\(stage.name) – \(stage.code) - \(division)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
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

            UIApplication.shared.isIdleTimerDisabled = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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

            UIApplication.shared.isIdleTimerDisabled = false
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

        let stage = AllStages[7]
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
    }
}
#endif
