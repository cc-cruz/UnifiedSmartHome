import Foundation
import Combine
import Alamofire
import Models
import Helpers

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
    
    private let baseURL = "https://api.smartthings.com/v1"
    private let session: Session
    private let retryHandler: SmartThingsRetryHandler
    private let logger = SmartThingsLogger.shared
    private let metrics = SmartThingsMetrics.shared
    private let errorRecovery = SmartThingsErrorRecovery.shared
    private let tokenManager: SmartThingsTokenManager
    
    // MARK: - Initializer
    
    init(tokenManager: SmartThingsTokenManager) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = Session(configuration: configuration)
        self.retryHandler = SmartThingsRetryHandler()
        self.tokenManager = tokenManager
    }
    
    // MARK: - SmartDeviceAdapter Protocol Methods
    
    public func refreshAuthentication() async -> Bool {
        logger.debug("Attempting to refresh SmartThings authentication.")
        metrics.incrementCounter(forName: .authenticationRefreshesAttempted)
        do {
            // getValidToken internally checks expiry and refreshes if needed.
            _ = try await tokenManager.getValidToken() 
            logger.info("SmartThings authentication successfully refreshed (or was already valid).")
            metrics.incrementCounter(forName: .authenticationRefreshesSucceeded)
            return true
        } catch {
            logger.error("Failed to refresh SmartThings authentication: \(error.localizedDescription)", error: error)
            metrics.incrementCounter(forName: .authenticationRefreshesFailed)
            errorRecovery.handleError(error, context: "Refreshing SmartThings token")
            return false
        }
    }
    
    // Helper function to map SmartThings device to internal LockDevice model
    private func mapSmartThingsDeviceToLockDevice(_ device: SmartThingsDevice) -> LockDevice? {
        // Basic mapping - Extract lock-specific details if possible
        // This needs refinement based on how lock state/info is stored in SmartThingsDevice.state
        
        // Check if it has lock capabilities
        guard device.capabilities.contains("lock") else {
            return nil // Not a lock device
        }

        // Extract state information (Placeholders - adjust based on actual state structure)
        let lockStateString = device.state["lock"]?.value as? String ?? "unknown"
        let batteryLevelString = device.state["battery"]?.value as? String // Example
        let batteryLevel = Int(batteryLevelString ?? "-1") ?? -1 // Example parsing

        let lockState: LockDevice.LockState
        switch lockStateString.lowercased() {
            case "locked": lockState = .locked
            case "unlocked": lockState = .unlocked
            default: lockState = .unknown
        }

        return LockDevice(
            id: device.deviceId,
            name: device.name, // Use available 'name'
            room: "Unknown", // SmartThingsDevice doesn't provide room here
            manufacturer: "SmartThings", // Default or extract if possible from other fields/context
            model: device.type, // Use 'type' as a placeholder for model
            firmwareVersion: "N/A", // Not available directly
            isOnline: true, // Assume online if fetched, ST status not directly on device struct
            currentState: lockState, // Use extracted state
            batteryLevel: batteryLevel >= 0 ? batteryLevel : 50, // Use extracted battery or default
            lastStateChange: nil, // Not directly available
            isRemoteOperationEnabled: true // Assume true, adjust if controllable via capabilities/state
        )
    }

    public func fetchDevices() async throws -> [AbstractDevice] {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        let response = try await retryHandler.executeRequest(
            URLRequest(url: URL(string: "\(baseURL)/devices")!, method: .get, headers: headers),
            session: session.session) { error in
            // Log error for monitoring
            print("Error fetching devices: \(error.localizedDescription)")
        }
        
        let devicesResponse = try JSONDecoder().decode(SmartThingsDevicesResponse.self, from: response)
        
        // Use the mapping function
        let devices = devicesResponse.items.compactMap { item -> AbstractDevice? in
            if item.capabilities.contains("lock") {
                return mapSmartThingsDeviceToLockDevice(item)
            } else {
                // Handle mapping for other device types (Light, Thermostat, etc.)
                // return mapSmartThingsDeviceToOtherType(item)
                return nil // Placeholder: Ignore non-lock devices for now
            }
        }
        return devices
    }
    
    public func getDeviceState(deviceId: String) async throws -> AbstractDevice {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        // --- Fetch Both Status and Device Details Concurrently --- 
        async let statusDataTask = retryHandler.executeRequest(
            URLRequest(url: URL(string: "\(baseURL)/devices/\(deviceId)/status")!,
                       method: .get, headers: headers),
            session: session.session) { error in
                self.logger.logError(error, context: ["deviceId": deviceId, "operation": "getDeviceStatus"])
            }
            
        async let deviceDataTask = retryHandler.executeRequest(
            URLRequest(url: URL(string: "\(baseURL)/devices/\(deviceId)")!,
                       method: .get, headers: headers),
            session: session.session) { error in
                self.logger.logError(error, context: ["deviceId": deviceId, "operation": "getDeviceDetails"])
            }
            
        // Await results
        let (statusData, deviceData) = try await (statusDataTask, deviceDataTask)
        
        // Decode Status Response
        let statusResponse: SmartThingsDeviceStatusResponse
        do {
            statusResponse = try JSONDecoder().decode(SmartThingsDeviceStatusResponse.self, from: statusData)
        } catch {
            self.logger.logError(error, context: ["deviceId": deviceId, "operation": "decodeDeviceStatus"])
            throw SmartThingsError.decodingError(error)
        }
        
        // Decode Device Details Response
        let deviceDetails: SmartThingsDevice
         do {
             deviceDetails = try JSONDecoder().decode(SmartThingsDevice.self, from: deviceData)
         } catch {
             self.logger.logError(error, context: ["deviceId": deviceId, "operation": "decodeDeviceDetails"])
             throw SmartThingsError.decodingError(error)
         }
        
        // Extract main component status
        guard let mainComponent = statusResponse.components["main"] else {
            self.logger.logWarning("Device status response missing 'main' component", context: ["deviceId": deviceId])
            throw SmartThingsError.invalidResponseFormat("Missing 'main' component")
        }
        
        let isOnline = statusResponse.healthState?.state == "ONLINE"
        let lastStateChange = mainComponent.values.first?.values.first?.timestamp // Attempt to get a timestamp
        // TODO: Improve lastStateChange extraction if needed by checking specific capabilities
        
        // ---- Determine Device Type and Map ----
        
        // Check for Lock capability
        if let lockStatusValue = mainComponent["lock"]?["lock"]?.value,
           let lockStatus = lockStatusValue.value as? String {
            let batteryLevel = mainComponent["battery"]?["battery"]?.value.value as? Int ?? 50
            let lockState: LockDevice.LockState
            switch lockStatus.lowercased() {
                case "locked": lockState = .locked
                case "unlocked": lockState = .unlocked
                default: lockState = .unknown
            }
             
            return LockDevice(
                id: deviceId,
                name: deviceDetails.name,
                room: "Unknown", // TODO: Map from deviceDetails.roomId if available/needed
                manufacturer: deviceDetails.manufacturerName ?? "SmartThings", // Use optional manufacturer name
                model: deviceDetails.deviceTypeName ?? "Unknown", // Use optional device type name
                firmwareVersion: deviceDetails.ocf?.fv ?? "N/A", // Use optional firmware version
                isOnline: isOnline,
                currentState: lockState,
                batteryLevel: batteryLevel,
                lastStateChange: nil, // TODO: Parse timestamp from SmartThingsStateValue if needed
                isRemoteOperationEnabled: true // Assume true, or check capabilities?
            )
        }
        
        // Check for Switch capability
        else if let switchStatusValue = mainComponent["switch"]?["switch"]?.value,
                let switchStatus = switchStatusValue.value as? String {
            let isOn = switchStatus.lowercased() == "on"
            
            return SwitchDevice(
                 id: deviceId,
                 name: deviceDetails.name,
                 room: "Unknown",
                 manufacturer: deviceDetails.manufacturerName ?? "SmartThings",
                 model: deviceDetails.deviceTypeName ?? "Unknown",
                 firmwareVersion: deviceDetails.ocf?.fv ?? "N/A",
                 isOnline: isOnline,
                 currentState: isOn,
                 lastStateChange: nil // TODO: Parse timestamp
             )
        }
        
        // Check for Thermostat capabilities
        else if mainComponent["thermostatMode"] != nil || mainComponent["temperatureMeasurement"] != nil {
            let currentTemp = mainComponent["temperatureMeasurement"]?["temperature"]?.value.value as? Double
            let heatingSetpoint = mainComponent["thermostatHeatingSetpoint"]?["temperature"]?.value.value as? Double
            let coolingSetpoint = mainComponent["thermostatCoolingSetpoint"]?["temperature"]?.value.value as? Double
            let modeString = mainComponent["thermostatMode"]?["thermostatMode"]?.value.value as? String ?? "off"
            let humidity = mainComponent["relativeHumidityMeasurement"]?["humidity"]?.value.value as? Double
            // TODO: Determine isHeating/isCooling/isFanRunning from thermostatOperatingState capability if present
            
            let mode: ThermostatMode
            switch modeString.lowercased() {
                case "heat": mode = .heat
                case "cool": mode = .cool
                case "auto": mode = .auto
                case "off": mode = .off
                // Add other modes if necessary (e.g., emergency heat)
                default: mode = .off
            }
            
            // Note: SmartThings uses separate heating/cooling setpoints. 
            // Our ThermostatDevice has a single targetTemperature. We need to decide how to map this.
            // Option: Use heating setpoint if mode is heat, cooling if mode is cool, average/nil if auto? 
            // For now, let's pass nil for targetTemperature and use specific setpoints if needed later.

            return ThermostatDevice(
                id: deviceId,
                name: deviceDetails.name,
                room: "Unknown", 
                manufacturer: deviceDetails.manufacturerName ?? "SmartThings", 
                model: deviceDetails.deviceTypeName ?? "Unknown",
                firmwareVersion: deviceDetails.ocf?.fv ?? "N/A",
                isOnline: isOnline,
                currentTemperature: currentTemp,
                targetTemperature: nil, // Map based on mode/setpoints if needed
                mode: mode,
                humidity: humidity,
                isHeating: mainComponent["thermostatOperatingState"]?["thermostatOperatingState"]?.value.value as? String == "heating", // Example
                isCooling: mainComponent["thermostatOperatingState"]?["thermostatOperatingState"]?.value.value as? String == "cooling", // Example
                isFanRunning: mainComponent["thermostatOperatingState"]?["thermostatOperatingState"]?.value.value as? String == "fan only", // Example
                fanMode: .auto // TODO: Map from thermostatFanMode capability if present
                // temperatureRange: // Not easily available from status
            )
        }
        
        // TODO: Add checks and mapping for other device types (Light - switchLevel, colorControl, etc.)
        
        else {
            // Fallback or error if device type couldn't be determined from status
            self.logger.logWarning("Could not determine device type from status response", context: ["deviceId": deviceId, "components": statusResponse.components])
            // Optionally return a GenericDevice or throw error
            // Let's return a GenericDevice for now if basic details are available
             return GenericDevice(
                 id: deviceId,
                 name: deviceDetails.name,
                 room: "Unknown",
                 manufacturer: deviceDetails.manufacturerName ?? "SmartThings",
                 model: deviceDetails.deviceTypeName ?? "Unknown",
                 firmwareVersion: deviceDetails.ocf?.fv ?? "N/A",
                 isOnline: isOnline,
                 deviceType: .other // Indicate unknown specific type
             )
            // throw SmartThingsError.unsupportedDeviceType("Could not map device from status")
        }
    }
    
    /// Execute a command on a device.
    /// - Parameters:
    ///   - deviceId: The ID of the device to command.
    ///   - command: The command to execute.
    /// - Returns: The updated state of the device.
    public func executeCommand(deviceId: String, command: DeviceCommand) async throws -> AbstractDevice {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        // --- Map DeviceCommand to SmartThings Command Payload ---
        // TODO: Implement this mapping based on the command type
        let smartThingsPayload: Data
        do {
            smartThingsPayload = try mapCommandToPayload(command)
        } catch {
            logger.logError(error, context: ["deviceId": deviceId, "command": String(describing: command), "operation": "mapCommandPayload"])
            throw error // Re-throw mapping error
        }
        
        // Construct the URL for executing commands
        let urlString = "\(baseURL)/devices/\(deviceId)/commands"
        guard let url = URL(string: urlString) else {
            throw SmartThingsError.invalidURL
        }
        
        // Prepare the request
        var request = URLRequest(url: url, method: .post, headers: headers)
        request.httpBody = smartThingsPayload
        
        // Execute the request using the retry handler
        let responseData = try await retryHandler.executeRequest(request, session: session.session) { error in
            // Log error for monitoring
            self.logger.logError(error, context: ["deviceId": deviceId, "command": String(describing: command), "operation": "executeCommand"])
        }
        
        // Decode the response (check for success/failure)
        // The actual command response might just be a status, not the full device state.
        do {
            let commandResponse = try JSONDecoder().decode(SmartThingsCommandResponse.self, from: responseData)
            guard commandResponse.status == "success" else {
                 logger.logWarning("SmartThings command execution failed", context: ["deviceId": deviceId, "command": String(describing: command), "response": commandResponse])
                 throw SmartThingsError.commandFailed(commandResponse.message ?? "Command execution failed")
            }
        } catch {
            logger.logError(error, context: ["deviceId": deviceId, "command": String(describing: command), "operation": "decodeCommandResponse"])
            throw SmartThingsError.decodingError(error)
        }
        
        // --- Return Updated State ---
        // Option 1: Assume success and return an optimistic state (less reliable)
        // Option 2: Re-fetch the full device state to confirm (more reliable, adds latency)
        // Let's go with Option 2 for now.
        logger.logInfo("Command executed successfully, fetching updated state...", context: ["deviceId": deviceId, "command": String(describing: command)])
        return try await getDeviceState(deviceId: deviceId)
    }
    
    public func revokeAuthentication() async -> Bool {
        logger.info("Revoking SmartThings authentication.")
        metrics.incrementCounter(forName: .authenticationRevocationsAttempted)
        await tokenManager.clearTokens()
        logger.info("SmartThings authentication tokens cleared locally.")
        metrics.incrementCounter(forName: .authenticationRevocationsSucceeded)
        // Note: This does not call a SmartThings API endpoint to revoke the token server-side.
        // Depending on requirements, a call to a revocation endpoint might be needed.
        return true // Assume local clearing is the definition of success here.
    }
    
    func updateDeviceState(deviceId: String, newState: DeviceState) async throws -> DeviceState {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        let command = convertToSmartThingsCommand(newState)
        
        var request = URLRequest(url: URL(string: "\(baseURL)/devices/\(deviceId)/commands")!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers.dictionary
        request.httpBody = command
        
        do {
            _ = try await retryHandler.executeRequest(request, session: session.session) { error in
                self.logger.logError(error, context: ["deviceId": deviceId, "operation": "updateState"])
                
                // Attempt recovery for device-specific errors
                if let smartThingsError = error as? SmartThingsError {
                    Task {
                        // Convert the String? deviceType from newState to the DeviceType enum
                        let deviceTypeEnum = DeviceType(rawValue: newState.deviceType?.uppercased() ?? "OTHER") ?? .other
                        
                        let recovered = await self.errorRecovery.attemptRecovery(
                            for: smartThingsError,
                            deviceId: deviceId,
                            deviceType: deviceTypeEnum, // Pass the converted enum case
                            context: ["state": newState]
                        )
                        
                        if recovered {
                            self.logger.logInfo("Device recovered successfully", context: ["deviceId": deviceId])
                        } else {
                            self.logger.logWarning("Device recovery failed", context: ["deviceId": deviceId])
                        }
                    }
                }
            }
            
            self.logger.logDeviceOperation(
                deviceId: deviceId,
                operation: "updateState",
                status: "success",
                context: ["state": newState]
            )
            
            return newState
        } catch {
            self.logger.logDeviceOperation(
                deviceId: deviceId,
                operation: "updateState",
                status: "failed",
                context: ["error": error.localizedDescription]
            )
            throw error
        }
    }
    
    // MARK: - Webhook Management
    
    func subscribeToWebhooks(url: String, events: [SmartThingsWebhookEvent], deviceIds: [String]? = nil) async throws -> SmartThingsWebhookSubscriptionResponse {
        let token = try await tokenManager.getValidToken()
        
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
        
        let response = try await retryHandler.executeRequest(request, session: session.session) { error in
            // Log error for monitoring
            print("Error subscribing to webhooks: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode(SmartThingsWebhookSubscriptionResponse.self, from: response)
    }
    
    func deleteWebhook(webhookId: String) async throws {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/webhooks/\(webhookId)")!)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = headers.dictionary
        
        _ = try await retryHandler.executeRequest(request, session: session.session) { error in
            // Log error for monitoring
            print("Error deleting webhook: \(error.localizedDescription)")
        }
    }
    
    func listWebhooks() async throws -> [SmartThingsWebhookSubscriptionResponse] {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/webhooks")!)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers.dictionary
        
        let response = try await retryHandler.executeRequest(request, session: session.session) { error in
            // Log error for monitoring
            print("Error listing webhooks: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode([SmartThingsWebhookSubscriptionResponse].self, from: response)
    }
    
    // MARK: - Group Management
    
    func createGroup(name: String, deviceIds: [String], roomId: String? = nil) async throws -> SmartThingsGroupResponse {
        let token = try await tokenManager.getValidToken()
        
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
        
        let response = try await retryHandler.executeRequest(urlRequest, session: session.session) { error in
            // Log error for monitoring
            print("Error creating group: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode(SmartThingsGroupResponse.self, from: response)
    }
    
    func updateGroup(groupId: String, name: String? = nil, deviceIds: [String]? = nil, roomId: String? = nil) async throws -> SmartThingsGroupResponse {
        let token = try await tokenManager.getValidToken()
        
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
        
        let response = try await retryHandler.executeRequest(urlRequest, session: session.session) { error in
            // Log error for monitoring
            print("Error updating group: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode(SmartThingsGroupResponse.self, from: response)
    }
    
    func deleteGroup(groupId: String) async throws {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/groups/\(groupId)")!)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = headers.dictionary
        
        _ = try await retryHandler.executeRequest(request, session: session.session) { error in
            // Log error for monitoring
            print("Error deleting group: \(error.localizedDescription)")
        }
    }
    
    func listGroups() async throws -> [SmartThingsGroupResponse] {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/groups")!)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers.dictionary
        
        let response = try await retryHandler.executeRequest(request, session: session.session) { error in
            // Log error for monitoring
            print("Error listing groups: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode([SmartThingsGroupResponse].self, from: response)
    }
    
    func executeGroupCommand(groupId: String, command: SmartThingsGroupCommandRequest) async throws {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/groups/\(groupId)/commands")!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers.dictionary
        request.httpBody = try JSONEncoder().encode(command)
        
        _ = try await retryHandler.executeRequest(request, session: session.session) { error in
            // Log error for monitoring
            print("Error executing group command: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Scene Management
    
    func createScene(name: String, actions: [SmartThingsSceneAction], roomId: String? = nil) async throws -> SmartThingsSceneResponse {
        let token = try await tokenManager.getValidToken()
        
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
        
        let response = try await retryHandler.executeRequest(urlRequest, session: session.session) { error in
            // Log error for monitoring
            print("Error creating scene: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode(SmartThingsSceneResponse.self, from: response)
    }
    
    func updateScene(sceneId: String, name: String? = nil, actions: [SmartThingsSceneAction]? = nil, roomId: String? = nil) async throws -> SmartThingsSceneResponse {
        let token = try await tokenManager.getValidToken()
        
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
        
        let response = try await retryHandler.executeRequest(urlRequest, session: session.session) { error in
            // Log error for monitoring
            print("Error updating scene: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode(SmartThingsSceneResponse.self, from: response)
    }
    
    func deleteScene(sceneId: String) async throws {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/scenes/\(sceneId)")!)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = headers.dictionary
        
        _ = try await retryHandler.executeRequest(request, session: session.session) { error in
            // Log error for monitoring
            print("Error deleting scene: \(error.localizedDescription)")
        }
    }
    
    func listScenes() async throws -> [SmartThingsSceneResponse] {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/scenes")!)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers.dictionary
        
        let response = try await retryHandler.executeRequest(request, session: session.session) { error in
            // Log error for monitoring
            print("Error listing scenes: \(error.localizedDescription)")
        }
        
        return try JSONDecoder().decode([SmartThingsSceneResponse].self, from: response)
    }
    
    func executeScene(sceneId: String) async throws -> SmartThingsSceneExecutionResponse {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/scenes/\(sceneId)/execute")!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers.dictionary
        
        let startTime = Date()
        
        do {
            let response = try await retryHandler.executeRequest(request, session: session.session) { error in
                self.logger.logError(error, context: ["sceneId": sceneId, "operation": "executeScene"])
            }
            
            let latency = Date().timeIntervalSince(startTime)
            metrics.recordOperationLatency("executeScene", latency: latency)
            
            self.logger.logSceneOperation(
                sceneId: sceneId,
                operation: "execute",
                status: "success",
                context: ["latency": latency]
            )
            
            return try JSONDecoder().decode(SmartThingsSceneExecutionResponse.self, from: response)
        } catch {
            self.logger.logSceneOperation(
                sceneId: sceneId,
                operation: "execute",
                status: "failed",
                context: ["error": error.localizedDescription]
            )
            throw error
        }
    }
    
    // MARK: - Device State Management
    
    func fetchDeviceState(deviceId: String) async throws -> DeviceState {
        let token = try await tokenManager.getValidToken()
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/devices/\(deviceId)/status")!)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers.dictionary
        
        let startTime = Date()
        
        do {
            let response = try await retryHandler.executeRequest(request, session: session.session) { error in
                self.logger.logError(error, context: ["deviceId": deviceId, "operation": "fetchState"])
            }
            
            let latency = Date().timeIntervalSince(startTime)
            metrics.recordOperationLatency("fetchState", latency: latency)
            
            let _ = try JSONDecoder().decode(SmartThingsDeviceStatusResponse.self, from: response)
            
            // Convert SmartThings status to DeviceState
            let state = DeviceState(isOnline: true, attributes: [:]) // Placeholder - needs actual attribute conversion
            /* 
            let state = DeviceState(
                deviceId: deviceId, // Incorrect initializer
                deviceType: statusResponse.type, // Incorrect property 
                attributes: [:] // Needs conversion logic
            )
            */
            
            // Assume state.attributes contains the capability string? This needs review.
            // For now, let's use a placeholder capability.
            let _ = [
                "capability": "switch", // Placeholder - Was state.deviceType.rawValue
                "command": state.attributes["command"]?.value as? String ?? "on" // Access .value from AnyCodable
            ]
            
            self.logger.logDeviceOperation(
                deviceId: deviceId,
                operation: "fetchState",
                status: "success",
                context: ["latency": latency]
            )
            
            return state
        } catch {
            self.logger.logDeviceOperation(
                deviceId: deviceId,
                operation: "fetchState",
                status: "failed",
                context: ["error": error.localizedDescription]
            )
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func mapCommandToPayload(_ command: DeviceCommand) throws -> Data {
        let capability: String
        let commandString: String
        var arguments: [Any]? = nil // SmartThings arguments are often an array

        switch command {
        case .lock:
            capability = "lock"
            commandString = "lock"
        case .unlock:
            capability = "lock"
            commandString = "unlock"
        case .turnOn:
            capability = "switch"
            commandString = "on"
        case .turnOff:
            capability = "switch"
            commandString = "off"
        case .setBrightness(let level):
            capability = "switchLevel"
            commandString = "setLevel"
            arguments = [level] // Argument is the brightness level
        case .setThermostatMode(let mode):
            capability = "thermostatMode"
            commandString = "setThermostatMode"
            arguments = [mode.rawValue] // Argument is the mode string (e.g., "heat", "cool")
        case .setHeatingSetpoint(let temp):
            capability = "thermostatHeatingSetpoint"
            commandString = "setHeatingSetpoint"
            // SmartThings expects temperature and unit (optional, defaults to F or C based on location)
            // For simplicity, we send just the temperature value for now.
            // Could enhance later to include unit if needed: arguments = [temp, "C" or "F"]
            arguments = [temp]
        case .setCoolingSetpoint(let temp):
            capability = "thermostatCoolingSetpoint"
            commandString = "setCoolingSetpoint"
            arguments = [temp]
        // TODO: Add cases for other commands (setColor, setFanMode, etc.)
        default:
            logger.logWarning("Unsupported command for SmartThings mapping", context: ["command": String(describing: command)])
            throw SmartThingsError.commandNotSupported(String(describing: command))
        }
        
        // Construct the SmartThings command payload structure
        var commandPayload: [String: Any] = [
            "component": "main",
            "capability": capability,
            "command": commandString
        ]
        
        if let args = arguments {
            commandPayload["arguments"] = args
        }
        
        let fullPayload = ["commands": [commandPayload]]
        
        do {
            return try JSONSerialization.data(withJSONObject: fullPayload, options: [])
        } catch {
            logger.logError(error, context: ["command": String(describing: command), "operation": "serializeCommandPayload"])
            throw SmartThingsError.encodingError(error)
        }
    }

    private func convertToSmartThingsCommand(_ state: DeviceState) -> Data {
        // Convert DeviceState to SmartThings command format
        // This is a simplified version for MVP
        let command: [String: Any] = [
            "commands": [
                [
                    "component": "main",
                    "capability": "switch",
                    "command": state.attributes["command"]?.value as? String ?? "on"
                ]
            ]
        ]
        
        return try! JSONSerialization.data(withJSONObject: command)
    }
} 