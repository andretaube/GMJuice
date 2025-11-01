//
//  VideoRecordingViewModel.swift
//  GMJuice
//
//  View model for video recording mode
//

import Foundation
import Combine
import SwiftData
import SwiftUI
import UIKit
@preconcurrency import AVFoundation
import Photos

@MainActor
public class VideoRecordingViewModel: ObservableObject, RecordingViewModelProtocol {
    private let stageId: String
    private let divisionId: String

    // RecordingViewModelProtocol conformance
    @Published var stringRun: StringRun
    @Published var counter: Int = 0
    @Published var allRuns: [StringRun] = []
    @Published var connectionStatus: BLEConnectionStatus = .Disconnected

    // Video-specific state
    @Published var isRecording: Bool = false

    // Camera view controller (provided by view)
    private weak var cameraViewController: CameraViewController?

    // Recording timing
    private var recordingStartTime: Date?
    private var beepTimes: [Date] = []
    private var lastShotTime: Date?

    // Managers
    private let manager = RecordingManager.shared
    private let ble = BLEManager.shared
    private var cancellables = Set<AnyCancellable>()

    init(stageId: String, divisionId: String) {
        self.stageId = stageId
        self.divisionId = divisionId

        // Initialize with empty string
        self.stringRun = StringRun(stageId: stageId, divisionId: divisionId)

        // Subscribe to BLE
        ble.$connectionStatus
            .receive(on: RunLoop.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)

        // Subscribe to RecordingManager
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

        // Track beep times
        manager.$stringCounter
            .receive(on: RunLoop.main)
            .sink { [weak self] counter in
                guard let self = self else { return }
                if counter > self.beepTimes.count {
                    let beepTime = Date()
                    self.beepTimes.append(beepTime)
                    print("🔔 Beep #\(counter) at \(beepTime)")
                }
            }
            .store(in: &cancellables)

        // Track shot times
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

    func setCameraViewController(_ viewController: CameraViewController) {
        self.cameraViewController = viewController
        print("📹 Camera view controller set")
    }

    // MARK: - Recording State

    func startedRecording() {
        self.isRecording = true
        self.recordingStartTime = Date()
        print("✅ Recording started")
    }

    func finishRecording(outputURL: URL) {
        Task { @MainActor in
            print("📹 finishRecording called")
            print("📹 Output URL: \(outputURL.path)")
            print("📹 File size: \((try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size]) ?? "unknown")")

            // Brief delay for allStrings to update
            try? await Task.sleep(nanoseconds: 100_000_000)

            print("📹 All runs count: \(allRuns.count)")
            print("📹 Recording start time: \(recordingStartTime?.description ?? "nil")")
            print("📹 Last shot time: \(lastShotTime?.description ?? "nil")")
            print("📹 Beep times count: \(beepTimes.count)")

            // Only process if we have strings recorded
            guard allRuns.count > 0 else {
                print("⚠️ No strings recorded - discarding video")
                try? FileManager.default.removeItem(at: outputURL)
                manager.endSession()
                return
            }

            // Process the video
            await processVideo(sourceURL: outputURL)

            // End session after processing
            manager.endSession()
            print("🏁 Recording session ended")
        }
    }

    // MARK: - Video Processing

    private func processVideo(sourceURL: URL) async {
        print("🎬 Starting video processing")
        VideoProcessingManager.shared.startProcessing()

        // Request background task to prevent suspension when screen locks
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "VideoProcessing") {
            // Expiration handler - called if background time runs out
            print("⚠️ Background task expiring - video processing may be interrupted")
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
        print("🔒 Background task started: \(backgroundTaskID.rawValue)")

        defer {
            // Ensure background task is always ended
            if backgroundTaskID != .invalid {
                print("🔓 Ending background task: \(backgroundTaskID.rawValue)")
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
        }

        guard let recordingStart = recordingStartTime,
              let lastShot = lastShotTime,
              !beepTimes.isEmpty else {
            print("⚠️ Missing timing data:")
            print("   - recordingStart: \(recordingStartTime?.description ?? "nil")")
            print("   - lastShot: \(lastShotTime?.description ?? "nil")")
            print("   - beepTimes count: \(beepTimes.count)")
            VideoProcessingManager.shared.finishProcessing()
            return
        }

        let firstBeep = beepTimes[0]
        let startTime = max(0, firstBeep.timeIntervalSince(recordingStart) - 2.0)
        let endTime = lastShot.timeIntervalSince(recordingStart) + 2.0
        let beepOffsets = beepTimes.map { $0.timeIntervalSince(recordingStart) }

        print("📹 Processing video: \(startTime)s to \(endTime)s")
        print("📹 Beep offsets: \(beepOffsets)")

        VideoProcessingManager.shared.updateStatus("Trimming and adding overlay...")

        let processor = VideoProcessor()
        do {
            guard let stage = AllStages.first(where: { $0.code == stageId }),
                  let division = Division(rawValue: divisionId) else {
                print("⚠️ Invalid stage or division")
                VideoProcessingManager.shared.finishProcessing()
                return
            }

            print("🎬 Calling trimAndOverlay...")
            let processedURL = try await processor.trimAndOverlay(
                sourceURL: sourceURL,
                startTime: startTime,
                endTime: endTime,
                stringRuns: allRuns,
                stage: stage,
                division: division,
                beepOffsets: beepOffsets,
                cameraPosition: .back
            )

            print("✅ Video trimmed and overlayed: \(processedURL.path)")
            VideoProcessingManager.shared.updateStatus("Saving video...")

            print("💾 Saving to documents...")
            let savedURL = try await saveToDocuments(url: processedURL)
            print("✅ Saved to documents: \(savedURL.path)")

            print("📸 Saving to photo library...")
            await saveToPhotoLibrary(url: savedURL)

            // Cleanup
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: processedURL)

            VideoProcessingManager.shared.finishProcessing()
            print("✅ Video saved: \(savedURL.path)")

        } catch {
            print("⚠️ Video processing error: \(error)")
            VideoProcessingManager.shared.finishProcessing()
        }
    }

    private func saveToDocuments(url: URL) async throws -> URL {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw VideoSaveError.documentsDirectoryNotFound
        }

        let videosDirectory = documentsPath.appendingPathComponent("Videos")
        try? FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let stage = AllStages.first(where: { $0.code == stageId })
        let fileName = "\(timestamp)_\(stage?.code ?? "unknown")_\(divisionId).mov"

        let destinationURL = videosDirectory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: url, to: destinationURL)

