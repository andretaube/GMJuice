//
//  BLEManagerTests.swift
//  GMJuiceTests
//
//  Unit tests for BLE data parsing and connection management
//

import XCTest
import CoreBluetooth
@testable import GMJuice

@MainActor
final class BLEManagerTests: XCTestCase {

    var mockBLE: MockBLEManager!

    override func setUp() async throws {
        try await super.setUp()
        mockBLE = MockBLEManager()
    }

    override func tearDown() async throws {
        mockBLE = nil
        try await super.tearDown()
    }

    // MARK: - Data Parsing Tests

    func testParseBeepData() throws {
        // Given
        let beepData = TestData.createBeepData()

        // When/Then
        let result = mockBLE.simulateDataReceived(beepData)

        // Beep events don't return timing data
        XCTAssertNil(result, "Beep data should not return timing information")
    }

    func testParseShotData() throws {
        // Given
        let expectedNow: Decimal = 2.50
        let expectedSplit: Decimal = 0.45
        let expectedFirst: Decimal = 0.75
        let shotData = TestData.createShotData(
            now: expectedNow,
            split: expectedSplit,
            first: expectedFirst
        )

        // When
        let result = mockBLE.simulateDataReceived(shotData)

        // Then
        XCTAssertNotNil(result, "Shot data should be parsed")
        XCTAssertEqual(result?.now, expectedNow, "Now time should match")
        XCTAssertEqual(result?.split, expectedSplit, "Split time should match")
        XCTAssertEqual(result?.first, expectedFirst, "First shot time should match")
    }

    func testParseInvalidData_TooShort() throws {
        // Given
        let invalidData = Data([1]) // Only 1 byte

        // When
        let result = mockBLE.simulateDataReceived(invalidData)

        // Then
        XCTAssertNil(result, "Invalid data should return nil")
    }

    func testParseInvalidData_WrongType() throws {
        // Given
        var bytes: [UInt8] = [2, 3, 0, 0, 0, 0, 0, 0, 0, 0] // type = 2 (not 1)
        let invalidData = Data(bytes)

        // When
        let result = mockBLE.simulateDataReceived(invalidData)

        // Then
        XCTAssertNil(result, "Data with wrong type should return nil")
    }

    func testParseShotData_EdgeValues() throws {
        // Given - test with very small values
        let shotData = TestData.createShotData(
            now: 0.01,
            split: 0.01,
            first: 0.01
        )

        // When
        let result = mockBLE.simulateDataReceived(shotData)

        // Then
        XCTAssertNotNil(result, "Should parse small values")
        guard let now = result?.now else {
            XCTFail("Result should have now value")
            return
        }
        XCTAssertTrue(
            assertDecimalEqual(now, 0.01, tolerance: 0.001),
            "Small now time should be accurate"
        )
    }

    func testParseShotData_LargeValues() throws {
        // Given - test with larger values (30 second max in Steel Challenge)
        let shotData = TestData.createShotData(
            now: 30.00,
            split: 5.00,
            first: 1.50
        )

        // When
        let result = mockBLE.simulateDataReceived(shotData)

        // Then
        XCTAssertNotNil(result, "Should parse large values")
        XCTAssertEqual(result?.now, 30.00, "Large now time should be accurate")
        XCTAssertEqual(result?.split, 5.00, "Large split time should be accurate")
    }

    // MARK: - Connection Tests

    func testStartScanning() async throws {
        // When
        mockBLE.startScanning()

        // Then
        XCTAssertFalse(mockBLE.discoveredDevices.isEmpty, "Should discover devices")
        XCTAssertTrue(
            mockBLE.discoveredDevices.first?.name.contains("AMG") ?? false,
            "Should discover AMG devices"
        )
    }

    func testStopScanning() async throws {
        // Given
        mockBLE.startScanning()
        XCTAssertFalse(mockBLE.discoveredDevices.isEmpty, "Should have devices after scan")

        // When
        mockBLE.stopScanning()

        // Then
        XCTAssertTrue(mockBLE.discoveredDevices.isEmpty, "Should clear devices after stop")
    }

    func testConnect() async throws {
        // Given
        let expectation = expectation(description: "Connection callback")
        mockBLE.onConnected = { _ in
            expectation.fulfill()
        }

        let mockPeripheral = MockPeripheral(name: "AMG-TEST", uuid: UUID())

        // When
        mockBLE.connect(peripheral: mockPeripheral)

        // Then
        XCTAssertEqual(mockBLE.connectionStatus, .Connecting, "Should be in connecting state")

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(mockBLE.connectionStatus, .Connected, "Should be connected after callback")
    }

