//
//  Announcer.swift
//  TrainingApp
//
//  Created by Andre Taube on 10/12/25.
//


import AVFoundation

@MainActor
final class Announcer: ObservableObject {
    static let shared = Announcer()

    @Published var isEnabled = true
    @Published var speakOnSilent = true   // if true, plays even when ringer is off
    @Published var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    @Published var voiceLanguage: String = "en-US" // or a specific identifier

    private let synth = AVSpeechSynthesizer()

    private init() {}

    /// Call once at app start or before first speak.
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            if speakOnSilent {
                // Plays through silent switch; ducks other audio a bit
                try session.setCategory(.playback, options: [.duckOthers])
            } else {
                // Respects the ringer/silent switch
                try session.setCategory(.ambient, options: [.duckOthers])
            }
            try session.setActive(true)
        } catch {
            print("Announcer audio session error: \(error)")
        }
    }

    func speakTime(seconds: Double
//                   ,
//                   stageName: String? = nil,
//                   runIndex: Int? = nil,
//                   isPersonalBest: Bool = false
    ) {
        guard isEnabled else { return }
        guard seconds.isFinite, seconds > 0 else { return }

        // Build phrase
//        let timePhrase = Self.format(seconds: seconds)
//        var parts: [String] = []
//        if let idx = runIndex { parts.append("String \(idx)") }
//        if let stage = stageName { parts.append(stage) }
//        parts.append(timePhrase)
//        if isPersonalBest { parts.append("New personal best!") }

//        let text = parts.joined(separator: ", ")

        // Avoid piling up old utterances; keep the most recent
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }

        let u = AVSpeechUtterance(string: String(format: "%.2f", seconds) )
        u.rate = rate
        if let voice = AVSpeechSynthesisVoice(language: voiceLanguage) {
            u.voice = voice
        }
        synth.speak(u)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    // MARK: - Formatting

//    /// "12.34 seconds" / "1 minute 02.15 seconds"
//    private static func format(seconds: Double) -> String {
//        let totalHundredths = Int((seconds * 100).rounded())
//        let mins = totalHundredths / 6000
//        let secs = (totalHundredths % 6000) / 100
//        let hundredths = totalHundredths % 100
//
//        if mins > 0 {
//            // Speak minutes and zero-padded seconds/hundredths
//            return "\(mins) \(mins == 1 ? "minute" : "minutes") \(String(format: "%02d", secs)).\(String(format: "%02d", hundredths)) seconds"
//        } else {
//            return "\(secs).\(String(format: "%02d", hundredths)) seconds"
//        }
//    }
}