        return destinationURL
    }

    private func saveToPhotoLibrary(url: URL) async {
        print("📸 Requesting photo library authorization...")
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        print("📸 Authorization status: \(status.rawValue)")

        guard status == .authorized else {
            print("⚠️ Photo library permission denied (status: \(status.rawValue))")
            return
        }

        do {
            print("📸 Performing changes to photo library...")
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            print("✅ Video saved to photo library")
        } catch {
            print("⚠️ Failed to save video to photo library: \(error)")
            print("⚠️ Error details: \(error.localizedDescription)")
        }
    }

    // MARK: - Permissions

    private func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    // MARK: - RecordingViewModelProtocol

    func bestTime() -> Decimal? {
        allRuns.filter { $0.time > 0 }.map { $0.adjustedTime }.min()
    }

    func bestFirstShot() -> Decimal? {
        allRuns.compactMap { $0.stringShots.first?.first }.filter { $0 > 0 }.min()
    }

    func worstTime() -> Decimal? {
        allRuns.filter { $0.time > 0 }.map { $0.adjustedTime }.max()
    }

    func worstFirstShot() -> Decimal? {
        allRuns.compactMap { $0.stringShots.first?.first }.filter { $0 > 0 }.max()
    }

    func times() -> [Decimal] {
        allRuns.sorted { $0.date < $1.date }.map(\.time).filter { $0 > 0 }
    }

    func adjustedTime(for run: StringRun) -> Decimal {
        return run.adjustedTime
    }

    func shouldFlashRed(for run: StringRun) -> Bool {
        return run.shouldFlashRed
    }
}

// MARK: - Errors

enum VideoSaveError: Error {
    case documentsDirectoryNotFound
}
