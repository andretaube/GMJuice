import SwiftUI

struct SettingsView: View {
    @ObservedObject private var ble = SettingsViewModel.shared
    @ObservedObject private var announcer = Announcer.shared
    
    var body: some View {
        NavigationStack {
            Form {

                Section("Connected Timer") {
                    HStack {
                        Text("Device")
                        Spacer()
                        Text(ble.savedName).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(ble.connectionStatus).foregroundColor(.secondary)
                    }
                }
                
                Section("Discovered Devices") {
                    ForEach(ble.devices) { dev in
                        Button {
                            BLEManager.shared.saveDevice(
                                id: dev.id,
                                name: dev.name.isEmpty ? "Unknown" : dev.name
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dev.name.isEmpty ? "Unknown" : dev.name)
                                    .font(.headline)
                                Text(dev.id.uuidString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // In your settings view
                Section("Voice") {
                    Toggle("Announcements Enabled", isOn: $announcer.isEnabled)
                    
                    Toggle("Speak on Silent", isOn: $announcer.speakOnSilent)
                                        
                    // Add voice picker button
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
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            BLEManager.shared.startScanning()
        }
        .onDisappear {
            BLEManager.shared.stopScanning()
        }
    }
}
