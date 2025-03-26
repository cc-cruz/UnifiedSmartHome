import XCTest
@testable import UnifiedSmartHome

final class SmartThingsAdapterTests: XCTestCase {
    var adapter: SmartThingsAdapter!
    var mockNetworkService: MockNetworkService!
    var mockSecurityService: MockSecurityService!
    var mockAuditLogger: MockAuditLogger!
    var mockRateLimiter: MockRateLimiter!
    
    override func setUp() {
        super.setUp()
        mockNetworkService = MockNetworkService()
        mockSecurityService = MockSecurityService()
        mockAuditLogger = MockAuditLogger()
        mockRateLimiter = MockRateLimiter()
        
        adapter = SmartThingsAdapter(
            networkService: mockNetworkService,
            securityService: mockSecurityService,
            auditLogger: mockAuditLogger,
            rateLimiter: mockRateLimiter
        )
        
        // Initialize the adapter with a dummy auth token
        adapter.authToken = "test-token"
    }
    
    override func tearDown() {
        adapter = nil
        mockNetworkService = nil
        mockSecurityService = nil
        mockAuditLogger = nil
        mockRateLimiter = nil
        super.tearDown()
    }
    
    // MARK: - Device Status Tests
    
    func testGetDeviceStatus() async throws {
        // Arrange
        let deviceId = "device-123"
        let deviceName = "Test Light"
        
        let mockResponse = SmartThingsDevice(
            deviceId: deviceId,
            name: deviceName,
            label: "Living Room Light",
            manufacturerName: "SmartThings",
            presentationId: "abc123",
            type: "LIGHT",
            deviceManufacturerCode: "ST01",
            locationId: "location-123",
            roomId: "room-123",
            components: [
                SmartThingsComponent(
                    id: "main",
                    capabilities: [
                        SmartThingsCapability(
                            id: "switch",
                            version: 1,
                            status: SmartThingsCapabilityStatus(
                                switch: SmartThingsCapabilityStatus.SwitchStatus(value: "on")
                            )
                        ),
                        SmartThingsCapability(
                            id: "switchLevel",
                            version: 1,
                            status: SmartThingsCapabilityStatus(
                                level: SmartThingsCapabilityStatus.SwitchLevelStatus(value: 80)
                            )
                        )
                    ]
                )
            ]
        )
        
        mockNetworkService.mockResponses["https://api.smartthings.com/v1/devices/\(deviceId)"] = mockResponse
        
        // Act
        let device = try await adapter.getDeviceStatus(id: deviceId)
        
        // Assert
        XCTAssertNotNil(device)
        XCTAssertEqual(device.id, deviceId)
        XCTAssertEqual(device.name, "Living Room Light")
        
        // Verify it's a light device with correct properties
        guard let lightDevice = device as? LightDevice else {
            XCTFail("Device should be a LightDevice")
            return
        }
        
        XCTAssertEqual(lightDevice.isOn, true)
        XCTAssertEqual(lightDevice.brightness, 80)
    }
    
    func testGetDeviceStatusById() async throws {
        // Arrange
        let deviceId = "device-123"
        let deviceName = "Test Light"
        
        let mockResponse = SmartThingsDevice(
            deviceId: deviceId,
            name: deviceName,
            label: "Living Room Light",
            manufacturerName: "SmartThings",
            presentationId: "abc123",
            type: "LIGHT",
            deviceManufacturerCode: "ST01",
            locationId: "location-123",
            roomId: "room-123",
            components: [
                SmartThingsComponent(
                    id: "main",
                    capabilities: [
                        SmartThingsCapability(
                            id: "switch",
                            version: 1,
                            status: SmartThingsCapabilityStatus(
                                switch: SmartThingsCapabilityStatus.SwitchStatus(value: "on")
                            )
                        ),
                        SmartThingsCapability(
                            id: "switchLevel",
                            version: 1,
                            status: SmartThingsCapabilityStatus(
                                level: SmartThingsCapabilityStatus.SwitchLevelStatus(value: 80)
                            )
                        )
                    ]
                )
            ]
        )
        
        mockNetworkService.mockResponses["https://api.smartthings.com/v1/devices/\(deviceId)"] = mockResponse
        
        // Act
        let device = try await adapter.getDeviceStatus(deviceId: deviceId)
        
        // Assert
        XCTAssertNotNil(device)
        XCTAssertEqual(device.id, deviceId)
        XCTAssertEqual(device.name, "Living Room Light")
        
        // Verify it's a light device with correct properties
        guard let lightDevice = device as? LightDevice else {
            XCTFail("Device should be a LightDevice")
            return
        }
        
        XCTAssertEqual(lightDevice.isOn, true)
        XCTAssertEqual(lightDevice.brightness, 80)
    }
    
