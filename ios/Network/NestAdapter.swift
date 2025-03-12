import Foundation

enum NestAdapterError: Error {
    case notAuthenticated
    case invalidURL
    case serverError(code: Int)
    case networkError(Error)
    case invalidCommand
    case rateLimited(retryAfter: Double?)
    case parsingError(String)
    
    var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Nest"
        case .invalidURL:
            return "Invalid URL for Nest API request"
        case .serverError(let code):
            return "Server error with status code: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidCommand:
            return "Invalid command for thermostat"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Try again in \(Int(seconds)) seconds."
            }
            return "Rate limited by Nest API"
        case .parsingError(let message):
            return "Error parsing Nest response: \(message)"
        }
    }
}

class NestAdapter {
    private var session: URLSession
    private let nestOAuthManager: NestOAuthManager
    private let configuration: NestConfiguration
    
    // Rate limiting management
    private var requestTimestamps: [Date] = []
    private let maxRequestsPerMinute = 100
    private var authToken: String?
    
    init(nestOAuthManager: NestOAuthManager = NestOAuthManager(), configuration: NestConfiguration = NestConfiguration()) {
        self.nestOAuthManager = nestOAuthManager
        self.configuration = configuration
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        self.session = URLSession(configuration: config)
    }
    
    func initializeConnection(authToken: String) throws {
        // Store the auth token for API requests
        self.authToken = authToken
        
        // Clear old timestamps for rate limit tracking
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        requestTimestamps = requestTimestamps.filter { $0 > oneMinuteAgo }
        
        // Check if credentials are placeholders
        if configuration.clientID.contains("[YOUR_") || configuration.projectID.contains("[YOUR_") {
            throw NestAdapterError.notAuthenticated
        }
    }
    
