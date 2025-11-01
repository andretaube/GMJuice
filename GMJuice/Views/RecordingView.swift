import SwiftUI
import Combine
import SwiftData
import UIKit

struct RecordingView<ViewModel: RecordingViewModelProtocol>: View {
    let stage: Stage
    let division: Division

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @ObservedObject private var announcer = Announcer.shared
    @ObservedObject private var recordingManager = RecordingManager.shared

    @ObservedObject var vm: ViewModel
    @State private var autoAnnounceTask: Task<Void, Never>?
    @State private var lastAnnouncedShotCount = 0
    @State private var previousConnectionStatus: BLEConnectionStatus = .Disconnected

    @Query private var shooterProfiles: [ShooterProfile]
    private var shooter: ShooterProfile? {
        shooterProfiles.first
    }

    @MainActor
    init(stage: Stage, division: Division, vm: ViewModel) {
        self.stage = stage
        self.division = division
        self.vm = vm
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
            // Lock to landscape orientation
            AppDelegate.orientationLock = .landscape

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
            // Restore all orientations
            AppDelegate.orientationLock = .all

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

// MARK: - Mock View Model for Previews

@MainActor
class MockRecordingViewModel: ObservableObject, RecordingViewModelProtocol {
    @Published var counter: Int
    @Published var stringRun: StringRun
    @Published var allRuns: [StringRun]
    @Published var connectionStatus: BLEConnectionStatus

    init(counter: Int, stringRun: StringRun, allRuns: [StringRun], connectionStatus: BLEConnectionStatus = .Connected) {
        self.counter = counter
        self.stringRun = stringRun
        self.allRuns = allRuns
        self.connectionStatus = connectionStatus
    }

    func adjustedTime(for stringRun: StringRun) -> Decimal {
        return stringRun.adjustedTime
    }

    func times() -> [Decimal] {
        return allRuns.sorted { $0.date < $1.date }.map(\.time).filter { $0 > 0 }
    }

    func bestTime() -> Decimal? {
        return allRuns.filter { $0.time > 0 }.map { $0.adjustedTime }.min()
    }

    func bestFirstShot() -> Decimal? {
        return allRuns.compactMap { $0.stringShots.first?.first }.filter { $0 > 0 }.min()
    }

    func worstTime() -> Decimal? {
        return allRuns.filter { $0.time > 0 }.map { $0.adjustedTime }.max()
    }

    func worstFirstShot() -> Decimal? {
        return allRuns.compactMap { $0.stringShots.first?.first }.filter { $0 > 0 }.max()
    }

    func shouldFlashRed(for run: StringRun) -> Bool {
        return run.shouldFlashRed
    }
}

// MARK: - Preview
@MainActor
struct RecordingView_Previews: PreviewProvider {


    static var previews: some View {

        let stage = AllStages[4]
        let division = Division.RFPO
        
        let container = try! ModelContainer(
            for: StringRun.self, StringShot.self, ShooterProfile.self, DivisionProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        
        let shooterProfile = ShooterProfile(uspsaNumber: "A12345")
        shooterProfile.setClassification(.M, for: division)
        container.mainContext.insert(shooterProfile)
                
        // Example runs with shots
        let r1 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r1.time = 2.09
        r1.date = Date()
        r1.stringShots = [
            StringShot(now: 0.55, split: 0.55, first: 0.55),
            StringShot(now: 0.95, split: 0.40, first: 0.55),
            StringShot(now: 1.35, split: 0.40, first: 0.55),
            StringShot(now: 1.69, split: 0.34, first: 0.55),
            StringShot(now: 2.09, split: 0.40, first: 0.55),
        ]

        let r2 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r2.time = 5.64
        r2.date = Date()+1
        r2.stringShots = [
            StringShot(now: 0.78, split: 0.78, first: 0.78),
            StringShot(now: 1.50, split: 0.72, first: 0.78),
            StringShot(now: 2.20, split: 0.70, first: 0.78),
            StringShot(now: 3.00, split: 0.80, first: 0.78),
            StringShot(now: 5.64, split: 2.64, first: 0.78),  // Slow last shot
        ]

        let r3 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r3.time = 1.71
        r3.date = Date()+2
        r3.stringShots = [
            StringShot(now: 0.45, split: 0.45, first: 0.45),
            StringShot(now: 0.78, split: 0.33, first: 0.45),
            StringShot(now: 1.10, split: 0.32, first: 0.45),
            StringShot(now: 1.40, split: 0.30, first: 0.45),
            StringShot(now: 1.71, split: 0.31, first: 0.45),
        ]

        let r4 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r4.time = 1.53
        r4.date = Date()+3
        r4.stringShots = [
            StringShot(now: 0.42, split: 0.42, first: 0.42),
            StringShot(now: 0.72, split: 0.30, first: 0.42),
            StringShot(now: 1.00, split: 0.28, first: 0.42),
            StringShot(now: 1.27, split: 0.27, first: 0.42),
            StringShot(now: 1.53, split: 0.26, first: 0.42),
        ]

        let r5 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r5.time = 2.15
        r5.date = Date()+4
//        r5.missedTargets = [3, 4]  // Missed targets 3 and 4
        r5.stringShots = [
            StringShot(now: 0.9, split: 0.9, first: 0.9),
            StringShot(now: 1.32, split: 0.42, first: 0.9),
            StringShot(now: 1.86, split: 0.54, first: 0.9),
            StringShot(now: 2.01, split: 0.50, first: 0.9),
            StringShot(now: 2.15, split: 1.00, first: 0.9),
        ]

        let allRuns = [r1, r2, r3, r4, r5]

        // Use mock view model for preview
        let vm = MockRecordingViewModel(
            counter: allRuns.count,
            stringRun: r5,
            allRuns: allRuns,
            connectionStatus: .Connected
        )

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
