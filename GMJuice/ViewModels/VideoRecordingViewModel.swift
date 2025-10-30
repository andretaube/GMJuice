//
//  VideoRecordingViewModel.swift
//  GMJuice
//
//  View model for video recording mode that extends RecordingViewModel
//  with AVFoundation camera capture and video recording capabilities.
//

import Foundation
import Combine
import SwiftData
import SwiftUI
@preconcurrency import AVFoundation
import Photos

@MainActor
public class VideoRecordingViewModel: ObservableObject {
    private let stageId: String
    private let divisionId: String

    // Observe manager state (same as RecordingViewModel)
    @Published var stringRun: StringRun
    @Published var counter: Int = 0
    @Published var allRuns: [StringRun] = []
    @Published var connectionStatus: BLEConnectionStatus = .Disconnected

    // Video recording state
    @Published var isRecording: Bool = false
    @Published var recordingStartTime: Date?
    @Published var beepTimes: [Date] = []  // Track all beep times for accurate video overlay
    @Published var lastShotTime: Date?

    // AVFoundation
    nonisolated(unsafe) let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentVideoURL: URL?
    private var recordingDelegate: VideoRecordingDelegate?

    private let manager = RecordingManager.shared
    private let ble = BLEManager.shared
    private var cancellables = Set<AnyCancellable>()

    init(stageId: String, divisionId: String) {
        self.stageId = stageId
        self.divisionId = divisionId

        // Initialize with empty string
        self.stringRun = StringRun(stageId: stageId, divisionId: divisionId)

        // Subscribe to BLE connection status
        ble.$connectionStatus
            .receive(on: RunLoop.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)

        // Subscribe to RecordingManager state
        manager.$currentString
            .receive(on: RunLoop.main)
            .sink { [weak self] currentString in
                guard let self = self else { return }
                self.stringRun = currentString ?? StringRun(stageId: stageId, divisionId: divisionId)
            }
            .store(in: &cancellables)

        manager.$stringCounter
            .receive(on: RunLoop.main)
            .assign(to: \.counter, on: self)
            .store(in: &cancellables)

        manager.$allStrings
            .receive(on: RunLoop.main)
            .assign(to: \.allRuns, on: self)
            .store(in: &cancellables)

        // Track all beep times for accurate video overlay timing
        manager.$stringCounter
            .receive(on: RunLoop.main)
            .sink { [weak self] counter in
                guard let self = self else { return }
                // Each time counter increments, a new beep happened
                if counter > self.beepTimes.count {
                    let beepTime = Date()
                    self.beepTimes.append(beepTime)
                    print("🔔 Beep #\(counter) detected at \(beepTime)")
                }
            }
            .store(in: &cancellables)

        // Track last shot time when shots are recorded
        manager.$shotCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                guard let self = self else { return }
                if count > 0 {
                    self.lastShotTime = Date()
                    print("🎯 Shot detected (count = \(count))")
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Camera Setup

    func startCamera() async {
        print("📹 startCamera() called")
        await setupCaptureSession()
        await startRecording()
        print("📹 startCamera() completed")
    }

    func stopCamera() {
        print("📹 stopCamera() called")
        Task {
            await stopRecording()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.stopRunning()
                print("📹 Capture session stopped")
            }
        }
    }

    private func setupCaptureSession() async {
        guard await checkCameraPermission() else {
            print("⚠️ Camera permission denied")
            return
        }

        print("📹 Setting up capture session on background thread")

        // Configure audio session BEFORE starting capture session
        // This prevents conflicts with the capture session's own audio setup
        do {
            let audioSession = AVAudioSession.sharedInstance()
            print("📹 Configuring audio session before capture session setup")
            print("📹 Current audio session: category=\(audioSession.category.rawValue), active=\(audioSession.isOtherAudioPlaying)")

            // First deactivate any existing audio session to ensure clean slate
            if audioSession.category != .playAndRecord {
                try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                print("📹 Deactivated previous audio session")
                // Brief pause to let deactivation complete
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }

            // Use playAndRecord category which is compatible with both video recording and potential playback
            // Use videoRecording mode which is optimized for video capture
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: [])

            print("📹 Audio session configured: category=\(audioSession.category.rawValue), mode=\(audioSession.mode.rawValue)")
        } catch {
            print("⚠️ Failed to configure audio session: \(error)")
        }

        // Run all capture session configuration on background thread
        await Task.detached { [weak self] in
            guard let self = self else { return }

            self.captureSession.sessionPreset = .high

            // Setup video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.captureSession.canAddInput(videoInput) else {
                print("⚠️ Failed to setup video input")
                return
            }

            self.captureSession.addInput(videoInput)

            // Setup audio input - required for stable movie file recording
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               self.captureSession.canAddInput(audioInput) {
                self.captureSession.addInput(audioInput)
                print("📹 Audio input added")
            } else {
                print("⚠️ Failed to add audio input")
            }

            // Setup movie file output
            let movieOutput = AVCaptureMovieFileOutput()

            // Configure the movie output
            movieOutput.maxRecordedDuration = CMTime(seconds: 600, preferredTimescale: 1) // 10 minutes max
            movieOutput.minFreeDiskSpaceLimit = 1024 * 1024 * 50 // 50 MB minimum free space

            if self.captureSession.canAddOutput(movieOutput) {
                self.captureSession.addOutput(movieOutput)

                // Set video orientation to landscape right
                if let connection = movieOutput.connection(with: .video) {
                    if #available(iOS 17.0, *) {
                        // iOS 17+: Use videoRotationAngle (0° = landscape right)
                        connection.videoRotationAngle = 0
                        print("📹 Video rotation angle set to 0° (landscape right)")
                    } else {
                        // iOS 16 and earlier
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .landscapeRight
                            print("📹 Video orientation set to landscape right")
                        }
                    }
                }

