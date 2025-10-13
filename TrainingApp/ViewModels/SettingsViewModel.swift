import Foundation
import CoreBluetooth
import Combine

final class SettingsViewModel: ObservableObject {
    static let shared = SettingsViewModel()
    
    let ble = BLEManager.shared

    
    struct Device: Identifiable, Equatable {
        let id: UUID
        let name: String
    }
    
    @Published var devices: [Device] = []
    @Published var savedId: UUID?
    @Published var savedName: String = "None"
    @Published var connectionStatus: String = "";
    
    private var bag = Set<AnyCancellable>()
    
    private init() {
        // Bridge discovered peripherals into simple, Identifiable models
        ble.$discoveredDevices
            .map { $0.map { Device(id: $0.identifier, name: $0.name ?? "") } }
            .receive(on: RunLoop.main)
            .assign(to: \.devices, on: self)
            .store(in: &bag)
                
        self.savedId = ble.savedId()
        self.savedName = ble.savedName()
        
        ble.onDeviceSaved = { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.savedId = self.ble.savedId()
                self.savedName = self.ble.savedName()
            }
        }
        
        ble.onConnecting = { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.connectionStatus = "Connecting..."
            }
        }
        
        ble.onConnected = { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.connectionStatus = "Connected"
            }
        }
        
        ble.onDisconnected = { [weak self] _, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.connectionStatus = "Disconnected"
            }
        }
        
        ble.onConnectFailed = { [weak self] _, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.connectionStatus = "Failed: \(error?.localizedDescription ?? "unknown")"
            }
        }

        
        
    }
    
    
}
