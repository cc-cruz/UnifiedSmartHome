import Foundation
import Combine
import Models
import Services

/// Error types specific to the Nest Adapter
enum NestAdapterError: Error, LocalizedError {
    case notAuthenticated
    case apiError(String)
    case requestFailed(Error)
    case decodingError(Error)
    case invalidURL
    case rateLimitExceeded
    case deviceNotFound
    case commandNotSupported(String)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Authentication token is missing or invalid."
        case .apiError(let message):
            return "Nest API Error: \(message)"
        case .requestFailed(let error):
            return "Network request failed: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode API response: \(error.localizedDescription)"
        case .invalidURL:
            return "The API endpoint URL is invalid."
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        case .deviceNotFound:
            return "The specified device could not be found."
        case .commandNotSupported(let commandName):
            return "The command '\(commandName)' is not supported for this Nest device."
        case .unknownError:
            return "An unknown error occurred."
        }
    }
}

/// Adapter for interacting with Nest devices via the SDM API
class NestAdapter: SmartDeviceAdapter {
    private var authToken: String?
    private let baseURL = "https://smartdevicemanagement.googleapis.com/v1"
    private let nestOAuthManager: NestOAuthManager
    
    private var enterprisePath: String {
        // Ensure project ID is available before constructing path
        let projectID = nestOAuthManager.getProjectID()
        guard !projectID.isEmpty else {
            // Handle missing project ID appropriately, maybe log an error or return default
            print("Error: Nest Project ID is missing.")
            return "enterprises/" 
        }
        return "enterprises/\(projectID)"
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
    
    // MARK: - SmartDeviceAdapter Conformance (Placeholders)
    
    /// Initialize the adapter with an authentication token
    func initialize(with authToken: String) throws {
        print("NestAdapter: Initializing with token.")
        self.authToken = authToken
        // Additional setup if needed
    }
    
    /// Refresh authentication if needed
    func refreshAuthentication() async throws -> Bool {
        print("NestAdapter: Attempting to refresh authentication.")
        // TODO: Integrate with NestOAuthManager's refresh logic
        // Example: Trigger refresh and check result
        await nestOAuthManager.refreshAccessToken()
        // This might need to be awaitable or use Combine publishers
        // Returning false as a placeholder, actual logic needed.
        return false 
    }
    
    /// Get the current state of a specific device
    func getDeviceState(deviceId: String) async throws -> AbstractDevice {
        print("NestAdapter: Getting state for device \(deviceId).")
        // TODO: Implement API call to get specific device state
        throw NestAdapterError.commandNotSupported("getDeviceState - Not Implemented")
    }
    
    /// Update a device's state by executing a command
    /// NOTE: The command type is SmartThingsCommand as per the protocol.
    /// This might need adjustment for Nest-specific commands.
    func executeCommand(deviceId: String, command: DeviceCommand) async throws -> AbstractDevice {
        print("NestAdapter: Executing command on device \(deviceId).")
        // TODO: Implement API call to execute Nest command
        // Need mapping from DeviceCommand to Nest command structure
        throw NestAdapterError.commandNotSupported("executeCommand - Not Implemented for \(command)")
    }
    
    /// Revoke authentication tokens
    func revokeAuthentication() async throws {
        print("NestAdapter: Revoking authentication.")
        await nestOAuthManager.signOut()
        self.authToken = nil
    }

    // MARK: - Existing Methods

    // Fetch all devices from Nest
    func fetchDevices() async throws -> [AbstractDevice] {
        guard let token = await nestOAuthManager.getAccessToken() else {
            throw NestAdapterError.notAuthenticated
        }
        
        guard let url = URL(string: "\(baseURL)/\(enterprisePath)/devices") else {
            throw NestAdapterError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("Fetching Nest devices from: \(url)") // Debugging
        
        // Basic rate limiting check (needs refinement)
        try await checkRateLimit()

        do {
            let (data, response) = try await session.data(for: request)
            recordRequestTime()
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NestAdapterError.requestFailed(URLError(.badServerResponse))
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                 let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                 print("Nest API Error (fetchDevices): \(httpResponse.statusCode) - \(errorBody)") // Debugging
                 throw NestAdapterError.apiError("Status code: \(httpResponse.statusCode), Body: \(errorBody)")
             }
            
            // Decode the response
            let decodedResponse = try JSONDecoder().decode(NestDeviceListResponse.self, from: data)
            
            // Convert Nest devices to AbstractDevice
            let abstractDevices = decodedResponse.devices?.compactMap { convertToAbstractDevice($0) } ?? []
            return abstractDevices
            
        } catch let error as DecodingError {
            print("Decoding Error (fetchDevices): \(error)") // Debugging
             throw NestAdapterError.decodingError(error)
         } catch let error as NestAdapterError {
             throw error // Re-throw specific Nest errors
         } catch {
             print("Request Failed (fetchDevices): \(error)") // Debugging
             throw NestAdapterError.requestFailed(error)
         }
    }
    
    // Convert Nest device to abstract device
    private func convertToAbstractDevice(_ nestDevice: NestDevice) -> AbstractDevice? {
        // Basic conversion logic - needs significant expansion based on NestDevice structure
        print("Converting Nest device: \(nestDevice.name ?? "Unknown")") // Debugging
        
        // Determine device type based on traits (example: Thermostat)
        if nestDevice.traits?["sdm.devices.traits.ThermostatMode"] != nil || 
           nestDevice.traits?["sdm.devices.traits.ThermostatTemperatureSetpoint"] != nil {
            
            // --- Placeholder Thermostat Conversion --- 
            // let currentMode = (nestDevice.traits?["sdm.devices.traits.ThermostatMode"] as? [String: Any])?["mode"] as? String ?? "UNKNOWN"
            // Removed unused variables:
            // let heatSetpoint = ...
            // let coolSetpoint = ...
            // let ambientTemp = ...
            // let humidity = ...

            // Map Nest mode string to ThermostatMode enum (defined in Models/DeviceTypes.swift)
            // Removed unused variable:
            // let thermostatMode: ThermostatMode
            // switch currentMode.lowercased() {
            //     ...
            // }

             print("Thermostat conversion placeholder - Requires ThermostatDevice model implementation and uncommenting variables.")
             return nil // Placeholder until ThermostatDevice model is fully integrated

        } else {
            // Handle other device types (Lights, Cameras, etc.) based on their traits
            print("Non-thermostat device type found: \(nestDevice.type ?? "Unknown Type")")
            return nil // Placeholder for other device types
        }
    }

    // MARK: - Rate Limiting Helpers
    
    private func checkRateLimit() async throws {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        
        // Clean up old timestamps (simple approach)
        // A more robust approach might use a queue or sorted list
        if let lastReq = lastRequestTime, lastReq < oneMinuteAgo {
             requestsThisMinute = 0 // Reset if last request was > 1 min ago
         }
        
        if requestsThisMinute >= maxRequestsPerMinute {
            // Calculate wait time (simple version)
            let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime ?? Date.distantPast)
            let waitTime = max(0, 60 - timeSinceLastRequest)
            print("Rate limit potentially exceeded. Waiting for \(waitTime) seconds.") // Debugging
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            requestsThisMinute = 0 // Reset after waiting
            // Re-check after wait? Or just proceed? Simple approach: proceed.
        }
    }
    
    private func recordRequestTime() {
        lastRequestTime = Date()
        requestsThisMinute += 1
    }
}

// MARK: - Helper Response Structures for Nest API

struct NestDeviceListResponse: Decodable {
    let devices: [NestDevice]?
}

struct NestDevice: Decodable {
    let name: String? // Format: enterprises/project-id/devices/device-id
    let type: String? // e.g., "sdm.devices.types.THERMOSTAT"
    let traits: [String: AnyCodable]? // Dictionary of traits
    let parentRelations: [NestParentRelation]?
    
    // Custom coding keys if needed, especially for traits if AnyCodable causes issues
}

struct NestParentRelation: Decodable {
    let parent: String? // Format: enterprises/project-id/structures/structure-id/rooms/room-id
    let displayName: String?
}
