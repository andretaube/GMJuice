import SwiftUI

struct VoiceSettingsView: View {
    @ObservedObject private var announcer = Announcer.shared

    var body: some View {
        Form {
            Section {
                Toggle("Announcements Enabled", isOn: $announcer.isEnabled)

                Toggle("Speak on Silent", isOn: $announcer.speakOnSilent)

                NavigationLink {
                    VoicePickerView()
                } label: {
                    HStack {
                        Text("Voice")
                        Spacer()
                        if let voice = announcer.currentVoice() {
                            Text(voice.name)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Voice Settings")
            } footer: {
                Text("Configure text-to-speech announcements for your training sessions. Enable announcements to hear your times and performance feedback.")
            }
        }
        .navigationTitle("Voice Settings")
    }
}

#Preview {
    NavigationStack {
        VoiceSettingsView()
    }
}