    func testDisconnect() async throws {
        // Given
        let mockPeripheral = MockPeripheral(name: "AMG-TEST", uuid: UUID())
        mockBLE.connect(peripheral: mockPeripheral)

        // When
        mockBLE.disconnect()

        // Then
        XCTAssertEqual(mockBLE.connectionStatus, .Disconnected, "Should be disconnected")
    }

    func testSaveDevice() async throws {
        // Given
        let expectation = expectation(description: "Device saved callback")
        mockBLE.onDeviceSaved = {
            expectation.fulfill()
        }

        let deviceId = UUID()
        let deviceName = "AMG-TEST-001"

        // When
        mockBLE.saveDevice(id: deviceId, name: deviceName)

        // Then
        await fulfillment(of: [expectation], timeout: 0.5)
        XCTAssertEqual(mockBLE.savedId(), deviceId, "Should save device UUID")
        XCTAssertEqual(mockBLE.savedDeviceName(), deviceName, "Should save device name")
    }

    // MARK: - Callback Tests

    func testBeepCallback() async throws {
        // Given
        let expectation = expectation(description: "Beep callback")
        var callbackFired = false

        mockBLE.onBeep = {
            callbackFired = true
            expectation.fulfill()
        }

        // When
        mockBLE.simulateBeep()

        // Then
        await fulfillment(of: [expectation], timeout: 0.5)
        XCTAssertTrue(callbackFired, "Beep callback should fire")
    }

    func testShotCallback() async throws {
        // Given
        let expectation = expectation(description: "Shot callback")
        let expectedNow: Decimal = 2.50
        let expectedSplit: Decimal = 0.45
        let expectedFirst: Decimal = 0.75

        var receivedNow: Decimal?
        var receivedSplit: Decimal?
        var receivedFirst: Decimal?

        mockBLE.onShot = { now, split, first in
            receivedNow = now
            receivedSplit = split
            receivedFirst = first
            expectation.fulfill()
        }

        // When
        mockBLE.simulateShot(now: expectedNow, split: expectedSplit, first: expectedFirst)

        // Then
        await fulfillment(of: [expectation], timeout: 0.5)
        XCTAssertEqual(receivedNow, expectedNow, "Now time should match")
        XCTAssertEqual(receivedSplit, expectedSplit, "Split time should match")
        XCTAssertEqual(receivedFirst, expectedFirst, "First time should match")
    }

    func testMultipleShotCallbacks() async throws {
        // Given
        let shotCount = 5
        let expectation = expectation(description: "Multiple shots")
        expectation.expectedFulfillmentCount = shotCount

        var receivedShots: [(Decimal, Decimal, Decimal)] = []

        mockBLE.onShot = { now, split, first in
            receivedShots.append((now, split, first))
            expectation.fulfill()
        }

        // When - simulate 5 shots
        for i in 1...shotCount {
            let now = Decimal(i) * 0.5
            mockBLE.simulateShot(now: now, split: 0.5, first: 0.75)
        }

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedShots.count, shotCount, "Should receive all shots")
        XCTAssertEqual(receivedShots[0].0, 0.5, "First shot should be 0.5")
        XCTAssertEqual(receivedShots[4].0, 2.5, "Last shot should be 2.5")
    }

    // MARK: - Data Conversion Tests

    func testDataConversion_Zero() throws {
        // Given
        let shotData = TestData.createShotData(now: 0, split: 0, first: 0)

        // When
        let result = mockBLE.simulateDataReceived(shotData)

        // Then
        XCTAssertNotNil(result, "Should parse zero values")
        XCTAssertEqual(result?.now, 0, "Zero should be preserved")
    }

    func testDataConversion_Precision() throws {
        // Given - test hundredths precision (0.01 second resolution)
        let shotData = TestData.createShotData(now: 1.23, split: 0.45, first: 0.67)

        // When
        let result = mockBLE.simulateDataReceived(shotData)

        // Then
        XCTAssertNotNil(result, "Should parse precise values")
        guard let now = result?.now, let split = result?.split, let first = result?.first else {
            XCTFail("Result should have all timing values")
            return
        }
        XCTAssertTrue(
            assertDecimalEqual(now, 1.23, tolerance: 0.005),
            "Should maintain hundredths precision for now time"
        )
        XCTAssertTrue(
            assertDecimalEqual(split, 0.45, tolerance: 0.005),
            "Should maintain hundredths precision for split time"
        )
        XCTAssertTrue(
            assertDecimalEqual(first, 0.67, tolerance: 0.005),
            "Should maintain hundredths precision for first shot time"
        )
    }
}