                // Update videoOutput on main actor
                Task { @MainActor in
                    self.videoOutput = movieOutput
                    print("📹 VideoOutput configured and assigned")
                }
            } else {
                print("⚠️ Cannot add movie output to session")
            }

            // Start the session
            print("📹 Starting capture session")
            self.captureSession.startRunning()
            print("📹 Capture session started successfully")
        }.value
    }

    private func checkCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Video Recording

    private func startRecording() async {
        // Wait longer for the capture session to fully stabilize
        // This is critical - session needs time to fully initialize audio/video pipeline
        print("📹 Waiting for capture session to stabilize...")
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        print("📹 Capture session running: \(captureSession.isRunning)")

        guard let videoOutput = videoOutput else {
            print("⚠️ Video output not available")
            return
        }

        guard captureSession.isRunning else {
            print("⚠️ Capture session not running - cannot start recording")
            return
        }

        // Generate unique filename
        let fileName = "gmjuice_\(UUID().uuidString).mov"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        currentVideoURL = tempURL

        print("📹 Starting video recording to: \(tempURL.path)")
        print("📹 VideoOutput.isRecording before start: \(videoOutput.isRecording)")
        print("📹 VideoOutput connections: \(videoOutput.connections.count)")

        // Log connection details
        for (index, connection) in videoOutput.connections.enumerated() {
            print("📹   Connection \(index): active=\(connection.isActive), enabled=\(connection.isEnabled)")
            for port in connection.inputPorts {
                print("📹     Input port: \(port.mediaType)")
            }
        }

        print("📹 VideoOutput maxRecordedDuration: \(videoOutput.maxRecordedDuration.seconds)")
        print("📹 CaptureSession.isRunning: \(captureSession.isRunning)")
        print("📹 CaptureSession.isInterrupted: \(captureSession.isInterrupted)")

        // Check disk space
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSTemporaryDirectory()),
           let freeSize = attrs[.systemFreeSize] as? NSNumber {
            let freeMB = freeSize.int64Value / (1024 * 1024)
            print("📹 Free disk space: \(freeMB) MB")
        }

        // Audio session already configured in setupCaptureSession()
        // No need to reconfigure here

        // Create and retain the delegate
        let delegate = VideoRecordingDelegate(viewModel: self)
        self.recordingDelegate = delegate

        // CRITICAL: Start recording on a background queue with .userInitiated QoS
        // AVCaptureMovieFileOutput requires this for proper operation
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard self != nil else {
                    continuation.resume()
                    return
                }

                print("📹 Calling startRecording on .userInitiated queue")
                videoOutput.startRecording(to: tempURL, recordingDelegate: delegate)
                print("📹 startRecording() call completed")

                // Resume immediately - don't block this queue!
                // AVFoundation needs this queue to complete recording setup
                continuation.resume()
            }
        }

        // Wait a bit for recording to fully initialize
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        print("📹 VideoOutput.isRecording after check: \(videoOutput.isRecording)")

        await MainActor.run {
            self.isRecording = videoOutput.isRecording
            if videoOutput.isRecording {
                self.recordingStartTime = Date()
                print("📹 Video recording started successfully")
            } else {
                print("⚠️ Video recording failed to start!")
            }
        }
    }

    private func stopRecording() async {
        print("📹 stopRecording() - videoOutput: \(videoOutput != nil), isRecording: \(videoOutput?.isRecording ?? false)")

        guard let videoOutput = videoOutput else {
            print("⚠️ stopRecording() - no videoOutput")
            return
        }

        guard videoOutput.isRecording else {
            print("⚠️ stopRecording() - videoOutput not recording")
            return
        }

        print("📹 Calling videoOutput.stopRecording()")
        videoOutput.stopRecording()

        await MainActor.run {
            self.isRecording = false
        }

        print("📹 Stopped video recording - waiting for delegate callback")
    }

    func finishRecording(outputURL: URL) {
        Task { @MainActor in
            print("📹 finishRecording called with URL: \(outputURL.path)")
            print("📹 File exists: \(FileManager.default.fileExists(atPath: outputURL.path))")

            // Brief delay to let Combine subscriptions deliver allStrings update
            // The RecordingManager publishes allStrings, but the update might not have
            // reached us yet via the Combine pipeline
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            print("📹 Strings recorded: \(allRuns.count)")

            // Only save video if at least 1 string was recorded
            guard allRuns.count > 0 else {
                print("⚠️ No strings recorded - discarding video")
                try? FileManager.default.removeItem(at: outputURL)

                // End recording session now that video processing is done
                manager.endSession()
                print("🏁 Recording session ended after video discard")
                return
            }

            print("📹 Processing video with \(allRuns.count) string(s)")

            // Process the video (trim and add overlay)
            await processVideo(sourceURL: outputURL)

            print("✅ Video processing completed")

            // End recording session now that video processing is done
            manager.endSession()
            print("🏁 Recording session ended after video processing")
        }
    }

    // MARK: - Video Processing

    private func processVideo(sourceURL: URL) async {
        // Notify that processing has started
        VideoProcessingManager.shared.startProcessing()

        guard let recordingStart = recordingStartTime else {
            print("⚠️ Missing recording start time")
            VideoProcessingManager.shared.finishProcessing()
            return
        }

        guard let lastShot = lastShotTime, !beepTimes.isEmpty else {
            print("⚠️ No beep/shot timing data - cannot trim video")
            VideoProcessingManager.shared.finishProcessing()
            return
        }

        let firstBeep = beepTimes[0]

        // Calculate trim times - 2 seconds before first beep and 2 seconds after last shot
        let startOffset = firstBeep.timeIntervalSince(recordingStart) - 2.0
        let endOffset = lastShot.timeIntervalSince(recordingStart) + 2.0
        let startTime = max(0, startOffset)
        let endTime = endOffset

        print("📹 Trimming video from \(startTime)s to \(endTime)s")

        // Calculate all beep times relative to recording start
        let beepOffsets = beepTimes.map { $0.timeIntervalSince(recordingStart) }
        print("📹 Beep offsets from recording start: \(beepOffsets)")

        VideoProcessingManager.shared.updateStatus("Trimming and adding overlay...")

        // Create video processor and process
        let processor = VideoProcessor()
        do {
            let processedURL = try await processor.trimAndOverlay(
                sourceURL: sourceURL,
                startTime: startTime,
                endTime: endTime,
                stringRuns: allRuns,
                stage: AllStages.first(where: { $0.code == stageId })!,
                division: Division(rawValue: divisionId) ?? .RFPO,
                beepOffsets: beepOffsets
            )

            VideoProcessingManager.shared.updateStatus("Saving video...")

            // Save to app's Documents directory
            let savedURL = try await saveToDocuments(url: processedURL)
            print("✅ Video saved to: \(savedURL.path)")

            // Also save to photo library
            await saveToPhotoLibrary(url: savedURL)

            // Cleanup temporary files
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: processedURL)

            // Processing complete
            VideoProcessingManager.shared.finishProcessing()

        } catch {
            print("⚠️ Video processing error: \(error)")
            VideoProcessingManager.shared.finishProcessing()
        }
    }

    private func saveToDocuments(url: URL) async throws -> URL {
        // Get Documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw VideoSaveError.documentsDirectoryNotFound
        }

        // Create Videos subdirectory if needed
        let videosDirectory = documentsPath.appendingPathComponent("Videos")
        try? FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)

        // Create filename with timestamp, stage, and division
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let stage = AllStages.first(where: { $0.code == stageId })
        let fileName = "\(timestamp)_\(stage?.code ?? "unknown")_\(divisionId).mov"

        let destinationURL = videosDirectory.appendingPathComponent(fileName)

        // Copy file to Documents
        try FileManager.default.copyItem(at: url, to: destinationURL)

        return destinationURL
    }

    private func saveToPhotoLibrary(url: URL) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized else {
            print("⚠️ Photo library permission denied")
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            print("✅ Video saved to photo library")
        } catch {
            print("⚠️ Failed to save video: \(error)")
        }
    }

    // MARK: - Helper Methods (same as RecordingViewModel)

    func bestTime() -> Decimal? {
        allRuns
            .filter { $0.time > 0 }
            .map { $0.adjustedTime }
            .min()
    }

    func bestFirstShot() -> Decimal? {
        allRuns
            .compactMap { run in
                run.stringShots.first?.first
            }
            .filter { $0 > 0 }
            .min()
    }

    func worstTime() -> Decimal? {
        allRuns
            .filter { $0.time > 0 }
            .map { $0.adjustedTime }
            .max()
    }

    func worstFirstShot() -> Decimal? {
        allRuns
            .compactMap { run in
                run.stringShots.first?.first
            }
            .filter { $0 > 0 }
            .max()
    }

    func times() -> [Decimal] {
        allRuns
            .sorted { $0.date < $1.date }
            .map(\.time)
            .filter { $0 > 0 }
    }

    func adjustedTime(for run: StringRun) -> Decimal {
        return run.adjustedTime
    }

    func shouldFlashRed(for run: StringRun) -> Bool {
        return run.shouldFlashRed
    }
}

