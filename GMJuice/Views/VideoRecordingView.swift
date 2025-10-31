//
//  VideoRecordingView.swift
//  GMJuice
//
//  Created by Andre Taube on 10/30/25.
//

import SwiftUI
import Photos
import SwiftData
import AVFoundation

struct VideoRecordingView: View {

    let stage: Stage
    let division: Division

    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm: VideoRecordingViewModel
    @ObservedObject private var recordingManager = RecordingManager.shared

    @State private var cameraViewController: CameraViewController?

    @Query private var shooterProfiles: [ShooterProfile]
    private var shooter: ShooterProfile? {
        shooterProfiles.first
    }

    @MainActor
    init(stage: Stage, division: Division) {
        self.stage = stage
        self.division = division
        _vm = StateObject(wrappedValue: VideoRecordingViewModel(stageId: stage.code, divisionId: division.id))
    }

    var body: some View {
        ZStack {
            // Camera preview
            CameraView(
                isRecording: .constant(vm.isRecording),
                onVideoRecorded: { videoURL in
                    vm.finishRecording(outputURL: videoURL)
                },
                onViewControllerCreated: { viewController in
                    cameraViewController = viewController
                    vm.setCameraViewController(viewController)

                    // Hook up recording started callback
                    viewController.onRecordingStarted = {
                        Task { @MainActor in
                            vm.startedRecording()
                        }
                    }
                }
            )
            .ignoresSafeArea()

            // UI overlay with recording components
            RecordingOverlay(
                stage: stage,
                division: division,
                vm: vm,
                shooter: shooter,
                onToggleMiss: toggleTargetMiss
            )
        }
        .navigationTitle("\(stage.code) – \(stage.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            requestCameraPermission()

            // Start recording session
            recordingManager.startSession(stageId: stage.code, divisionId: division.id, modelContext: modelContext)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            print("📹 VideoRecordingView onDisappear called")
            print("📹 cameraViewController is nil: \(cameraViewController == nil)")
            print("📹 vm.isRecording: \(vm.isRecording)")

            // Stop recording if still recording
            cameraViewController?.stopRecording()

            // Note: recordingManager.endSession() is called by VideoRecordingViewModel.finishRecording()
            UIApplication.shared.isIdleTimerDisabled = false
            print("📹 onDisappear completed")
        }
    }

    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    private func toggleTargetMiss(_ target: Int) {
        RecordingManager.shared.toggleTargetMiss(target)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Recording Overlay

struct RecordingOverlay: View {
    let stage: Stage
    let division: Division
    @ObservedObject var vm: VideoRecordingViewModel
    let shooter: ShooterProfile?
    let onToggleMiss: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top row: left and right columns
            HStack(alignment: .top, spacing: 16) {
                RecordingLeftColumn(stage: stage, division: division, vm: vm, style: .video, shooter: shooter)
                
                // Center: Timer and target indicators
                VStack(spacing: 8) {
                    RecordingTimerDisplay(fontSize: 240, vm: vm, division: division, stage: stage, shooter: shooter, style: .video)
                        .frame(maxWidth: .infinity)

                    RecordingTargetIndicators(stage: stage, missedTargets: vm.stringRun.missedTargets, onToggleMiss: onToggleMiss, style: .video)
                }
                .padding(.horizontal)

                
                
                RecordingRightColumn(vm: vm, style: .video) {
                    // Recording indicator
                    if vm.isRecording {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                            Text("REC")
                                .font(.system(.body, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: .black, radius: 2)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()


            // Bottom: Shots and splits
            RecordingShotsAndSplits(vm: vm, style: .video)
                .padding(.horizontal)
                .padding(.bottom)
        }
    }
}


class CameraViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    var captureSession: AVCaptureSession!
    var movieOutput: AVCaptureMovieFileOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!

    var onVideoRecorded: ((URL) -> Void)?
    var onRecordingStarted: (() -> Void)?

    // Keep a strong reference to self during recording to prevent premature deallocation
    private var strongSelf: CameraViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateOrientation()
    }

    func updateOrientation() {
        guard let windowScene = view.window?.windowScene else { return }

        // Get the device's current orientation
        let orientation = windowScene.interfaceOrientation

        // Map interface orientation to video rotation angle
        let rotationAngle: CGFloat
        switch orientation {
        case .landscapeLeft:
            rotationAngle = 180
        case .landscapeRight:
            rotationAngle = 0
        case .portrait:
            rotationAngle = 90
        case .portraitUpsideDown:
            rotationAngle = 270
        default:
            rotationAngle = 90
        }

        // Update preview layer orientation
        if let connection = previewLayer?.connection, connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
    }

    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        // Add audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return }
        guard let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else { return }
        if captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }

        // Add movie file output
        movieOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }

        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds

        view.layer.addSublayer(previewLayer)