    func fetchDevices() async throws -> [SmartDeviceAdapter] {
        // Check authentication
        guard let authToken = self.authToken else {
            throw NestAdapterError.notAuthenticated
        }
        
        // Check rate limits
        try checkRateLimits()
        
        // Create URL for devices request
        guard let url = configuration.buildListDevicesURL() else {
            throw NestAdapterError.invalidURL
        }
        
        // Create and configure the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        // Track this request
        trackRequest()
        
        do {
            // Make the request
            let (data, response) = try await session.data(for: request)
            
            // Process HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                // Handle HTTP status codes
                switch httpResponse.statusCode {
                case 200:
                    // Success - parse the devices
                    return try parseDevices(from: data)
                    
                case 401:
                    // Authentication error
                    throw NestAdapterError.notAuthenticated
                    
                case 429:
                    // Rate limiting
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    throw NestAdapterError.rateLimited(retryAfter: Double(retryAfter ?? "60"))
                    
                default:
                    // Server error or other error
                    throw NestAdapterError.serverError(code: httpResponse.statusCode)
                }
            }
            
            // Fallback parsing if we can't check HTTP status code
            return try parseDevices(from: data)
        } catch let adapterError as NestAdapterError {
            // Rethrow adapter-specific errors
            throw adapterError
        } catch {
            // Wrap other errors
            throw NestAdapterError.networkError(error)
        }
    }
    
    func updateDeviceState(deviceId: String, newState: [String: Any]) async throws -> Bool {
        // Check authentication
        guard let authToken = self.authToken else {
            throw NestAdapterError.notAuthenticated
        }
        
        // Check rate limits
        try checkRateLimits()
        
        // Create URL for device command
        guard let url = configuration.buildDeviceURL(deviceID: deviceId) else {
            throw NestAdapterError.invalidURL
        }
        
        // Build the command request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert state to command JSON format
        do {
            let commandBody = try createCommand(from: newState)
            request.httpBody = commandBody
        } catch {
            throw NestAdapterError.invalidCommand
        }
        
        // Track this request
        trackRequest()
        
        do {
            // Make the request
            let (data, response) = try await session.data(for: request)
            
            // Process HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                // Handle HTTP status codes
                switch httpResponse.statusCode {
                case 200, 201, 204:
                    // Success
                    return true
                    
                case 401:
                    // Authentication error
                    throw NestAdapterError.notAuthenticated
                    
                case 429:
                    // Rate limiting
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    throw NestAdapterError.rateLimited(retryAfter: Double(retryAfter ?? "60"))
                    
                default:
                    // Server error or other error
                    throw NestAdapterError.serverError(code: httpResponse.statusCode)
                }
            }
            
            // If we can't check the HTTP status, consider it a success if there's no exception
            return true
        } catch let adapterError as NestAdapterError {
            // Rethrow adapter-specific errors
            throw adapterError
        } catch {
            // Wrap other errors
            throw NestAdapterError.networkError(error)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func trackRequest() {
        // Add current timestamp to track rate limits
        requestTimestamps.append(Date())
        
        // Clean up old timestamps (older than 1 minute)
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        requestTimestamps = requestTimestamps.filter { $0 > oneMinuteAgo }
    }
    
    private func checkRateLimits() throws {
        // Clean up old timestamps
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        requestTimestamps = requestTimestamps.filter { $0 > oneMinuteAgo }
        
        // Check if we're over the limit
        if requestTimestamps.count >= maxRequestsPerMinute {
            throw NestAdapterError.rateLimited(retryAfter: 60)
        }
    }
    
    private func parseDevices(from data: Data) throws -> [SmartDeviceAdapter] {
        do {
            // Parse the JSON response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let devices = json["devices"] as? [[String: Any]] else {
                throw NestAdapterError.parsingError("Invalid response format")
            }
            
            // Convert each device to our internal model
            var smartDevices: [SmartDeviceAdapter] = []
            
            for deviceJson in devices {
                if let device = convertToDevice(deviceJson) {
                    smartDevices.append(device)
                }
            }
            
            return smartDevices
        } catch {
            if let parseError = error as? NestAdapterError {
                throw parseError
            }
            throw NestAdapterError.parsingError(error.localizedDescription)
        }
    }
    
    private func convertToDevice(_ deviceJson: [String: Any]) -> SmartDeviceAdapter? {
        guard let deviceId = deviceJson["name"] as? String,
              let type = deviceJson["type"] as? String else {
            return nil
        }
        
        // Extract the display name from the device's custom name
        var displayName = "Unknown Device"
        if let traits = deviceJson["traits"] as? [String: Any],
           let info = traits["sdm.devices.traits.Info"] as? [String: Any],
           let customName = info["customName"] as? String {
            displayName = customName
        }
        
        // For now we only support thermostats, but could expand to other device types
        if type.contains("thermostat") {
            return convertToThermostat(deviceId: deviceId, displayName: displayName, deviceJson: deviceJson)
        }
        
        return nil
    }
    
    private func convertToThermostat(deviceId: String, displayName: String, deviceJson: [String: Any]) -> ThermostatDevice? {
        guard let traits = deviceJson["traits"] as? [String: Any] else {
            return nil
        }
        
        // Parse temperature traits
        var currentTemperature: Double = 0
        var targetTemperature: Double = 0
        var mode: ThermostatDevice.ThermostatMode = .off
        var availableModes: [ThermostatDevice.ThermostatMode] = []
        
        // Parse temperature setting
        if let tempSetting = traits["sdm.devices.traits.ThermostatTemperatureSetpoint"] as? [String: Any] {
            if let heatCelsius = tempSetting["heatCelsius"] as? Double {
                targetTemperature = heatCelsius
            } else if let coolCelsius = tempSetting["coolCelsius"] as? Double {
                targetTemperature = coolCelsius
            }
        }
        
        // Parse current temperature
        if let tempTrait = traits["sdm.devices.traits.Temperature"] as? [String: Any],
           let tempCelsius = tempTrait["ambientTemperatureCelsius"] as? Double {
            currentTemperature = tempCelsius
        }
        
        // Parse mode
        if let modeTrait = traits["sdm.devices.traits.ThermostatMode"] as? [String: Any] {
            if let modeString = modeTrait["mode"] as? String {
                mode = mapToMode(modeString)
            }
            
            if let availableModesJson = modeTrait["availableModes"] as? [String] {
                availableModes = availableModesJson.compactMap { mapToMode($0) }
            }
        }
        
        // Create and return the thermostat device
        return ThermostatDevice(
            id: deviceId,
            name: displayName,
            currentTemperature: currentTemperature,
            targetTemperature: targetTemperature,
            mode: mode,
            availableModes: availableModes
        )
    }
    
    private func mapToMode(_ modeString: String) -> ThermostatDevice.ThermostatMode {
        switch modeString.lowercased() {
        case "heat": return .heat
        case "cool": return .cool
        case "heatcool": return .auto
        default: return .off
        }
    }
    
    private func createCommand(from state: [String: Any]) throws -> Data {
        // Create the command structure based on state changes
        var command: [String: Any] = [:]
        
        if let targetTemperature = state["targetTemperature"] as? Double {
            // For temperature changes
            if let mode = state["mode"] as? String {
                switch mode {
                case "heat":
                    command = [
                        "command": "sdm.devices.commands.ThermostatTemperatureSetpoint.SetHeat",
                        "params": ["heatCelsius": targetTemperature]
                    ]
                case "cool":
                    command = [
                        "command": "sdm.devices.commands.ThermostatTemperatureSetpoint.SetCool",
                        "params": ["coolCelsius": targetTemperature]
                    ]
                case "heatcool", "auto":
                    // For heat-cool mode, we'd need a range, but we're simplifying
                    command = [
                        "command": "sdm.devices.commands.ThermostatTemperatureSetpoint.SetRange",
                        "params": [
                            "heatCelsius": targetTemperature - 1,
                            "coolCelsius": targetTemperature + 1
                        ]
                    ]
                default:
                    throw NestAdapterError.invalidCommand
                }
            }
        } else if let modeString = state["mode"] as? String {
            // For mode changes only
            var nestMode: String
            
            switch modeString {
            case "heat": nestMode = "HEAT"
            case "cool": nestMode = "COOL"
            case "auto", "heatcool": nestMode = "HEATCOOL"
            case "off": nestMode = "OFF"
            default:
                throw NestAdapterError.invalidCommand
            }
            
            command = [
                "command": "sdm.devices.commands.ThermostatMode.SetMode",
                "params": ["mode": nestMode]
            ]
        }
        
        // If command is empty, we didn't build a valid command
        if command.isEmpty {
            throw NestAdapterError.invalidCommand
        }
        
        return try JSONSerialization.data(withJSONObject: command, options: [])
    }
} 