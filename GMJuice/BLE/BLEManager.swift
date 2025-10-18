//
//  BLEManager.swift
//  GMJuice
//
//  Created by Andre Taube on 10/9/25.
//
import Foundation
import CoreBluetooth

final class BLEManager: NSObject, ObservableObject {
    public static let shared = BLEManager()
    
    private let TIMER_SERVICE = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let TIMER_NOTIFY  = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    private let TIMER_WRITE   = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let TIMER_NAME_PREFIX = "AMG"
    
    private var central: CBCentralManager!
    @Published var discoveredDevices: [CBPeripheral] = []
    
    // MARK: - Persistence keys
    private let savedUUIDKey = "ble_saved_uuid"
    private let savedNameKey = "ble_saved_name"
    
    private var current: CBPeripheral?
    
    var onDeviceSaved: (() -> Void)?
    var onConnecting: ((CBPeripheral) -> Void)?
    var onConnected: ((CBPeripheral) -> Void)?
    var onConnectFailed: ((CBPeripheral, Error?) -> Void)?
    var onDisconnected: ((CBPeripheral, Error?) -> Void)?
    var onBeep: (() -> Void)?
    var onShot: ((Decimal, Decimal, Decimal) -> Void)?
    var onStopWaiting: (() -> Void)?

    
    private var notifyChar: CBCharacteristic?
    private var writeChar:  CBCharacteristic?
    
    override private init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }
    
    func start() {
        if central.state == .poweredOn {
            connectSavedOrScan()
        }
    }
    
    func connectSavedOrScan() {
        if let savedUUID = savedId(),
           let p = central.retrievePeripherals(withIdentifiers: [savedUUID]).first {
            print("Connecting to saved device \(savedUUID)")
            current = p
            current?.delegate = self
            onConnecting?(p)
            central.connect(p, options: [
                CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
                CBConnectPeripheralOptionNotifyOnNotificationKey: true
            ])
        } else {
            print("No saved devices to connect to")
        }
    }
    
    // MARK: - Public
    
    public func startScanning() {
        guard central.state == .poweredOn else {
            print("Central not powered on, cannot scan yet.")
            return
        }
        
        discoveredDevices.removeAll()
        central.scanForPeripherals(
            withServices: nil
            
        )
        
        print("Started scanning for BLE devices...")
        
        central.retrieveConnectedPeripherals(withServices: [TIMER_SERVICE])
    }
    
    public func stopScanning() {
        central.stopScan()
        discoveredDevices.removeAll()
        print ("Scan stopped")
    }
    
    public func connect(savedUUID: UUID?) {
        guard central.state == .poweredOn else { return }
        guard let id = savedUUID,
              let p = central.retrievePeripherals(withIdentifiers: [id]).first else {
            return
        }
        current = p
        current?.delegate = self
        onConnecting?(p)
        central.connect(p, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ])
    }
    
    public func disconnect() {
        if let p = current { central.cancelPeripheralConnection(p) }
    }
    
    public func saveDevice(id: UUID, name: String) {
        UserDefaults.standard.set(id.uuidString, forKey: savedUUIDKey)
        UserDefaults.standard.set(name, forKey: savedNameKey)
        UserDefaults.standard.synchronize()
        onDeviceSaved?();
        print("Saved device: \(name) : \(id)")
        connect(savedUUID: id)
    }
    
    public func savedId() -> UUID? {
        guard let s = UserDefaults.standard.string(forKey: savedUUIDKey),
              let id = UUID(uuidString: s),
              !s.isEmpty
        else { return nil }
        return id
    }
    
    public func savedName() -> String {
        return UserDefaults.standard.string(forKey: savedNameKey).flatMap { $0.isEmpty ? nil : $0 } ?? "None"
    }
    
    private func handleData(_ data: Data) {
        guard data.count >= 2 else { return }
        let bytes = [UInt8](data)
        
        var timeNow: Decimal?
        var timeSplit: Decimal?
        var timeFirst: Decimal?

        let type = bytes[0]
        
        if type == 1 {
            let subtype = bytes[1]
            switch subtype {
            case 5: // beep
                if let onBeep = onBeep {
                    DispatchQueue.main.async {
                        onBeep()
                    }
                }
            case 8: // stop waiting
                if let onStopWaiting = onStopWaiting {
                    DispatchQueue.main.async {
                        onStopWaiting()
                    }
                }
            case 3: // a shot
                func pair(_ hi: Int, _ lo: Int) -> (UInt8, UInt8)? {
                    guard hi < bytes.count, lo < bytes.count else { return nil }
                    return (bytes[hi], bytes[lo])
                }
                if let (h4, l5) = pair(4, 5) { timeNow = convertData(high: h4, low: l5) }
                if let (h6, l7) = pair(6, 7) { timeSplit = convertData(high: h6, low: l7) }
                if let (h8, l9) = pair(8, 9) { timeFirst = convertData(high: h8, low: l9) }
                                
                if let onShot = onShot, let now = timeNow, let split = timeSplit, let first = timeFirst {
                    DispatchQueue.main.async {
                        onShot(now, split, first)
                    }
                }
                
            default:
                break
            }
        }
    }
    
    private func convertData(high: UInt8, low: UInt8) -> Decimal {
        // Combine the bytes into a single integer.
        let combinedValue = (Int(high) << 8) | Int(low)
        
        // Initialize a Decimal from the integer value.
        let decimalValue = Decimal(combinedValue)
        
        // Perform division using another Decimal value.
        let divisor = Decimal(100)
        
        return decimalValue / divisor
    }

}


// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth powered on.")
        case .poweredOff:
            print("Bluetooth powered off.")
        case .resetting:
            print("Bluetooth resetting...")
        case .unauthorized:
            print("Bluetooth unauthorized.")
        case .unsupported:
            print("Bluetooth unsupported on this device.")
        case .unknown:
            fallthrough
        @unknown default:
            print("Bluetooth state unknown.")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        if let timerName = peripheral.name, timerName.contains("AMG") {
            if !discoveredDevices.contains(peripheral) {
                discoveredDevices.append(peripheral)
                let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "Unknown"
                print("==> Discovered: \(name) [\(peripheral.identifier)] RSSI=\(RSSI)")
                
                if let uuids = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID], !uuids.isEmpty {
                    print("  Service UUIDs: \(uuids.map { $0.uuidString }.joined(separator: ", "))")
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        onConnected?(peripheral)
        // Typically discover services next:
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        onConnectFailed?(peripheral, error)
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        onDisconnected?(peripheral, error)
        // If this was your current device, clear it or auto-retry as desired
        if current?.identifier == peripheral.identifier { current = nil }
    }

    
}

extension BLEManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach {
            peripheral.discoverCharacteristics(nil, for: $0)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {

        if let error { print("Char discovery error:", error); return }
        guard let chars = service.characteristics else { return }

        for c in chars {
            if c.uuid == TIMER_NOTIFY { notifyChar = c }
            if c.uuid == TIMER_WRITE  { writeChar  = c }
        }

        if let c = notifyChar {
            if c.properties.contains(.notify) || c.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: c)
            } else {
                print("Target char doesn’t support notify/indicate")
            }
        } else {
            print("Notify characteristic not found — check UUID")
        }
        
    }

    // Handy extras you might use:
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) { /* … */ }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) { /* … */ }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        handleData(data)
    }
}
