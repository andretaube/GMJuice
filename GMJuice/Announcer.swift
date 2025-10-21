//
//  Announcer.swift
//  GMJuice
//
//  Created by Andre Taube on 10/12/25.
//

import AVFoundation

@MainActor
final class Announcer: NSObject, ObservableObject {
    static let shared = Announcer()

    @Published var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: enabledKey)
            if !isEnabled, synth.isSpeaking {
                synth.stopSpeaking(at: .immediate)
            }
        }
    }
    
    @Published var speakOnSilent: Bool {
        didSet {
            guard speakOnSilent != oldValue else { return }
            defaults.set(speakOnSilent, forKey: speakOnSilentKey)
            configureAudioSession()
        }
    }
    
    @Published var selectedVoiceIdentifier: String? {
        didSet {
            guard selectedVoiceIdentifier != oldValue else { return }
            if let id = selectedVoiceIdentifier {
                defaults.set(id, forKey: voiceIdentifierKey)
            } else {
                defaults.removeObject(forKey: voiceIdentifierKey)
            }
        }
    }
    
    // UserDefaults keys
    private let enabledKey = "announcer_enabled"
    private let speakOnSilentKey = "announcer_speak_on_silent"
    private let voiceIdentifierKey = "announcer_voice_identifier"
    
    private let defaults = UserDefaults.standard
    private let synth = AVSpeechSynthesizer()
    private var audioSessionConfigured = false
    
    private override init() {
        // Load saved preferences or use defaults
        self.isEnabled = defaults.object(forKey: enabledKey) as? Bool ?? true
        self.speakOnSilent = defaults.object(forKey: speakOnSilentKey) as? Bool ?? true
        let defaultVoice = AVSpeechSynthesisVoice.speechVoices().first {
            $0.name == "Alex" && $0.language == "en-US"
        }
        self.selectedVoiceIdentifier = defaults.string(forKey: voiceIdentifierKey) ?? defaultVoice?.identifier
        
        
        super.init()
        
        synth.delegate = self
    }

    /// Configures the audio session based on current settings
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            if speakOnSilent {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            } else {
                try session.setCategory(.ambient, options: [.duckOthers])
            }
            try session.setActive(true, options: [])
            audioSessionConfigured = true
        } catch {
            print("⚠️ Announcer audio session error: \(error.localizedDescription)")
            audioSessionConfigured = false
        }
    }

    /// Speaks the given text if announcer is enabled
    func speak(text: String) {
        guard isEnabled else { return }
        guard !text.isEmpty else { return }

        if !audioSessionConfigured {
            configureAudioSession()
        }

        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.volume = 1.0
        
        // Use selected voice or fall back to default en-US
        if let identifier = selectedVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        } else {
            // Fallback to default en-US voice
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        synth.speak(utterance)
    }

    /// Stops any current speech immediately
    func stop() {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
    }
    
    /// Convenience methods
    func enable()  { isEnabled = true }
    func disable() { isEnabled = false }
    func toggle()  { isEnabled.toggle() }
    
    /// Returns all available voices
    static func allVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
    }
    
    /// Returns voices grouped by language
    static func voicesByLanguage() -> [String: [AVSpeechSynthesisVoice]] {
        let voices = allVoices()
        return Dictionary(grouping: voices) { voice in
            Locale(identifier: voice.language).localizedString(forLanguageCode: voice.language) ?? voice.language
        }
    }
    
    /// Returns English voices only
    static func englishVoices() -> [AVSpeechSynthesisVoice] {
        return allVoices().filter { $0.language.hasPrefix("en") }
    }
    
    /// Get the currently selected voice
    func currentVoice() -> AVSpeechSynthesisVoice? {
        if let identifier = selectedVoiceIdentifier {
            return AVSpeechSynthesisVoice(identifier: identifier)
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension Announcer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        // Speech started
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Speech finished
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Speech cancelled
    }
}
