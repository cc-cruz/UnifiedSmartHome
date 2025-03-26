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
    private let retryHandler: SmartThingsRetryHandler
    
    // MARK: - Initializer
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = Session(configuration: configuration)
        self.retryHandler = SmartThingsRetryHandler()
    }
    
    // MARK: - SmartDeviceAdapter Protocol Methods
    
    func initializeConnection(authToken: String) throws {
        self.authToken = authToken
    }
    
    func fetchDevices() async throws -> [AbstractDevice] {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        let response = try await retryHandler.executeRequest(
            URLRequest(url: URL(string: "\(baseURL)/devices")!, headers: headers),
            session: session
        ) { error in
            // Log error for monitoring
            print("Error fetching devices: \(error.localizedDescription)")
        }
        
        let devicesResponse = try JSONDecoder().decode(SmartThingsDevicesResponse.self, from: response)
        
        return devicesResponse.items.map { device in
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
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        // Convert DeviceState to SmartThings command format
        let command = convertToSmartThingsCommand(newState)
        
        var request = URLRequest(url: URL(string: "\(baseURL)/devices/\(deviceId)/commands")!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers.dictionary
        request.httpBody = command
        
        _ = try await retryHandler.executeRequest(request, session: session) { error in
            // Log error for monitoring
            print("Error updating device state: \(error.localizedDescription)")
        }
        
        return newState
    }
    
    // MARK: - Webhook Management
    
    func subscribeToWebhooks(url: String, events: [SmartThingsWebhookEvent], deviceIds: [String]? = nil) async throws -> SmartThingsWebhookSubscriptionResponse {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
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
        
        var request = URLRequest(url: URL(string: "\(baseURL)/webhooks")!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers.dictionary
        request.httpBody = try JSONEncoder().encode(subscription)
        
        let response = try await retryHandler.executeRequest(request, session: session) { error in
            // Log error for monitoring
            print("Error subscribing to webhooks: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode(SmartThingsWebhookSubscriptionResponse.self, from: response)
    }
    
    func deleteWebhook(webhookId: String) async throws {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/webhooks/\(webhookId)")!)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = headers.dictionary
        
        _ = try await retryHandler.executeRequest(request, session: session) { error in
            // Log error for monitoring
            print("Error deleting webhook: \(error.localizedDescription)")
        }
    }
    
    func listWebhooks() async throws -> [SmartThingsWebhookSubscriptionResponse] {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/webhooks")!)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers.dictionary
        
        let response = try await retryHandler.executeRequest(request, session: session) { error in
            // Log error for monitoring
            print("Error listing webhooks: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode([SmartThingsWebhookSubscriptionResponse].self, from: response)
    }
    
    // MARK: - Group Management
    
    func createGroup(name: String, deviceIds: [String], roomId: String? = nil) async throws -> SmartThingsGroupResponse {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
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
        
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/groups")!)
        urlRequest.httpMethod = "POST"
        urlRequest.allHTTPHeaderFields = headers.dictionary
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let response = try await retryHandler.executeRequest(urlRequest, session: session) { error in
            // Log error for monitoring
            print("Error creating group: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode(SmartThingsGroupResponse.self, from: response)
    }
    
    func updateGroup(groupId: String, name: String? = nil, deviceIds: [String]? = nil, roomId: String? = nil) async throws -> SmartThingsGroupResponse {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request: [String: Any] = [:]
        if let name = name { request["name"] = name }
        if let deviceIds = deviceIds { request["deviceIds"] = deviceIds }
        if let roomId = roomId { request["roomId"] = roomId }
        
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/groups/\(groupId)")!)
        urlRequest.httpMethod = "PUT"
        urlRequest.allHTTPHeaderFields = headers.dictionary
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: request)
        
        let response = try await retryHandler.executeRequest(urlRequest, session: session) { error in
            // Log error for monitoring
            print("Error updating group: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode(SmartThingsGroupResponse.self, from: response)
    }
    
    func deleteGroup(groupId: String) async throws {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/groups/\(groupId)")!)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = headers.dictionary
        
        _ = try await retryHandler.executeRequest(request, session: session) { error in
            // Log error for monitoring
            print("Error deleting group: \(error.localizedDescription)")
        }
    }
    
    func listGroups() async throws -> [SmartThingsGroupResponse] {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/groups")!)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers.dictionary
        
        let response = try await retryHandler.executeRequest(request, session: session) { error in
            // Log error for monitoring
            print("Error listing groups: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode([SmartThingsGroupResponse].self, from: response)
    }
    
    func executeGroupCommand(groupId: String, command: SmartThingsGroupCommandRequest) async throws {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/groups/\(groupId)/commands")!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers.dictionary
        request.httpBody = try JSONEncoder().encode(command)
        
        _ = try await retryHandler.executeRequest(request, session: session) { error in
            // Log error for monitoring
            print("Error executing group command: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Scene Management
    
    func createScene(name: String, actions: [SmartThingsSceneAction], roomId: String? = nil) async throws -> SmartThingsSceneResponse {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        let request = SmartThingsSceneRequest(
            name: name,
            actions: actions,
            roomId: roomId
        )
        
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/scenes")!)
        urlRequest.httpMethod = "POST"
        urlRequest.allHTTPHeaderFields = headers.dictionary
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let response = try await retryHandler.executeRequest(urlRequest, session: session) { error in
            // Log error for monitoring
            print("Error creating scene: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode(SmartThingsSceneResponse.self, from: response)
    }
    
    func updateScene(sceneId: String, name: String? = nil, actions: [SmartThingsSceneAction]? = nil, roomId: String? = nil) async throws -> SmartThingsSceneResponse {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request: [String: Any] = [:]
        if let name = name { request["name"] = name }
        if let actions = actions { request["actions"] = actions }
        if let roomId = roomId { request["roomId"] = roomId }
        
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/scenes/\(sceneId)")!)
        urlRequest.httpMethod = "PUT"
        urlRequest.allHTTPHeaderFields = headers.dictionary
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: request)
        
        let response = try await retryHandler.executeRequest(urlRequest, session: session) { error in
            // Log error for monitoring
            print("Error updating scene: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode(SmartThingsSceneResponse.self, from: response)
    }
    
    func deleteScene(sceneId: String) async throws {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/scenes/\(sceneId)")!)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = headers.dictionary
        
        _ = try await retryHandler.executeRequest(request, session: session) { error in
            // Log error for monitoring
            print("Error deleting scene: \(error.localizedDescription)")
        }
    }
    
    func listScenes() async throws -> [SmartThingsSceneResponse] {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/scenes")!)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers.dictionary
        
        let response = try await retryHandler.executeRequest(request, session: session) { error in
            // Log error for monitoring
            print("Error listing scenes: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode([SmartThingsSceneResponse].self, from: response)
    }
    
    func executeScene(sceneId: String) async throws -> SmartThingsSceneExecutionResponse {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/scenes/\(sceneId)/execute")!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers.dictionary
        
        let response = try await retryHandler.executeRequest(request, session: session) { error in
            // Log error for monitoring
            print("Error executing scene: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode(SmartThingsSceneExecutionResponse.self, from: response)
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