    // MARK: - Command Execution Tests
    
    func testExecuteCommandOnLightDevice() async throws {
        // Arrange
        let deviceId = "light-123"
        let lightDevice = LightDevice(
            id: deviceId,
            name: "Bedroom Light",
            room: "bedroom",
            manufacturer: "SmartThings",
            model: "Smart Bulb",
            firmwareVersion: "1.0",
            isOnline: true,
            lastSeen: Date(),
            dateAdded: Date(),
            metadata: [:],
            brightness: 50,
            color: "#FFFFFF",
            isOn: false
        )
        
        let command = DeviceCommand(
            name: "turnOn",
            parameters: [:]
        )
        
        // Configure mock network service to succeed
        mockNetworkService.requestHandler = { request in
            guard let url = request.url, url.absoluteString.contains(deviceId) else {
                throw URLError(.badURL)
            }
            
            // Successful response
            return (Data(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        
        // Configure rate limiter to allow action
        mockRateLimiter.canPerformActionResult = true
        
        // Act
        let updatedDevice = try await adapter.executeCommand(command, on: lightDevice)
        
        // Assert
        guard let updatedLight = updatedDevice as? LightDevice else {
            XCTFail("Updated device should be a LightDevice")
            return
        }
        
        XCTAssertTrue(updatedLight.isOn)
        XCTAssertEqual(updatedLight.id, deviceId)
        
        // Verify audit log was created
        XCTAssertEqual(mockAuditLogger.loggedEvents.count, 1)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].category, .deviceControl)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].action, .executeCommand)
        
