//
//  MockBLEManager.swift
//  GMJuiceTests
//
//  Mock implementation of BLEManager for testing without hardware dependencies
//

import Foundation
import CoreBluetooth
@testable import GMJuice

@MainActor
class MockBLEManager {
    var connectionStatus: BLEConnectionStatus = .Disconnected
    var discoveredDevices: [MockPeripheral] = []

    // Callbacks matching BLEManager interface
    var onDeviceSaved: (() -> Void)?
    var onConnecting: ((MockPeripheral) -> Void)?
    var onConnected: ((MockPeripheral) -> Void)?
    var onConnectFailed: ((MockPeripheral, Error?) -> Void)?
    var onDisconnected: ((MockPeripheral, Error?) -> Void)?
    var onBeep: (() -> Void)?
    var onShot: ((Decimal, Decimal, Decimal) -> Void)?
    var onStopWaiting: (() -> Void)?

    // Simulate saved device
    private var savedUUID: UUID?
    private var savedName: String?

    func startScanning() {
        // Simulate discovering an AMG device
        let mockDevice = MockPeripheral(name: "AMG-TEST-001", uuid: UUID())
        discoveredDevices = [mockDevice]
    }

    func stopScanning() {
        discoveredDevices = []
    }

    func connect(peripheral: MockPeripheral) {
        connectionStatus = .Connecting
        onConnecting?(peripheral)

        // Simulate successful connection after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.connectionStatus = .Connected
                self.onConnected?(peripheral)
            }
        }
    }

    func disconnect() {
        connectionStatus = .Disconnected
    }

    func saveDevice(id: UUID, name: String) {
        savedUUID = id
        savedName = name
        onDeviceSaved?()
    }

    func savedId() -> UUID? {
        return savedUUID
    }

    func savedDeviceName() -> String {
        return savedName ?? "None"
    }

    // MARK: - Test Helpers

    /// Simulate a beep event from the timer
    func simulateBeep() {
        onBeep?()
    }

    /// Simulate a shot event from the timer
    func simulateShot(now: Decimal, split: Decimal, first: Decimal) {
        onShot?(now, split, first)
    }

    /// Simulate parsing BLE data (for testing data parsing logic)
    func simulateDataReceived(_ data: Data) -> (now: Decimal?, split: Decimal?, first: Decimal?)? {
        guard data.count >= 2 else { return nil }
        let bytes = [UInt8](data)

        let type = bytes[0]
        guard type == 1 else { return nil }

        let subtype = bytes[1]

        if subtype == 3 { // shot
            guard data.count >= 10 else { return nil }

            let now = convertData(high: bytes[4], low: bytes[5])
            let split = convertData(high: bytes[6], low: bytes[7])
            let first = convertData(high: bytes[8], low: bytes[9])

            return (now, split, first)
        }

        return nil
    }

    private func convertData(high: UInt8, low: UInt8) -> Decimal {
        let combinedValue = (Int(high) << 8) | Int(low)
        let decimalValue = Decimal(combinedValue)
        let divisor = Decimal(100)
        return decimalValue / divisor
    }
}

// MARK: - Mock Peripheral

struct MockPeripheral {
    let name: String
    let uuid: UUID

    init(name: String, uuid: UUID = UUID()) {
        self.name = name
        self.uuid = uuid
    }
}
