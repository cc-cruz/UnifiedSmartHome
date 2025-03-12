import Foundation
import Combine

// Detailed error types for better error handling
enum NestAdapterError: Error, LocalizedError {
    case notAuthenticated
    case invalidURL
    case serverError(statusCode: Int)
    case networkError(Error)
    case invalidCommand
    case rateLimited(retryAfter: TimeInterval?)
    case parseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Nest. Please connect your account."
        case .invalidURL:
            return "Invalid API URL. Please check your configuration."
        case .serverError(let code):
            return "Server error with status code \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidCommand:
            return "Invalid command for this device"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Please try again after \(Int(seconds)) seconds."
            }
            return "Rate limited. Please try again later."
        case .parseError(let error):
            return "Failed to parse API response: \(error.localizedDescription)"
        }
    }
}

class NestAdapter: SmartDeviceAdapter {
    private var authToken: String?
    private let baseURL = "https://smartdevicemanagement.googleapis.com/v1"
    private let nestOAuthManager: NestOAuthManager
    
    private var enterprisePath: String {
        return "enterprises/\(nestOAuthManager.getProjectID())"
    }
    
    private var session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    // Rate limiting properties
    private var lastRequestTime: Date?
    private var requestsThisMinute = 0
    private let maxRequestsPerMinute = 60 // Default, adjust based on API docs
    
    init(nestOAuthManager: NestOAuthManager = NestOAuthManager(), session: URLSession = .shared) {
        self.nestOAuthManager = nestOAuthManager
        self.session = session
    }
    
    // Initialize connection with auth token
    func initializeConnection(authToken: String) throws {
        self.authToken = authToken
    }
    
    // Fetch all devices from Nest
    func fetchDevices() async throws -> [AbstractDevice] {
        guard let authToken = authToken else {
            throw NestAdapterError.notAuthenticated
        }
        
        // Rate limiting check
        try checkRateLimit()
        
        let urlString = "\(baseURL)/\(enterprisePath)/devices"
        guard let url = URL(string: urlString) else {
            throw NestAdapterError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Track request for rate limiting
            trackRequest()
            
            // Handle HTTP status codes as specified in the API Reference doc
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NestAdapterError.serverError(statusCode: 0)
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                // Success - process the response
                break
            case 401:
                // Unauthorized - token issue
                throw NestAdapterError.notAuthenticated
            case 429:
                // Rate limited
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }
                throw NestAdapterError.rateLimited(retryAfter: retryAfter)
            default:
                throw NestAdapterError.serverError(statusCode: httpResponse.statusCode)
            }
            
