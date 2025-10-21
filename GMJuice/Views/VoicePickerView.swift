//
//  VoicePickerView.swift
//  GMJuice
//
//  Created by Andre Taube on 10/20/25.
//

import SwiftUI
import AVFoundation

struct VoicePickerView: View {
    @ObservedObject var announcer = Announcer.shared
    @Environment(\.dismiss) private var dismiss
    
    private let previewMessage = "Hello, I am your coach!"
    
    var body: some View {
        NavigationStack {
            List {
                // Show message if no enhanced voices
                if enhancedVoices.isEmpty {
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("To add more voices go to:")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Text("Settings → Accessibility → Spoken Content → Voices → English")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Voice list
                Section {
                    // Default voice
                    if let defaultVoice = defaultVoice {
                        VoiceRow(
                            voice: defaultVoice,
                            isSelected: defaultVoice.identifier == announcer.selectedVoiceIdentifier
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            announcer.selectedVoiceIdentifier = defaultVoice.identifier
                            announcer.speak(text: previewMessage)
                        }
                    }
                    
                    // Enhanced voices
                    ForEach(enhancedVoices, id: \.identifier) { voice in
                        VoiceRow(
                            voice: voice,
                            isSelected: voice.identifier == announcer.selectedVoiceIdentifier
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            announcer.selectedVoiceIdentifier = voice.identifier
                            announcer.speak(text: previewMessage)
                        }
                    }
                }
            }
            .navigationTitle("Voice Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var defaultVoice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices().first {
            $0.name == "Alex" && $0.language == "en-US"
        } ?? AVSpeechSynthesisVoice(language: "en-US")
    }
    
    private var enhancedVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter {
            ($0.language == "en-US" || $0.language == "en-GB") &&
            ($0.quality == .enhanced || $0.quality == .premium)
        }
    }
}

struct VoiceRow: View {
    let voice: AVSpeechSynthesisVoice
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(voice.name)
                    .font(.body)
                
                HStack(spacing: 8) {
                    Text(voice.language == "en-US" ? "United States" : "United Kingdom")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    qualityBadge
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .font(.body.weight(.semibold))
            }
        }
        .padding(.vertical, 2)
    }
    
    @ViewBuilder
    private var qualityBadge: some View {
        if voice.quality == .premium {
            Text("Premium")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.2))
                .foregroundColor(.purple)
                .cornerRadius(4)
        } else if voice.quality == .enhanced {
            Text("Enhanced")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(4)
        } else if voice.quality == .default {
            Text("Default")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.gray)
                .cornerRadius(4)
        }
    }
}

#Preview {
    VoicePickerView()
}
