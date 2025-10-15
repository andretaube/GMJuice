//
//  Announcer.swift
//  GMJuice
//
//  Created by Andre Taube on 10/12/25.
//


import AVFoundation

@MainActor
final class Announcer: ObservableObject {
    static let shared = Announcer()

    @Published var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: key)
            if !isEnabled, synth.isSpeaking {
                synth.stopSpeaking(at: .immediate)
            }
        }
    }
    @Published var speakOnSilent = true   // if true, plays even when ringer is off
    @Published var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    @Published var voiceLanguage: String = "en-US" // or a specific identifier

    
    private let key = "announcer_enabled"
    private let defaults = UserDefaults.standard
    
    private let synth = AVSpeechSynthesizer()

    private init() {
        if defaults.object(forKey: key) != nil {
            self.isEnabled = defaults.bool(forKey: key)
        } else {
            self.isEnabled = true // default
            defaults.set(true, forKey: key)
        }
    }

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

    func speak(text: String) {
        guard isEnabled else { return }

        // Avoid piling up old utterances; keep the most recent
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }

        let u = AVSpeechUtterance(string: text)
        u.rate = rate
        if let voice = AVSpeechSynthesisVoice(language: voiceLanguage) {
            u.voice = voice
        }
        synth.speak(u)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }
    
    func enable()  { isEnabled = true  }
    func disable() { isEnabled = false }
}