// MARK: - Video Recording Delegate

private class VideoRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    weak var viewModel: VideoRecordingViewModel?

    init(viewModel: VideoRecordingViewModel) {
        self.viewModel = viewModel
        super.init()
        print("📹 VideoRecordingDelegate created")
    }

    deinit {
        print("📹 VideoRecordingDelegate deallocated")
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("📹 VideoRecordingDelegate.fileOutput called!")
        print("📹 Output URL: \(outputFileURL.path)")
        print("📹 File exists: \(FileManager.default.fileExists(atPath: outputFileURL.path))")
        print("📹 Error: \(error?.localizedDescription ?? "none")")
        print("📹 Error code: \((error as NSError?)?.code ?? 0)")
        print("📹 Error domain: \((error as NSError?)?.domain ?? "none")")
        print("📹 ViewModel exists: \(viewModel != nil)")

        if let error = error {
            let nsError = error as NSError
            // AVError code -11819 is "Recording Stopped" which can happen if stopped too early
            // But we still want to process the video if the file exists
            print("⚠️ Recording error: \(error.localizedDescription) (code: \(nsError.code))")

            // Check if file exists anyway
            if FileManager.default.fileExists(atPath: outputFileURL.path) {
                print("📹 File exists despite error - attempting to process anyway")
            } else {
                print("⚠️ File doesn't exist - cannot process video")
                return
            }
        }

        Task { @MainActor in
            print("📹 Calling viewModel.finishRecording")
            viewModel?.finishRecording(outputURL: outputFileURL)
        }
    }
}

// MARK: - Errors

enum VideoSaveError: Error {
    case documentsDirectoryNotFound
}
