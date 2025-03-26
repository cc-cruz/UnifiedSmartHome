import XCTest
@testable import UnifiedSmartHome

final class SmartThingsWebhookHandlerTests: XCTestCase {
    var handler: SmartThingsWebhookHandler!
    var mockDeviceManager: MockDeviceManager!
    var mockAuditLogger: MockAuditLogger!
    
    override func setUp() {
        super.setUp()
        mockDeviceManager = MockDeviceManager()
        mockAuditLogger = MockAuditLogger()
        
        handler = SmartThingsWebhookHandler(
            deviceManager: mockDeviceManager,
            auditLogger: mockAuditLogger
        )
    }
    
    override func tearDown() {
        handler = nil
        mockDeviceManager = nil
        mockAuditLogger = nil
        super.tearDown()
    }
    
    // MARK: - Device Event Tests
    
    func testHandleDeviceEvent() async throws {
        // Arrange
        let deviceId = "device-123"
        let event = SmartThingsWebhookEventPayload(
            eventId: "event-123",
            eventType: .deviceEvent,
            deviceId: deviceId,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            data: [
                "switch": AnyCodable("on"),
                "level": AnyCodable(80)
            ]
        )
        
        let mockDevice = LightDevice(
            id: deviceId,
            name: "Test Light",
            manufacturerName: "SmartThings",
            modelName: "Smart Bulb",
            deviceTypeName: "light",
            capabilities: [],
            components: [],
            status: .online,
            healthState: .healthy,
            attributes: [:]
        )
        
        mockDeviceManager.getDeviceResult = mockDevice
        
        // Act
        try await handler.handleEvent(event)
        
        // Assert
        XCTAssertEqual(mockAuditLogger.loggedEvents.count, 1)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].category, .deviceEvent)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].action, .webhookReceived)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].status, .success)
        
        XCTAssertEqual(mockDeviceManager.updateDeviceStateCalled, true)
        XCTAssertEqual(mockDeviceManager.updateDeviceStateDevice?.id, deviceId)
    }
    
    // MARK: - Device Health Tests
    
    func testHandleDeviceHealth() async throws {
        // Arrange
        let deviceId = "device-123"
        let event = SmartThingsWebhookEventPayload(
            eventId: "event-123",
            eventType: .deviceHealth,
            deviceId: deviceId,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            data: [
                "healthState": AnyCodable("OFFLINE")
            ]
        )
        
        let mockDevice = LightDevice(
            id: deviceId,
            name: "Test Light",
            manufacturerName: "SmartThings",
            modelName: "Smart Bulb",
            deviceTypeName: "light",
            capabilities: [],
            components: [],
            status: .online,
            healthState: .healthy,
            attributes: [:]
        )
        
        mockDeviceManager.getDeviceResult = mockDevice
        
        // Act
        try await handler.handleEvent(event)
        
        // Assert
        XCTAssertEqual(mockAuditLogger.loggedEvents.count, 1)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].category, .deviceEvent)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].action, .webhookReceived)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].status, .success)
        
        XCTAssertEqual(mockDeviceManager.updateDeviceHealthCalled, true)
        XCTAssertEqual(mockDeviceManager.updateDeviceHealthDevice?.id, deviceId)
        XCTAssertEqual(mockDeviceManager.updateDeviceHealthState, "OFFLINE")
    }
    
    // MARK: - Device Lifecycle Tests
    
    func testHandleDeviceLifecycleAdded() async throws {
        // Arrange
        let deviceId = "device-123"
        let event = SmartThingsWebhookEventPayload(
            eventId: "event-123",
            eventType: .deviceLifecycle,
            deviceId: deviceId,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            data: [
                "lifecycle": AnyCodable("ADDED")
            ]
        )
        
        let mockDevice = LightDevice(
            id: deviceId,
            name: "Test Light",
            manufacturerName: "SmartThings",
            modelName: "Smart Bulb",
            deviceTypeName: "light",
            capabilities: [],
            components: [],
            status: .online,
            healthState: .healthy,
            attributes: [:]
        )
        
        mockDeviceManager.fetchDeviceResult = mockDevice
        
        // Act
        try await handler.handleEvent(event)
        
        // Assert
        XCTAssertEqual(mockAuditLogger.loggedEvents.count, 1)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].category, .deviceEvent)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].action, .webhookReceived)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].status, .success)
        
        XCTAssertEqual(mockDeviceManager.addDeviceCalled, true)
        XCTAssertEqual(mockDeviceManager.addDeviceDevice?.id, deviceId)
    }
    
    func testHandleDeviceLifecycleRemoved() async throws {
        // Arrange
        let deviceId = "device-123"
        let event = SmartThingsWebhookEventPayload(
            eventId: "event-123",
            eventType: .deviceLifecycle,
            deviceId: deviceId,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            data: [
                "lifecycle": AnyCodable("REMOVED")
            ]
        )
        
        // Act
        try await handler.handleEvent(event)
        
        // Assert
        XCTAssertEqual(mockAuditLogger.loggedEvents.count, 1)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].category, .deviceEvent)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].action, .webhookReceived)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].status, .success)
        
        XCTAssertEqual(mockDeviceManager.removeDeviceCalled, true)
        XCTAssertEqual(mockDeviceManager.removeDeviceId, deviceId)
    }
} 