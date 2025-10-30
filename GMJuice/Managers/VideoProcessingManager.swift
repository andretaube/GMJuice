//
//  VideoProcessingManager.swift
//  GMJuice
//
//  Singleton to track video processing state across the app
//

import Foundation

@MainActor
final class VideoProcessingManager: ObservableObject {
    static let shared = VideoProcessingManager()

    @Published var isProcessing: Bool = false
    @Published var processingStatus: String = ""

    private init() {}

    func startProcessing() {
        isProcessing = true
        processingStatus = "Processing video..."
        print("🎬 Video processing started")
    }

    func updateStatus(_ status: String) {
        processingStatus = status
        print("🎬 Processing status: \(status)")
    }

    func finishProcessing() {
        isProcessing = false
        processingStatus = ""
        print("🎬 Video processing finished")
    }
}
