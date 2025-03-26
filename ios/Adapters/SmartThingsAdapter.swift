import Foundation
import Combine
import Alamofire

/// Configuration for SmartThings API
struct SmartThingsConfiguration {
    static let shared = SmartThingsConfiguration()
    
    let apiKey: String
    let baseURL: String
    
    private init() {
        // Load from environment variables or secure configuration
        self.apiKey = ProcessInfo.processInfo.environment["SMARTTHINGS_API_KEY"] ?? ""
        self.baseURL = ProcessInfo.processInfo.environment["SMARTTHINGS_BASE_URL"] ?? "https://api.smartthings.com/v1"
        
        guard !apiKey.isEmpty else {
            fatalError("SmartThings configuration is incomplete. Please set the required environment variables.")
        }
    }
}

/// A concrete implementation of the `SmartDeviceAdapter` protocol for Samsung SmartThings devices.
class SmartThingsAdapter: SmartDeviceAdapter {
    
    // MARK: - Properties
    
    private var authToken: String?
    private let baseURL = "https://api.smartthings.com/v1"
    private let session: Session
    
    // MARK: - Initializer
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = Session(configuration: configuration)
    }
    
    // MARK: - SmartDeviceAdapter Protocol Methods
    
    func initializeConnection(authToken: String) throws {
        self.authToken = authToken
    }
    
    func fetchDevices() async throws -> [AbstractDevice] {
        guard let token = authToken else {
            throw DeviceOperationError.authenticationFailed
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        let response = try await session.request("\(baseURL)/devices", headers: headers)
            .serializingDecodable(SmartThingsDevicesResponse.self)
            .value
        
        return response.items.map { device in
            // Convert SmartThings device to AbstractDevice
            switch device.type {
            case "lock":
                return LockDevice(
                    id: device.deviceId,
                    name: device.name,
                    state: device.state,
                    capabilities: device.capabilities
                )
            case "thermostat":
                return ThermostatDevice(
                    id: device.deviceId,
                    name: device.name,
                    state: device.state,
                    capabilities: device.capabilities
                )
            case "light":
                return LightDevice(
                    id: device.deviceId,
                    name: device.name,
                    state: device.state,
                    capabilities: device.capabilities
                )
            case "switch":
                return SwitchDevice(
                    id: device.deviceId,
                    name: device.name,
                    state: device.state,
                    capabilities: device.capabilities
                )
            default:
                return GenericDevice(
                    id: device.deviceId,
                    name: device.name,
                    state: device.state,
                    capabilities: device.capabilities
                )
            }
        }
    }
    
    func updateDeviceState(deviceId: String, newState: DeviceState) async throws -> DeviceState {
        guard let token = authToken else {
            throw DeviceOperationError.authenticationFailed
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        // Convert DeviceState to SmartThings command format
        let command = convertToSmartThingsCommand(newState)
        
        let response = try await session.request(
            "\(baseURL)/devices/\(deviceId)/commands",
            method: .post,
            headers: headers,
            body: command
        ).serializingDecodable(SmartThingsCommandResponse.self).value
        
        return newState // For MVP, we'll assume success if no error is thrown
    }
    
    // MARK: - Webhook Management
    
    func subscribeToWebhooks(url: String, events: [SmartThingsWebhookEvent], deviceIds: [String]? = nil) async throws -> SmartThingsWebhookSubscriptionResponse {
        guard let token = authToken else {
            throw DeviceOperationError.authenticationFailed
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        let subscription = SmartThingsWebhookSubscription(
            webhookId: UUID().uuidString,
            url: url,
            events: events,
            deviceIds: deviceIds
        )
        
        let response = try await session.request(
            "\(baseURL)/webhooks",
            method: .post,
            headers: headers,
            body: try JSONEncoder().encode(subscription)
        ).serializingDecodable(SmartThingsWebhookSubscriptionResponse.self).value
        
        return response
    }
    
    func deleteWebhook(webhookId: String) async throws {
        guard let token = authToken else {
            throw DeviceOperationError.authenticationFailed
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        _ = try await session.request(
            "\(baseURL)/webhooks/\(webhookId)",
            method: .delete,
            headers: headers
        ).serializingDecodable(EmptyResponse.self).value
    }
    
    func listWebhooks() async throws -> [SmartThingsWebhookSubscriptionResponse] {
        guard let token = authToken else {
            throw DeviceOperationError.authenticationFailed
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        let response = try await session.request(
            "\(baseURL)/webhooks",
            method: .get,
            headers: headers
        ).serializingDecodable([SmartThingsWebhookSubscriptionResponse].self).value
        
        return response
    }
    
    // MARK: - Group Management
    
    func createGroup(name: String, deviceIds: [String], roomId: String? = nil) async throws -> SmartThingsGroupResponse {
        guard let token = authToken else {
            throw DeviceOperationError.authenticationFailed
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        let request = SmartThingsGroupRequest(
            name: name,
            deviceIds: deviceIds,
            roomId: roomId
        )
        
        let response = try await session.request(
            "\(baseURL)/groups",
            method: .post,
            headers: headers,
            body: try JSONEncoder().encode(request)
        ).serializingDecodable(SmartThingsGroupResponse.self).value
        
        return response
    }
    
    func updateGroup(groupId: String, name: String? = nil, deviceIds: [String]? = nil, roomId: String? = nil) async throws -> SmartThingsGroupResponse {
        guard let token = authToken else {
            throw DeviceOperationError.authenticationFailed
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request: [String: Any] = [:]
        if let name = name { request["name"] = name }
        if let deviceIds = deviceIds { request["deviceIds"] = deviceIds }
        if let roomId = roomId { request["roomId"] = roomId }
        
        let response = try await session.request(
            "\(baseURL)/groups/\(groupId)",
            method: .put,
            headers: headers,
            body: try JSONSerialization.data(withJSONObject: request)
        ).serializingDecodable(SmartThingsGroupResponse.self).value
        
        return response
    }
    
    func deleteGroup(groupId: String) async throws {
        guard let token = authToken else {
            throw DeviceOperationError.authenticationFailed
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        _ = try await session.request(
            "\(baseURL)/groups/\(groupId)",
            method: .delete,
            headers: headers
        ).serializingDecodable(EmptyResponse.self).value
    }
    
    func listGroups() async throws -> [SmartThingsGroupResponse] {
        guard let token = authToken else {
            throw DeviceOperationError.authenticationFailed
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        let response = try await session.request(
            "\(baseURL)/groups",
            method: .get,
            headers: headers
        ).serializingDecodable([SmartThingsGroupResponse].self).value
        
        return response
    }
    
    func executeGroupCommand(groupId: String, command: SmartThingsGroupCommandRequest) async throws {
        guard let token = authToken else {
            throw DeviceOperationError.authenticationFailed
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        _ = try await session.request(
            "\(baseURL)/groups/\(groupId)/commands",
            method: .post,
            headers: headers,
            body: try JSONEncoder().encode(command)
        ).serializingDecodable(EmptyResponse.self).value
    }
    
    // MARK: - Private Methods
    
    private func convertToSmartThingsCommand(_ state: DeviceState) -> Data {
        // Convert DeviceState to SmartThings command format
        // This is a simplified version for MVP
        let command: [String: Any] = [
            "commands": [
                [
                    "component": "main",
                    "capability": state.deviceType.rawValue,
                    "command": state.attributes["command"] as? String ?? "on"
                ]
            ]
        ]
        
        return try! JSONSerialization.data(withJSONObject: command)
    }
} 