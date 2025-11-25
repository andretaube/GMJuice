//
//  VideosView.swift
//  GMJuice
//
//  View to display and manage recorded training videos
//

import SwiftUI
import AVKit

struct VideosView: View {
    @StateObject private var viewModel = VideosViewModel()
    @ObservedObject private var processingManager = VideoProcessingManager.shared
    @State private var showDeleteAlert = false
    @State private var videoToDelete: VideoItem?
    private let analytics = AnalyticsService.shared

    var body: some View {
        Group {
                if viewModel.videos.isEmpty && !processingManager.isProcessing {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        // Processing indicator
                        if processingManager.isProcessing {
                            processingBanner
                        }

                        videoList
                    }
                }
            }
            .navigationTitle("Videos")
            .onAppear {
                analytics.trackScreen("VideosView")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.videos.isEmpty {
                        EditButton()
                    }
                }
            }
            .alert("Delete Video", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let video = videoToDelete {
                        viewModel.deleteVideo(video)
                        videoToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this video? This action cannot be undone.")
            }
            .onAppear {
                viewModel.loadVideos()
            }
            .refreshable {
                viewModel.loadVideos()
            }
            .onChange(of: processingManager.isProcessing) { _, isProcessing in
                // Reload videos when processing finishes
                if !isProcessing {
                    viewModel.loadVideos()
                }
            }
    }

    private var processingBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)

            VStack(alignment: .leading, spacing: 2) {
                Text("Processing Video")
                    .font(.subheadline.bold())

                Text(processingManager.processingStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Videos Yet")
                .font(.title2.bold())

            Text("Record your training sessions using the Video mode to see them here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var videoList: some View {
        List {
            ForEach(viewModel.videos) { video in
                Button {
                    presentVideoPlayer(for: video)
                } label: {
                    VideoRowView(video: video)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        videoToDelete = video
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let video = viewModel.videos[index]
                    videoToDelete = video
                    showDeleteAlert = true
                }
            }
        }
    }

    private func presentVideoPlayer(for video: VideoItem) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        // Unlock orientation before presenting
        AppDelegate.orientationLock = .all

        // Create and configure AVPlayerViewController
        let player = AVPlayer(url: video.url)
        let playerVC = RotatableAVPlayerViewController()
        playerVC.player = player
        playerVC.modalPresentationStyle = .fullScreen
        playerVC.onDismiss = {
            AppDelegate.orientationLock = .portrait
        }

        // Present and play
        topController.present(playerVC, animated: true) {
            player.play()
        }
    }
}

class RotatableAVPlayerViewController: AVPlayerViewController {
    var onDismiss: (() -> Void)?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            onDismiss?()
        }
    }
}

// MARK: - Video Row View

struct VideoRowView: View {
    let video: VideoItem
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .frame(width: 120, height: 67.5)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Video info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.stageName)
                    .font(.headline)

                Text(video.division)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(video.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if let duration = video.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 4)
        .task {
            thumbnail = await generateThumbnail(for: video.url)
        }
    }

    private func generateThumbnail(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try await imageGenerator.image(at: .zero).image
            return UIImage(cgImage: cgImage)
        } catch {
            print("⚠️ Failed to generate thumbnail: \(error)")
            return nil
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Video Item Model

struct VideoItem: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    let date: Date
    let stageCode: String
    let division: String
    let duration: TimeInterval?

    var stageName: String {
        AllStages.first(where: { $0.code == stageCode })?.name ?? stageCode
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Videos ViewModel

@MainActor
class VideosViewModel: ObservableObject {
    @Published var videos: [VideoItem] = []

    func loadVideos() {
        Task {
            await loadVideosAsync()
        }
    }

    private func loadVideosAsync() async {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ Documents directory not found")
            return
        }

        let videosDirectory = documentsPath.appendingPathComponent("Videos")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: videosDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            var videoItems: [VideoItem] = []

            for url in fileURLs {
                guard url.pathExtension == "mov" || url.pathExtension == "mp4" else {
                    continue
                }

                // Parse filename: 2025-01-15_14-30-45_SC-101_RFPO.mov
                let fileName = url.deletingPathExtension().lastPathComponent
                let components = fileName.split(separator: "_")

                guard components.count >= 4 else {
                    continue
                }

                // Extract date from filename
                let dateString = "\(components[0])_\(components[1])"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let date = dateFormatter.date(from: dateString) ?? Date()

                let stageCode = String(components[2])
                let division = String(components[3])

                // Get video duration
                let asset = AVURLAsset(url: url)
                let duration = try? await asset.load(.duration).seconds

                let videoItem = VideoItem(
                    url: url,
                    fileName: fileName,
                    date: date,
                    stageCode: stageCode,
                    division: division,
                    duration: duration
                )

                videoItems.append(videoItem)
            }

            // Sort by date (newest first)
            videos = videoItems.sorted { $0.date > $1.date }

            print("📹 Loaded \(videos.count) videos")

        } catch {
            print("⚠️ Error loading videos: \(error)")
        }
    }

    func deleteVideo(_ video: VideoItem) {
        do {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: video.url.path)[.size] as? Int64)
            
            try FileManager.default.removeItem(at: video.url)
            videos.removeAll { $0.id == video.id }
            
            // Track video deletion
            AnalyticsService.shared.trackVideoDeleted(
                stage: video.stageCode,
                division: video.division,
                fileSize: fileSize
            )
            
            print("✅ Video deleted: \(video.fileName)")
        } catch {
            print("⚠️ Failed to delete video: \(error)")
            AnalyticsService.shared.trackError(error, context: "VideosViewModel.deleteVideo")
        }
    }
}
