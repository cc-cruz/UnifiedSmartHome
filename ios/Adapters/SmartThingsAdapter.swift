import Foundation
import Combine
import Alamofire
import Models

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
public class SmartThingsAdapter: SmartDeviceAdapter {
    
    // MARK: - Properties
    
    private var authToken: String?
    private let baseURL = "https://api.smartthings.com/v1"
    private let urlSession: URLSession
    private let retryHandler: SmartThingsRetryHandler
    private let logger = SmartThingsLogger.shared
    private let metrics = SmartThingsMetrics.shared
    private let errorRecovery = SmartThingsErrorRecovery.shared
    
    // MARK: - Initializer
    
    /// Default public initializer. Uses an internal URLSession without external dependencies.
    public init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: configuration)
        self.retryHandler = SmartThingsRetryHandler()
    }
    
    /// Convenience initializer so existing call-sites that pass a `NetworkServiceProtocol` and
    /// `SmartThingsTokenManager` continue to compile.  At the moment those parameters are not
    /// used directly because the adapter operates with its own `Alamofire.Session`, but keeping
    /// them in the signature preserves API compatibility and allows future refactor.
    public convenience init(networkService: NetworkServiceProtocol, tokenManager: SmartThingsTokenManager) {
        self.init()
        // Future: wire `networkService` / `tokenManager` into internal request pipeline.
    }
    
    // MARK: - SmartDeviceAdapter Protocol Methods
    
    public func initialize(with authToken: String) throws {
        self.authToken = authToken
    }
    
    public func refreshAuthentication() async throws -> Bool {
        // TODO: Implement actual token refresh logic for SmartThings
        // metrics.authenticationRefreshesAttempted += 1 // OLD WAY
        metrics.incrementCounter(named: "authenticationRefreshesAttempted") // NEW WAY

        logger.logInfo("refreshAuthentication called, not implemented for SmartThingsPAT", context: [:])
        
        // Simulate failure for now, or a specific condition
        let success = false // Or some logic to determine success
        if success {
            // metrics.authenticationRefreshesSucceeded += 1 // OLD WAY
            metrics.incrementCounter(named: "authenticationRefreshesSucceeded") // NEW WAY
        } else {
            // metrics.authenticationRefreshesFailed += 1 // OLD WAY
            metrics.incrementCounter(named: "authenticationRefreshesFailed") // NEW WAY
        }
        return success
    }
    
    public func fetchDevices() async throws -> [AbstractDevice] {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        let url = URL(string: "\(baseURL)/devices")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers.dictionary
        
        let responseData = try await retryHandler.executeRequest(request, session: urlSession) { error in
            self.logger.logError(error, context: ["operation": "fetchDevices"])
        }
        
        let devicesResponse = try JSONDecoder().decode(SmartThingsDevicesResponse.self, from: responseData)
        
        // Map each SmartThingsDevice into the appropriate concrete AbstractDevice subclass.
        // The convenience initialisers are failable; compactMap drops any that cannot be parsed.
        let devices: [AbstractDevice] = devicesResponse.items.compactMap { device in
            // Prefer explicit device type name if available, otherwise fall back to capabilities heuristics.
            let lowercasedType = (device.deviceTypeName ?? device.type).lowercased()
            switch lowercasedType {
            case let t where t.contains("lock"):
                return LockDevice(fromDevice: device)
            case let t where t.contains("thermostat"):
                return ThermostatDevice(fromDevice: device)
            case let t where t.contains("light"):
                return LightDevice(fromDevice: device)
            case let t where t.contains("switch"):
                return SwitchDevice(fromDevice: device)
            default:
                return GenericDevice(fromDevice: device)
            }
        }
        
        return devices
    }
    
    public func getDeviceState(deviceId: String) async throws -> AbstractDevice {
        guard let token = authToken else {
            throw SmartThingsError.unauthorized
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        guard let url = URL(string: "\(baseURL)/devices/\(deviceId)/status") else {
            throw SmartThingsError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers.dictionary
        
        let startTime = Date()
        
        do {
            let responseData = try await retryHandler.executeRequest(request, session: urlSession) { error in
                self.logger.logError(error, context: ["deviceId": deviceId, "operation": "getDeviceState"])
            }
            
            let latency = Date().timeIntervalSince(startTime)
            metrics.recordOperationLatency("getDeviceState", latency: latency)
            
            // At the moment we don't perform deep parsing of SmartThingsDeviceStatusResponse.
            // Return a GenericDevice with minimal details so the call site compiles.
            _ = try JSONDecoder().decode(SmartThingsDeviceStatusResponse.self, from: responseData)
            
            return GenericDevice(
                id: deviceId,
                name: "SmartThings Device \(deviceId)",
                room: "Unknown",
                manufacturer: "Unknown",
                model: "Unknown",
                firmwareVersion: "Unknown",
                capabilities: [],
                attributes: [:]
            )
        } catch {
            logger.logDeviceOperation(
                deviceId: deviceId,
                operation: "getDeviceState",
                status: "failed",
                context: ["error": error.localizedDescription]
            )
            throw error
        }
    }
    
    public func executeCommand(deviceId: String, command: DeviceCommand) async throws -> AbstractDevice {
        guard let token = authToken else {
            // metrics.authenticationErrors += 1 // OLD WAY - Assuming this was intended for a generic auth error counter
            metrics.incrementCounter(named: "authenticationErrors") // NEW WAY
            throw SmartThingsError.unauthorized
        }
        
        // metrics.commandExecutionsAttempted += 1 // OLD WAY
        metrics.incrementCounter(named: "commandExecutionsAttempted") // NEW WAY
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        // TODO: Convert DeviceCommand to SmartThings specific command payload
        // This replaces convertToSmartThingsCommand which took DeviceState.
        // The logic here will depend on the structure of DeviceCommand enum
        // and how it maps to SmartThings capabilities and commands.
        let smartThingsPayload: Data
        do {
            smartThingsPayload = try convertDeviceCommandToSmartThingsPayload(command)
        } catch {
            logger.logError(error, context: ["deviceId": deviceId, "operation": "executeCommand", "command": String(describing: command)])
            // Consider throwing a specific SmartThingsError.invalidCommand or similar
            throw error // Or a more specific error like SmartThingsError.commandNotSupported(String(describing: command))
        }
        
        guard let url = URL(string: "\(baseURL)/devices/\(deviceId)/commands") else {
            throw SmartThingsError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers.dictionary
        request.httpBody = smartThingsPayload
        
        do {
            _ = try await retryHandler.executeRequest(request, session: urlSession) { error in
                logger.logError(error, context: ["deviceId": deviceId, "operation": "executeCommand", "command": String(describing: command)])
                
                // Attempt recovery for device-specific errors
                // This error recovery logic might need adjustment if error types change.
                if let smartThingsError = error as? SmartThingsError {
                    Task {
                        // Assuming errorRecovery.attemptRecovery needs the new DeviceCommand or a way to infer deviceType
                        // For now, passing a placeholder or removing this block if newState is not available.
                        // let recovered = await errorRecovery.attemptRecovery(
                        //     for: smartThingsError,
                        //     deviceId: deviceId,
                        //     deviceType: <#DeviceType from command or fetched#>, // This is now harder to get
                        //     context: ["command": command]
                        // )
                        // if recovered { logger.logInfo("Device recovered successfully", context: ["deviceId": deviceId]) }
                        // else { logger.logWarning("Device recovery failed", context: ["deviceId": deviceId]) }
                        logger.logWarning("Error recovery in executeCommand needs review due to DeviceCommand change", context: ["deviceId": deviceId])
                    }
                }
            }
            
            // metrics.commandExecutionsSucceeded += 1 // OLD WAY
            metrics.incrementCounter(named: "commandExecutionsSucceeded") // NEW WAY
            
            logger.logDeviceOperation(
                deviceId: deviceId,
                operation: "executeCommand",
                status: "success",
                context: ["command": String(describing: command)]
            )
            
            // After command execution, fetch and return the updated device state as AbstractDevice
            return try await getDeviceState(deviceId: deviceId)
        } catch {
            // metrics.commandExecutionsFailed += 1 // OLD WAY
            metrics.incrementCounter(named: "commandExecutionsFailed") // NEW WAY
            logger.logDeviceOperation(
                deviceId: deviceId,
                operation: "executeCommand",
                status: "failed",
                context: ["command": String(describing: command), "error": error.localizedDescription]
            )
            throw error
        }
    }
    
    public func revokeAuthentication() async throws {
        // TODO: Implement actual token revocation logic for SmartThings
        // This might involve clearing the stored authToken and any other relevant session data.
        // If SmartThings uses PATs, revocation might not be client-side, but good to clear local token.
        
        // metrics.authenticationRevocationsAttempted += 1 // OLD WAY
        metrics.incrementCounter(named: "authenticationRevocationsAttempted") // NEW WAY
        
        self.authToken = nil
        logger.logInfo("revokeAuthentication called for SmartThings", context: [:])
        
        // metrics.authenticationRevocationsSucceeded += 1 // OLD WAY - Assuming immediate success for local clear
        metrics.incrementCounter(named: "authenticationRevocationsSucceeded") // NEW WAY
        // Depending on PAT, a server-side call might be needed to invalidate the token if possible.
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
        
        let response = try await retryHandler.executeRequest(request, session: urlSession) { error in
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
        
        _ = try await retryHandler.executeRequest(request, session: urlSession) { error in
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
        
        let response = try await retryHandler.executeRequest(request, session: urlSession) { error in
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
        
        let response = try await retryHandler.executeRequest(urlRequest, session: urlSession) { error in
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
        
        let response = try await retryHandler.executeRequest(urlRequest, session: urlSession) { error in
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
        
        _ = try await retryHandler.executeRequest(request, session: urlSession) { error in
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
        
        let response = try await retryHandler.executeRequest(request, session: urlSession) { error in
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
        
        _ = try await retryHandler.executeRequest(request, session: urlSession) { error in
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
        
        let response = try await retryHandler.executeRequest(urlRequest, session: urlSession) { error in
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
        
        let response = try await retryHandler.executeRequest(urlRequest, session: urlSession) { error in
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
        
        _ = try await retryHandler.executeRequest(request, session: urlSession) { error in
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
        
        let response = try await retryHandler.executeRequest(request, session: urlSession) { error in
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
        
        let startTime = Date()
        
        do {
            let response = try await retryHandler.executeRequest(request, session: urlSession) { error in
                logger.logError(error, context: ["sceneId": sceneId, "operation": "executeScene"])
            }
            
            let latency = Date().timeIntervalSince(startTime)
            metrics.recordOperationLatency("executeScene", latency: latency)
            
            logger.logSceneOperation(
                sceneId: sceneId,
                operation: "execute",
                status: "success",
                context: ["latency": latency]
            )
            
            return try JSONDecoder().decode(SmartThingsSceneExecutionResponse.self, from: response)
        } catch {
            logger.logSceneOperation(
                sceneId: sceneId,
                operation: "execute",
                status: "failed",
                context: ["error": error.localizedDescription]
            )
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func convertDeviceCommandToSmartThingsPayload(_ command: DeviceCommand) throws -> Data {
        // TODO: Implement the conversion from DeviceCommand to the SmartThings JSON command format.
        // This will involve a switch on the 'command' parameter and constructing the appropriate
        // JSON structure based on the command type and its associated values.
        //
        // Example (very basic, needs full implementation based on DeviceCommand cases):
        // switch command {
        // case .turnOn:
        //     let payload = ["commands": [["component": "main", "capability": "switch", "command": "on"]]]
        //     return try JSONSerialization.data(withJSONObject: payload)
        // case .turnOff:
        //     let payload = ["commands": [["component": "main", "capability": "switch", "command": "off"]]]
        //     return try JSONSerialization.data(withJSONObject: payload)
        // case .setBrightness(let level):
        //     let payload = ["commands": [["component": "main", "capability": "switchLevel", "command": "setLevel", "arguments": [level]]]]
        //     return try JSONSerialization.data(withJSONObject: payload)
        // default:
        //     throw SmartThingsError.commandNotSupported("Conversion for \\(command) not implemented")
        // }
        logger.logWarning("convertDeviceCommandToSmartThingsPayload needs full implementation.", context: ["command": String(describing: command)])
        // Placeholder: return empty JSON object to allow compilation
        return try JSONSerialization.data(withJSONObject: [:])
    }
} 