import SwiftUI

struct SettingsView: View {
    @ObservedObject private var ble = SettingsViewModel.shared

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
            }
                
        }
        .navigationTitle("BLE Debug")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Image(systemName: "ladybug")
            }
        }
        .onAppear {
            BLEManager.shared.startScanning()
        }
        .onDisappear {
            BLEManager.shared.stopScanning()
        }
    }
}