            // Parse the response
            do {
                let nestResponse = try JSONDecoder().decode(NestDeviceResponse.self, from: data)
                
                // Convert Nest devices to abstract devices
                return nestResponse.devices.compactMap { nestDevice in
                    return convertToAbstractDevice(nestDevice)
                }
            } catch {
                throw NestAdapterError.parseError(error)
            }
        } catch let error as NestAdapterError {
            // Re-throw adapter errors
            throw error
        } catch {
            // Wrap other errors
            throw NestAdapterError.networkError(error)
        }
    }
    
    // Update device state
    func updateDeviceState(deviceId: String, newState: DeviceState) async throws -> DeviceState {
        guard let authToken = authToken else {
            throw NestAdapterError.notAuthenticated
        }
        
        // Rate limiting check
        try checkRateLimit()
        
        // Extract the relative device ID from the full device name if needed
        let relativeDeviceId: String
        if deviceId.contains("/") {
            relativeDeviceId = deviceId.components(separatedBy: "/").last ?? deviceId
        } else {
            relativeDeviceId = deviceId
        }
        
        let urlString = "\(baseURL)/\(enterprisePath)/devices/\(relativeDeviceId):executeCommand"
        guard let url = URL(string: urlString) else {
            throw NestAdapterError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Determine command based on device state
        if let targetTemp = newState.attributes["targetTemperature"]?.value as? Double {
            // For temperature updates
            let command = NestCommand(
                command: "sdm.devices.commands.ThermostatTemperatureSetpoint.SetHeat",
                params: ["heatCelsius": targetTemp]
            )
            
            do {
                let bodyData = try JSONEncoder().encode(command)
                request.httpBody = bodyData
                
                let (_, response) = try await session.data(for: request)
                
                // Track request for rate limiting
                trackRequest()
                
                // Handle HTTP status codes
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NestAdapterError.serverError(statusCode: 0)
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    // Success - return the updated state
                    return newState
                case 401:
                    throw NestAdapterError.notAuthenticated
                case 429:
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }
                    throw NestAdapterError.rateLimited(retryAfter: retryAfter)
                default:
                    throw NestAdapterError.serverError(statusCode: httpResponse.statusCode)
                }
                
            } catch let error as NestAdapterError {
                throw error
            } catch {
                throw NestAdapterError.networkError(error)
            }
        } else if let mode = newState.attributes["mode"]?.value as? String {
            // For mode updates
            let nestMode: String
            
            switch mode {
            case "HEAT":
                nestMode = "HEAT"
            case "COOL":
                nestMode = "COOL"
            case "AUTO":
                nestMode = "HEATCOOL"
            case "ECO":
                nestMode = "ECO"
            default:
                nestMode = "OFF"
            }
            
            let command = NestCommand(
                command: "sdm.devices.commands.ThermostatMode.SetMode",
                params: ["mode": nestMode]
            )
            
            do {
                let bodyData = try JSONEncoder().encode(command)
                request.httpBody = bodyData
                
                let (_, response) = try await session.data(for: request)
                
                // Track request for rate limiting
                trackRequest()
                
                // Handle HTTP status codes
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NestAdapterError.serverError(statusCode: 0)
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    // Success - return the updated state
                    return newState
                case 401:
                    throw NestAdapterError.notAuthenticated
                case 429:
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }
                    throw NestAdapterError.rateLimited(retryAfter: retryAfter)
                default:
                    throw NestAdapterError.serverError(statusCode: httpResponse.statusCode)
                }
                
            } catch let error as NestAdapterError {
                throw error
            } catch {
                throw NestAdapterError.networkError(error)
            }
        } else {
            throw NestAdapterError.invalidCommand
        }
    }
    
    // Private method to track request rate for rate limiting
    private func trackRequest() {
        let now = Date()
        
        if let last = lastRequestTime, now.timeIntervalSince(last) < 60 {
            // Still within the same minute window
            requestsThisMinute += 1
        } else {
            // New minute window
            requestsThisMinute = 1
            lastRequestTime = now
        }
    }
    
    // Check if we're approaching rate limits
    private func checkRateLimit() throws {
        guard let last = lastRequestTime else {
            return // First request, no need to check
        }
        
        let now = Date()
        if now.timeIntervalSince(last) < 60 && requestsThisMinute >= maxRequestsPerMinute {
            // We've hit our rate limit for this minute
            let secondsToWait = 60 - now.timeIntervalSince(last)
            throw NestAdapterError.rateLimited(retryAfter: secondsToWait)
        }
    }
    
    // Convert Nest device to abstract device
    private func convertToAbstractDevice(_ nestDevice: NestDevice) -> AbstractDevice? {
        // Check if this is a thermostat by looking at its traits
        if nestDevice.traits.contains(where: { $0.key.contains("ThermostatTemperatureSetpoint") || $0.key.contains("ThermostatMode") }) {
            // Extract temperature data
            var currentTemp: Double = 20.0 // Default
            var targetTemp: Double = 21.0 // Default
            var mode: ThermostatDevice.ThermostatMode = .off
            
            if let ambientTempC = nestDevice.traits["sdm.devices.traits.Temperature"]?["ambientTemperatureCelsius"] as? Double {
                currentTemp = ambientTempC
            }
            
            if let heatTempC = nestDevice.traits["sdm.devices.traits.ThermostatTemperatureSetpoint"]?["heatCelsius"] as? Double {
                targetTemp = heatTempC
            } else if let coolTempC = nestDevice.traits["sdm.devices.traits.ThermostatTemperatureSetpoint"]?["coolCelsius"] as? Double {
                targetTemp = coolTempC
            }
            
            if let modeStr = nestDevice.traits["sdm.devices.traits.ThermostatMode"]?["mode"] as? String {
                switch modeStr {
                case "HEAT":
                    mode = .heat
                case "COOL":
                    mode = .cool
                case "HEATCOOL":
                    mode = .auto
                case "ECO":
                    mode = .eco
                default:
                    mode = .off
                }
            }
            
            // Create capabilities array
            let capabilities: [Device.DeviceCapability] = [
                Device.DeviceCapability(type: "temperature", attributes: [
                    "current": AnyCodable(currentTemp),
                    "target": AnyCodable(targetTemp)
                ]),
                Device.DeviceCapability(type: "mode", attributes: [
                    "value": AnyCodable(mode.rawValue)
                ])
            ]
            
            // Get device name
            let deviceName = nestDevice.traits["sdm.devices.traits.Info"]?["customName"] as? String ?? "Nest Thermostat"
            
            // Create a thermostat device
            return ThermostatDevice(
                id: nestDevice.name,
                name: deviceName,
                manufacturer: .googleNest,
                roomId: nil, // Nest doesn't provide room info in the same way
                propertyId: "default", // You would need to map this to your property structure
                status: .online,
                capabilities: capabilities,
                currentTemperature: currentTemp,
                targetTemperature: targetTemp,
                mode: mode,
                units: .celsius // Nest API uses Celsius
            )
        }
        
        return nil // Not a thermostat or unsupported device type
    }
}

// MARK: - Nest API Response Models
struct NestDeviceResponse: Decodable {
    let devices: [NestDevice]
}

struct NestDevice: Decodable {
    let name: String
    let type: String
    let traits: [String: [String: Any]]
    
    enum CodingKeys: String, CodingKey {
        case name, type, traits
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        
        // Decode traits as [String: Any]
        let traitsData = try container.decode(Data.self, forKey: .traits)
        if let json = try JSONSerialization.jsonObject(with: traitsData) as? [String: [String: Any]] {
            traits = json
        } else {
            traits = [:]
        }
    }
}

// MARK: - Nest API Command Models
struct NestCommand: Encodable {
    let command: String
    let params: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case command, params
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(command, forKey: .command)
        
        // Encode params as JSON
        let paramsData = try JSONSerialization.data(withJSONObject: params)
        try container.encode(paramsData, forKey: .params)
    }
} 