        // Start the session
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }

        // Set initial orientation
        updateOrientation()
    }

    func startRecording() {
        guard !movieOutput.isRecording else { return }

        // Keep a strong reference to prevent deallocation during recording
        strongSelf = self

        let outputFileName = UUID().uuidString
        let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
        let outputURL = URL(fileURLWithPath: outputFilePath)

        // Set video recording orientation to match preview
        if let connection = movieOutput.connection(with: .video),
           let previewConnection = previewLayer.connection,
           connection.isVideoRotationAngleSupported(previewConnection.videoRotationAngle) {
            connection.videoRotationAngle = previewConnection.videoRotationAngle
        }

        print("📹 Starting recording to: \(outputURL.path)")
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)

        // Notify that recording started
        onRecordingStarted?()
    }

    func stopRecording() {
        print("🛑 stopRecording called")
        print("🛑 movieOutput: \(movieOutput != nil ? "exists" : "nil")")
        print("🛑 movieOutput.isRecording: \(movieOutput?.isRecording ?? false)")

        guard movieOutput.isRecording else {
            print("⚠️ stopRecording called but not recording")
            return
        }
        print("🛑 Calling movieOutput.stopRecording()...")
        movieOutput.stopRecording()
        print("🛑 movieOutput.stopRecording() called")
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Release the strong reference now that recording is complete
        defer { strongSelf = nil }

        print("📹 fileOutput delegate called")
        print("📹 Output URL: \(outputFileURL.path)")
        print("📹 File exists: \(FileManager.default.fileExists(atPath: outputFileURL.path))")

        if let error = error {
            print("⚠️ Recording error: \(error.localizedDescription)")
            print("⚠️ Error code: \((error as NSError).code)")
            print("⚠️ Error domain: \((error as NSError).domain)")
            // Still process if file exists
            guard FileManager.default.fileExists(atPath: outputFileURL.path) else {
                print("⚠️ File doesn't exist, not processing")
                return
            }
        }

        print("✅ Calling onVideoRecorded callback")
        onVideoRecorded?(outputFileURL)
    }
}

import SwiftUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    @Binding var isRecording: Bool
    var onVideoRecorded: ((URL) -> Void)?
    var onViewControllerCreated: ((CameraViewController) -> Void)?

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onVideoRecorded = onVideoRecorded
        onViewControllerCreated?(controller)

        // Start recording automatically after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            controller.startRecording()
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // Recording is managed automatically - starts on appear, stops on disappear
    }

    static func dismantleUIViewController(_ uiViewController: CameraViewController, coordinator: ()) {
        print("📹 CameraView being dismantled")
        // Stop recording when the view is being torn down
        uiViewController.stopRecording()
    }
}

#if DEBUG
import SwiftUI
import SwiftData

// MARK: - Preview

@MainActor
struct VideoRecordingView_Previews: PreviewProvider {

    static var previews: some View {
        let stage = AllStages[0]  // SC-108
        let division = Division.RFPO

        let container = try! ModelContainer(
            for: StringRun.self, StringShot.self, ShooterProfile.self, DivisionProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let shooterProfile = ShooterProfile(uspsaNumber: "A12345")
        shooterProfile.setClassification(.M, for: division)
        container.mainContext.insert(shooterProfile)

        // Create some sample runs
        let r1 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r1.time = 2.09
        r1.date = Date()
        r1.stringShots = [
            StringShot(now: 0.82, split: 0.82, first: 0.82),
            StringShot(now: 1.25, split: 0.43, first: 0.82),
            StringShot(now: 1.58, split: 0.33, first: 0.82),
            StringShot(now: 1.87, split: 0.29, first: 0.82),
            StringShot(now: 2.09, split: 0.22, first: 0.82),
        ]

        let r2 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r2.time = 1.87
        r2.date = Date() + 1
        r2.stringShots = [
            StringShot(now: 0.78, split: 0.78, first: 0.78),
            StringShot(now: 1.01, split: 0.23, first: 0.78),
            StringShot(now: 1.27, split: 0.26, first: 0.78),
            StringShot(now: 1.56, split: 0.29, first: 0.78),
            StringShot(now: 1.87, split: 0.31, first: 0.78),
        ]

        let r3 = StringRun(stageId: stage.code, divisionId: division.rawValue)
        r3.time = 1.74
        r3.date = Date() + 2
        r3.stringShots = [
            StringShot(now: 0.78, split: 0.78, first: 0.78),
            StringShot(now: 1.01, split: 0.23, first: 0.78),
            StringShot(now: 1.27, split: 0.26, first: 0.78),
            StringShot(now: 1.56, split: 0.29, first: 0.78),
            StringShot(now: 1.74, split: 0.18, first: 0.78),
        ]

        let vm = VideoRecordingViewModel(stageId: stage.code, divisionId: division.rawValue)
        vm.allRuns = [r1, r2, r3]
        vm.stringRun = r3
        vm.counter = 3
        vm.isRecording = true

        // Preview just the overlay without the camera
        return ZStack {
            Color.black
                .ignoresSafeArea()

            RecordingOverlay(
                stage: stage,
                division: division,
                vm: vm,
                shooter: shooterProfile,
                onToggleMiss: { _ in }
            )
        }
        .modelContainer(container)
    }
}
#endif
