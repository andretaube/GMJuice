//
//  VideoProcessor.swift
//  GMJuice
//
//  Utility for processing recorded videos: trimming and adding overlays
//  with performance data, shots, and splits information.
//

import Foundation
import AVFoundation
import UIKit
import CoreImage

class VideoProcessor {

    /// Trims video and adds overlay with performance data
    /// - Parameters:
    ///   - sourceURL: URL of the source video file
    ///   - startTime: Start time in seconds for trimming
    ///   - endTime: End time in seconds for trimming
    ///   - stringRuns: Array of string runs to display in overlay
    ///   - stage: Stage information
    ///   - division: Division information
    ///   - beepOffsets: Array of beep times relative to recording start (one per string)
    /// - Returns: URL of the processed video file
    func trimAndOverlay(
        sourceURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval,
        stringRuns: [StringRun],
        stage: Stage,
        division: Division,
        beepOffsets: [TimeInterval]
    ) async throws -> URL {

        let asset = AVURLAsset(url: sourceURL)

        // Create composition
        let composition = AVMutableComposition()

        // Add video track
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            throw VideoProcessingError.noVideoTrack
        }

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoProcessingError.failedToCreateCompositionTrack
        }

        // Add audio track if available
        if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
            if let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                let timeRange = CMTimeRange(
                    start: CMTime(seconds: startTime, preferredTimescale: 600),
                    end: CMTime(seconds: endTime, preferredTimescale: 600)
                )
                try compositionAudioTrack.insertTimeRange(
                    timeRange,
                    of: audioTrack,
                    at: .zero
                )
            }
        }

        // Insert trimmed video
        let timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            end: CMTime(seconds: endTime, preferredTimescale: 600)
        )

        try compositionVideoTrack.insertTimeRange(
            timeRange,
            of: videoTrack,
            at: .zero
        )

        // Get video properties
        let videoSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)

        // Apply transform to maintain orientation
        compositionVideoTrack.preferredTransform = preferredTransform

        // Determine actual render size accounting for transform
        let renderSize: CGSize
        if preferredTransform.a == 0 && preferredTransform.d == 0 {
            // Video is rotated 90 or 270 degrees
            renderSize = CGSize(width: videoSize.height, height: videoSize.width)
        } else {
            renderSize = videoSize
        }

        // Create video composition with overlay
        let videoComposition = try await createVideoComposition(
            composition: composition,
            videoTrack: compositionVideoTrack,
            renderSize: renderSize,
            stringRuns: stringRuns,
            stage: stage,
            division: division,
            beepOffsets: beepOffsets,
            trimStartTime: startTime
        )

        // Export the composition
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gmjuice_processed_\(UUID().uuidString).mov")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoProcessingError.failedToCreateExportSession
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition

        if #available(iOS 18.0, *) {
            do {
                try await exportSession.export(to: outputURL, as: .mov)
            } catch {
                throw VideoProcessingError.exportFailed(error)
            }
        } else {
            await exportSession.export()

            if let error = exportSession.error {
                throw VideoProcessingError.exportFailed(error)
            }
        }

        return outputURL
    }

    private func createVideoComposition(
        composition: AVMutableComposition,
        videoTrack: AVMutableCompositionTrack,
        renderSize: CGSize,
        stringRuns: [StringRun],
        stage: Stage,
        division: Division,
        beepOffsets: [TimeInterval],
        trimStartTime: TimeInterval
    ) async throws -> AVMutableVideoComposition {

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30 FPS

        // Create instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(
            start: .zero,
            duration: composition.duration
        )

        // Create layer instruction for video track
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        instruction.layerInstructions = [layerInstruction]

        videoComposition.instructions = [instruction]

        // Create overlay layers
        let overlayLayer = createOverlayLayer(
            size: renderSize,
            stringRuns: stringRuns,
            stage: stage,
            division: division,
            beepOffsets: beepOffsets,
            trimStartTime: trimStartTime,
            videoDuration: composition.duration.seconds
        )

        // Setup animation tool
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        return videoComposition
    }

    private func createOverlayLayer(
        size: CGSize,
        stringRuns: [StringRun],
        stage: Stage,
        division: Division,
        beepOffsets: [TimeInterval],
        trimStartTime: TimeInterval,
        videoDuration: TimeInterval
    ) -> CALayer {

        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: size)

        print("📹 Video overlay size: \(size.width) x \(size.height)")

        let padding: CGFloat = 20
        let bottomHeight: CGFloat = 144  // Reduced by another 20% from 180 (total 40% reduction from 240)
        // Core Animation coordinate system: origin is at BOTTOM-LEFT, Y increases upward
        // So to position at bottom, use small Y value
        let yPosition = padding
        print("📹 Shot panels Y position: \(yPosition) (bottom of video)")

        // Create full-width background bar for shots/splits - lighter and more transparent
        let backgroundBar = CALayer()
        backgroundBar.backgroundColor = UIColor.white.withAlphaComponent(0.3).cgColor
        backgroundBar.frame = CGRect(x: 0, y: 0, width: size.width, height: bottomHeight + padding * 2)
        overlayLayer.addSublayer(backgroundBar)

        // Create shots/splits panels for each string using exact beep timestamps
        for (stringIndex, stringRun) in stringRuns.enumerated() {
            // Guard against mismatched array sizes
            guard stringIndex < beepOffsets.count else {
                print("⚠️ Missing beep offset for string \(stringIndex + 1), skipping overlay")
                continue
            }

            // Calculate when this string's beep happened in the trimmed video
            // beepOffsets[stringIndex] is the beep time relative to recording start
            // We subtract trimStartTime to get the time in the trimmed video
            let beepOffset = beepOffsets[stringIndex] - trimStartTime
            print("📹 String \(stringIndex + 1) beep offset in trimmed video: \(beepOffset)s (recording offset: \(beepOffsets[stringIndex])s)")

            // Calculate when next string starts (to fade out current shots)
            let nextStringStart: TimeInterval
            if stringIndex < stringRuns.count - 1 && stringIndex + 1 < beepOffsets.count {
                // Next string's beep time in trimmed video (no early fade)
                nextStringStart = beepOffsets[stringIndex + 1] - trimStartTime
                print("📹 String \(stringIndex + 1) will fade out at \(nextStringStart)s")
            } else {
                nextStringStart = videoDuration // Last string, no fade out
            }

            // Create top right info display for this string
            let topRightInfo = createTopRightInfo(
                size: size,
                stringRun: stringRun,
                stringIndex: stringIndex,
                allStringRuns: stringRuns,
                stage: stage,
                division: division
            )

            // Start invisible
            topRightInfo.opacity = 0

            // Fade in when string starts (at beep)
            let infoFadeIn = CABasicAnimation(keyPath: "opacity")
            infoFadeIn.fromValue = 0
            infoFadeIn.toValue = 1
            infoFadeIn.duration = 0.3
            infoFadeIn.beginTime = AVCoreAnimationBeginTimeAtZero + beepOffset
            infoFadeIn.fillMode = .forwards
            infoFadeIn.isRemovedOnCompletion = false
            topRightInfo.add(infoFadeIn, forKey: "fadeIn")

            // Fade out when next string starts (except for last string)
            if stringIndex < stringRuns.count - 1 {
                let infoFadeOut = CABasicAnimation(keyPath: "opacity")
                infoFadeOut.fromValue = 1
                infoFadeOut.toValue = 0
                infoFadeOut.duration = 0.3
                infoFadeOut.beginTime = AVCoreAnimationBeginTimeAtZero + nextStringStart
                infoFadeOut.fillMode = .forwards
                infoFadeOut.isRemovedOnCompletion = false
                topRightInfo.add(infoFadeOut, forKey: "fadeOut")
            }

            overlayLayer.addSublayer(topRightInfo)

            // Create shot panels that appear as shots are made
            for (shotIndex, shot) in stringRun.orderedStringShots.enumerated() {
                // Calculate when this shot appears in the video
                let shotNow = NSDecimalNumber(decimal: shot.now).doubleValue
                let shotTime = beepOffset + shotNow

                if shotTime >= 0 && shotTime <= videoDuration {
                    let shotPanel = createRealTimeShotPanel(
                        shot: shot,
                        index: shotIndex + 1,
                        size: size,
                        bottomHeight: bottomHeight,
                        padding: padding
                    )

                    // Position based on shot index (horizontal layout at bottom left)
                    let panelWidth: CGFloat = 168  // Reduced by another 20% from 210
                    let xPos = padding + CGFloat(shotIndex) * panelWidth
                    shotPanel.frame = CGRect(
                        x: xPos,
                        y: yPosition,
                        width: 156,  // Reduced by another 20% from 195
                        height: bottomHeight
                    )

                    print("📹 String \(stringIndex + 1) Shot \(shotIndex + 1) frame: x=\(xPos), y=\(yPosition), appears at \(shotTime)s, fades at \(nextStringStart)s")

                    // Start invisible
                    shotPanel.opacity = 0

                    // Add fade-in animation at the shot timestamp
                    let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
                    fadeInAnimation.fromValue = 0
                    fadeInAnimation.toValue = 1
                    fadeInAnimation.duration = 0.2
                    fadeInAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + shotTime
                    fadeInAnimation.fillMode = .forwards
                    fadeInAnimation.isRemovedOnCompletion = false
                    shotPanel.add(fadeInAnimation, forKey: "fadeIn")

                    // Add fade-out animation when next string starts (except for last string)
                    if stringIndex < stringRuns.count - 1 {
                        let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
                        fadeOutAnimation.fromValue = 1
                        fadeOutAnimation.toValue = 0
                        fadeOutAnimation.duration = 0.3
                        fadeOutAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + nextStringStart
                        fadeOutAnimation.fillMode = .forwards
                        fadeOutAnimation.isRemovedOnCompletion = false
                        shotPanel.add(fadeOutAnimation, forKey: "fadeOut")
                    }

                    overlayLayer.addSublayer(shotPanel)
                }
            }
        }

        return overlayLayer
    }

    private func createRealTimeShotPanel(
        shot: StringShot,
        index: Int,
        size: CGSize,
        bottomHeight: CGFloat,
        padding: CGFloat
    ) -> CALayer {

        let panel = CALayer()
        // No background - using full-width bar instead

        // Split time - regular font (not bold), white text, at BOTTOM (lower Y)
        let splitText = createTextLayer(
            text: Format.formatTime(shot.split),
            fontSize: 48,  // Reduced by another 20% from 60
            bold: false,
            color: .white
        )
        splitText.frame = CGRect(x: 8, y: 8, width: 144, height: 60)
        panel.addSublayer(splitText)

        // Cumulative time (now) - bold, white text, ABOVE splits (higher Y)
        let nowText = createTextLayer(
            text: Format.formatTime(shot.now),
            fontSize: 48,  // Reduced by another 20% from 60
            bold: true,
            color: .white
        )
        nowText.frame = CGRect(x: 8, y: 76, width: 144, height: 60)
        panel.addSublayer(nowText)

        return panel
    }

    private func createTopRightInfo(
        size: CGSize,
        stringRun: StringRun,
        stringIndex: Int,
        allStringRuns: [StringRun],
        stage: Stage,
        division: Division
    ) -> CALayer {
        let container = CALayer()

        // Get this string's time
        let stringTime = stringRun.adjustedTime
        let stringTimeDouble = NSDecimalNumber(decimal: stringTime).doubleValue

        // Calculate percent for this string
        let percent = PeakBenchmarks.percent(division: division, stageCode: stage.code, time: stringTime)
        let percentDouble = NSDecimalNumber(decimal: percent).doubleValue
        let shooterClass = ShooterClass.shooterClass(percentage: percent)

        // Position at top right
        let infoWidth: CGFloat = 320
        let infoHeight: CGFloat = 360  // 6 lines * 60px per line
        let xPos = size.width - infoWidth - 20
        let yPos = size.height - infoHeight - 20  // Top in Core Animation coords

        // Format current date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let dateString = dateFormatter.string(from: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: Date())

        // Total Time - just the number (TOP - position 6 of 6)
        let timeValue = createTextLayer(
            text: String(format: "%.2f", stringTimeDouble),
            fontSize: 50,
            bold: true,
            color: .white
        )
        timeValue.frame = CGRect(x: xPos, y: yPos + 305, width: infoWidth, height: 50)
        timeValue.alignmentMode = .right
        container.addSublayer(timeValue)

        // Stage Code (position 5 of 6)
        let stageCodeValue = createTextLayer(
            text: stage.code,
            fontSize: 50,
            bold: true,
            color: .white
        )
        stageCodeValue.frame = CGRect(x: xPos, y: yPos + 245, width: infoWidth, height: 50)
        stageCodeValue.alignmentMode = .right
        container.addSublayer(stageCodeValue)

        // Division (position 4 of 6)
        let divisionValue = createTextLayer(
            text: division.rawValue,
            fontSize: 50,
            bold: true,
            color: .white
        )
        divisionValue.frame = CGRect(x: xPos, y: yPos + 185, width: infoWidth, height: 50)
        divisionValue.alignmentMode = .right
        container.addSublayer(divisionValue)

        // Percent and Class - format like "87% (M)" (position 3 of 6)
        let percentValue = createTextLayer(
            text: String(format: "%.0f%% (%@)", percentDouble, shooterClass.rawValue),
            fontSize: 50,
            bold: true,
            color: .white
        )
        percentValue.frame = CGRect(x: xPos, y: yPos + 125, width: infoWidth, height: 50)
        percentValue.alignmentMode = .right
        container.addSublayer(percentValue)

        // Current Date (position 2 of 6)
        let dateValue = createTextLayer(
            text: dateString,
            fontSize: 50,
            bold: false,
            color: .white
        )
        dateValue.frame = CGRect(x: xPos, y: yPos + 65, width: infoWidth, height: 50)
        dateValue.alignmentMode = .right
        container.addSublayer(dateValue)

        // Current Time (position 1 of 6 - BOTTOM)
        let currentTimeValue = createTextLayer(
            text: timeString,
            fontSize: 50,
            bold: false,
            color: .white
        )
        currentTimeValue.frame = CGRect(x: xPos, y: yPos + 5, width: infoWidth, height: 50)
        currentTimeValue.alignmentMode = .right
        container.addSublayer(currentTimeValue)

        return container
    }

    private func createTextLayer(
        text: String,
        fontSize: CGFloat,
        bold: Bool,
        color: UIColor
    ) -> CATextLayer {

        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = color.cgColor
        textLayer.isWrapped = false
        textLayer.alignmentMode = .left
        textLayer.contentsScale = UIScreen.main.scale

        // Add shadow for better readability on any background
        textLayer.shadowColor = UIColor.black.cgColor
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.shadowRadius = 4
        textLayer.shadowOpacity = 0.8

        if bold {
            textLayer.font = UIFont.boldSystemFont(ofSize: fontSize)
        } else {
            textLayer.font = UIFont.systemFont(ofSize: fontSize)
        }

        return textLayer
    }
}

// MARK: - Errors

enum VideoProcessingError: Error {
    case noVideoTrack
    case failedToCreateCompositionTrack
    case failedToCreateExportSession
    case exportFailed(Error)
}