        // Verify rate limiter was called
        XCTAssertTrue(mockRateLimiter.recordActionCalled)
    }
    
    func testExecuteCommandOnLockDevice() async throws {
        // Arrange
        let deviceId = "lock-123"
        let lockDevice = LockDevice(
            id: deviceId,
            name: "Front Door",
            room: "entrance",
            manufacturer: "Yale",
            model: "Smart Lock",
            firmwareVersion: "1.0",
            isOnline: true,
            lastSeen: Date(),
            dateAdded: Date(),
            metadata: [:]
        )
        
        lockDevice.currentState = .unlocked
        
        let command = DeviceCommand(
            name: "lock",
            parameters: [:]
        )
        
        // Configure mock network service to succeed
        mockNetworkService.requestHandler = { request in
            guard let url = request.url, url.absoluteString.contains(deviceId) else {
                throw URLError(.badURL)
            }
            
            // Successful response
            return (Data(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        
        // Configure security service to return a user ID
        mockSecurityService.currentUserId = "user-123"
        
        // Configure rate limiter to allow action
        mockRateLimiter.canPerformActionResult = true
        
        // Act
        let updatedDevice = try await adapter.executeCommand(command, on: lockDevice)
        
        // Assert
        guard let updatedLock = updatedDevice as? LockDevice else {
            XCTFail("Updated device should be a LockDevice")
            return
        }
        
        XCTAssertEqual(updatedLock.currentState, .locked)
        XCTAssertEqual(updatedLock.id, deviceId)
        
        // Verify access history was updated
        XCTAssertEqual(updatedLock.accessHistory.count, 1)
        XCTAssertEqual(updatedLock.accessHistory[0].operation, .lock)
        XCTAssertEqual(updatedLock.accessHistory[0].userId, "user-123")
        XCTAssertTrue(updatedLock.accessHistory[0].success)
        
        // Verify audit log was created
        XCTAssertEqual(mockAuditLogger.loggedEvents.count, 1)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].category, .deviceControl)
    }
    
    func testExecuteCommandFailsWhenRateLimited() async {
        // Arrange
        let deviceId = "light-123"
        let lightDevice = LightDevice(
            id: deviceId,
            name: "Bedroom Light",
            room: "bedroom",
            manufacturer: "SmartThings",
            model: "Smart Bulb",
            firmwareVersion: "1.0",
            isOnline: true,
            lastSeen: Date(),
            dateAdded: Date(),
            metadata: [:],
            brightness: 50,
            color: "#FFFFFF",
            isOn: false
        )
        
        let command = DeviceCommand(
            name: "turnOn",
            parameters: [:]
        )
        
        // Configure rate limiter to deny action
        mockRateLimiter.canPerformActionResult = false
        
        // Act & Assert
        do {
            _ = try await adapter.executeCommand(command, on: lightDevice)
            XCTFail("Command should have failed due to rate limiting")
        } catch let error as DeviceOperationError {
            XCTAssertEqual(error, DeviceOperationError.rateLimitExceeded)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Verify audit logs
        XCTAssertEqual(mockAuditLogger.loggedEvents.count, 2)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].category, .deviceControl)
        XCTAssertEqual(mockAuditLogger.loggedEvents[1].category, .security)
        XCTAssertEqual(mockAuditLogger.loggedEvents[1].action, .rateLimitExceeded)
    }
    
    // MARK: - Webhook Tests
    
    func testSubscribeToWebhooks() async throws {
        // Arrange
        let url = "https://example.com/webhook"
        let events: [SmartThingsWebhookEvent] = [.deviceEvent, .deviceHealth]
        let deviceIds = ["device-123"]
        
        let mockResponse = SmartThingsWebhookSubscriptionResponse(
            webhookId: "webhook-123",
            url: url,
            events: events,
            deviceIds: deviceIds,
            status: "ACTIVE",
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        
        mockNetworkService.mockResponses["https://api.smartthings.com/v1/webhooks"] = mockResponse
        
        // Act
        let response = try await adapter.subscribeToWebhooks(url: url, events: events, deviceIds: deviceIds)
        
        // Assert
        XCTAssertEqual(response.webhookId, "webhook-123")
        XCTAssertEqual(response.url, url)
        XCTAssertEqual(response.events, events)
        XCTAssertEqual(response.deviceIds, deviceIds)
        XCTAssertEqual(response.status, "ACTIVE")
    }
    
    func testDeleteWebhook() async throws {
        // Arrange
        let webhookId = "webhook-123"
        
        // Configure mock network service to succeed
        mockNetworkService.requestHandler = { request in
            guard let url = request.url, url.absoluteString.contains(webhookId) else {
                throw URLError(.badURL)
            }
            
            // Successful response
            return (Data(), HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!)
        }
        
        // Act
        try await adapter.deleteWebhook(webhookId: webhookId)
        
        // Assert
        // No exception means success
    }
    
    func testListWebhooks() async throws {
        // Arrange
        let mockResponse = [
            SmartThingsWebhookSubscriptionResponse(
                webhookId: "webhook-123",
                url: "https://example.com/webhook1",
                events: [.deviceEvent],
                deviceIds: ["device-123"],
                status: "ACTIVE",
                createdAt: ISO8601DateFormatter().string(from: Date())
            ),
            SmartThingsWebhookSubscriptionResponse(
                webhookId: "webhook-456",
                url: "https://example.com/webhook2",
                events: [.deviceHealth],
                deviceIds: ["device-456"],
                status: "ACTIVE",
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
        ]
        
        mockNetworkService.mockResponses["https://api.smartthings.com/v1/webhooks"] = mockResponse
        
        // Act
        let response = try await adapter.listWebhooks()
        
        // Assert
        XCTAssertEqual(response.count, 2)
        XCTAssertEqual(response[0].webhookId, "webhook-123")
        XCTAssertEqual(response[1].webhookId, "webhook-456")
    }
    
    // MARK: - Group Management Tests
    
    func testCreateGroup() async throws {
        // Arrange
        let name = "Living Room Lights"
        let deviceIds = ["device-123", "device-456"]
        let roomId = "room-123"
        
        let mockResponse = SmartThingsGroupResponse(
            groupId: "group-123",
            name: name,
            deviceIds: deviceIds,
            roomId: roomId,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        mockNetworkService.mockResponses["https://api.smartthings.com/v1/groups"] = mockResponse
        
        // Act
        let response = try await adapter.createGroup(name: name, deviceIds: deviceIds, roomId: roomId)
        
        // Assert
        XCTAssertEqual(response.groupId, "group-123")
        XCTAssertEqual(response.name, name)
        XCTAssertEqual(response.deviceIds, deviceIds)
        XCTAssertEqual(response.roomId, roomId)
    }
    
    func testUpdateGroup() async throws {
        // Arrange
        let groupId = "group-123"
        let newName = "Updated Living Room Lights"
        let newDeviceIds = ["device-789"]
        
        let mockResponse = SmartThingsGroupResponse(
            groupId: groupId,
            name: newName,
            deviceIds: newDeviceIds,
            roomId: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        mockNetworkService.mockResponses["https://api.smartthings.com/v1/groups/\(groupId)"] = mockResponse
        
        // Act
        let response = try await adapter.updateGroup(
            groupId: groupId,
            name: newName,
            deviceIds: newDeviceIds
        )
        
        // Assert
        XCTAssertEqual(response.groupId, groupId)
        XCTAssertEqual(response.name, newName)
        XCTAssertEqual(response.deviceIds, newDeviceIds)
    }
    
    func testDeleteGroup() async throws {
        // Arrange
        let groupId = "group-123"
        
        // Configure mock network service to succeed
        mockNetworkService.requestHandler = { request in
            guard let url = request.url, url.absoluteString.contains(groupId) else {
                throw URLError(.badURL)
            }
            
            // Successful response
            return (Data(), HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!)
        }
        
        // Act
        try await adapter.deleteGroup(groupId: groupId)
        
        // Assert
        // No exception means success
    }
    
    func testListGroups() async throws {
        // Arrange
        let mockResponse = [
            SmartThingsGroupResponse(
                groupId: "group-123",
                name: "Living Room Lights",
                deviceIds: ["device-123", "device-456"],
                roomId: "room-123",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            ),
            SmartThingsGroupResponse(
                groupId: "group-456",
                name: "Bedroom Lights",
                deviceIds: ["device-789"],
                roomId: "room-456",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        ]
        
        mockNetworkService.mockResponses["https://api.smartthings.com/v1/groups"] = mockResponse
        
        // Act
        let response = try await adapter.listGroups()
        
        // Assert
        XCTAssertEqual(response.count, 2)
        XCTAssertEqual(response[0].groupId, "group-123")
        XCTAssertEqual(response[1].groupId, "group-456")
    }
    
    func testExecuteGroupCommand() async throws {
        // Arrange
        let groupId = "group-123"
        let command = SmartThingsGroupCommandRequest(
            commands: [
                SmartThingsGroupCommandRequest.SmartThingsGroupCommand(
                    component: "main",
                    capability: "switch",
                    command: "on",
                    arguments: nil
                )
            ]
        )
        
        // Configure mock network service to succeed
        mockNetworkService.requestHandler = { request in
            guard let url = request.url, url.absoluteString.contains(groupId) else {
                throw URLError(.badURL)
            }
            
            // Successful response
            return (Data(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        
        // Act
        try await adapter.executeGroupCommand(groupId: groupId, command: command)
        
        // Assert
        // No exception means success
    }
    
    // MARK: - Scene Management Tests
    
    func testCreateScene() async throws {
        // Arrange
        let name = "Evening Mode"
        let actions = [
            SmartThingsSceneAction(
                deviceId: "device-123",
                component: "main",
                capability: "switch",
                command: "on",
                arguments: nil
            ),
            SmartThingsSceneAction(
                deviceId: "device-456",
                component: "main",
                capability: "switchLevel",
                command: "setLevel",
                arguments: ["level": AnyCodable(80)]
            )
        ]
        let roomId = "room-123"
        
        let mockResponse = SmartThingsSceneResponse(
            sceneId: "scene-123",
            name: name,
            actions: actions,
            roomId: roomId,
            status: "ACTIVE",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        mockNetworkService.mockResponses["https://api.smartthings.com/v1/scenes"] = mockResponse
        
        // Act
        let response = try await adapter.createScene(name: name, actions: actions, roomId: roomId)
        
        // Assert
        XCTAssertEqual(response.sceneId, "scene-123")
        XCTAssertEqual(response.name, name)
        XCTAssertEqual(response.actions.count, 2)
        XCTAssertEqual(response.roomId, roomId)
        XCTAssertEqual(response.status, "ACTIVE")
    }
    
    func testUpdateScene() async throws {
        // Arrange
        let sceneId = "scene-123"
        let newName = "Updated Evening Mode"
        let newActions = [
            SmartThingsSceneAction(
                deviceId: "device-789",
                component: "main",
                capability: "switch",
                command: "on",
                arguments: nil
            )
        ]
        
        let mockResponse = SmartThingsSceneResponse(
            sceneId: sceneId,
            name: newName,
            actions: newActions,
            roomId: nil,
            status: "ACTIVE",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        mockNetworkService.mockResponses["https://api.smartthings.com/v1/scenes/\(sceneId)"] = mockResponse
        
        // Act
        let response = try await adapter.updateScene(
            sceneId: sceneId,
            name: newName,
            actions: newActions
        )
        
        // Assert
        XCTAssertEqual(response.sceneId, sceneId)
        XCTAssertEqual(response.name, newName)
        XCTAssertEqual(response.actions.count, 1)
        XCTAssertEqual(response.actions[0].deviceId, "device-789")
    }
    
    func testDeleteScene() async throws {
        // Arrange
        let sceneId = "scene-123"
        
        // Configure mock network service to succeed
        mockNetworkService.requestHandler = { request in
            guard let url = request.url, url.absoluteString.contains(sceneId) else {
                throw URLError(.badURL)
            }
            
            // Successful response
            return (Data(), HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!)
        }
        
        // Act
        try await adapter.deleteScene(sceneId: sceneId)
        
        // Assert
        // No exception means success
    }
    
    func testListScenes() async throws {
        // Arrange
        let mockResponse = [
            SmartThingsSceneResponse(
                sceneId: "scene-123",
                name: "Evening Mode",
                actions: [],
                roomId: "room-123",
                status: "ACTIVE",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            ),
            SmartThingsSceneResponse(
                sceneId: "scene-456",
                name: "Morning Mode",
                actions: [],
                roomId: "room-456",
                status: "ACTIVE",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        ]
        
        mockNetworkService.mockResponses["https://api.smartthings.com/v1/scenes"] = mockResponse
        
        // Act
        let response = try await adapter.listScenes()
        
        // Assert
        XCTAssertEqual(response.count, 2)
        XCTAssertEqual(response[0].sceneId, "scene-123")
        XCTAssertEqual(response[1].sceneId, "scene-456")
    }
    
    func testExecuteScene() async throws {
        // Arrange
        let sceneId = "scene-123"
        
        let mockResponse = SmartThingsSceneExecutionResponse(
            status: "SUCCESS",
            message: "Scene executed successfully",
            executionId: "execution-123"
        )
        
        mockNetworkService.mockResponses["https://api.smartthings.com/v1/scenes/\(sceneId)/execute"] = mockResponse
        
        // Act
        let response = try await adapter.executeScene(sceneId: sceneId)
        
        // Assert
        XCTAssertEqual(response.status, "SUCCESS")
        XCTAssertEqual(response.message, "Scene executed successfully")
        XCTAssertEqual(response.executionId, "execution-123")
    }
}

// MARK: - Mock Classes

class MockNetworkService: NetworkServiceProtocol {
    var mockResponses: [String: Codable] = [:]
    var requestHandler: ((URLRequest) throws -> (Data, URLResponse))? = nil
    
    func request<T: Decodable>(endpoint: String, method: HTTPMethod, body: Encodable?) async throws -> T {
        if let url = URL(string: endpoint), let mockResponse = mockResponses[endpoint] as? T {
            return mockResponse
        }
        
        throw URLError(.badURL)
    }
    
    func authenticatedRequest<T: Decodable>(endpoint: String, token: String, method: HTTPMethod, body: Encodable?) async throws -> T {
        if let url = URL(string: endpoint), let mockResponse = mockResponses[endpoint] as? T {
            return mockResponse
        }
        
        throw URLError(.badURL)
    }
    
    func rawRequest(request: URLRequest) async throws -> (Data, URLResponse) {
        if let handler = requestHandler {
            return try handler(request)
        }
        
        throw URLError(.badURL)
    }
}

class MockSecurityService: SecurityServiceProtocol {
    var isJailbrokenResult = false
    var biometricAuthSucceeds = true
    var currentUserId: String? = nil
    
    func isDeviceJailbroken() -> Bool {
        return isJailbrokenResult
    }
    
    func verifyBiometricAuthentication(reason: String) async throws {
        if !biometricAuthSucceeds {
            throw SecurityError.biometricAuthFailed
        }
    }
    
    func getCurrentUserId() -> String? {
        return currentUserId
    }
    
    func validateUserPermissions(for deviceId: String) throws -> Bool {
        return true
    }
}

class MockAuditLogger: AuditLoggerProtocol {
    struct LoggedEvent {
        var category: EventCategory
        var action: EventAction
        var metadata: [String: String]
    }
    
    var loggedEvents: [LoggedEvent] = []
    
    func logEvent(category: EventCategory, action: EventAction, metadata: [String: String]) {
        loggedEvents.append(LoggedEvent(category: category, action: action, metadata: metadata))
    }
}

class MockRateLimiter: RateLimiterProtocol {
    var canPerformActionResult = true
    var recordActionCalled = false
    
    func canPerformAction(for identifier: String) -> Bool {
        return canPerformActionResult
    }
    
    func recordAction(for identifier: String) {
        recordActionCalled = true
    }
} 