import Foundation

/// Represents a command to be executed on a smart device
struct DeviceCommand {
    /// Name of the command (e.g., "turnOn", "setBrightness", "lock")
    let name: String
    
    /// Optional parameters for the command (e.g., brightness level, color value)
    let parameters: [String: Any]
    
    init(name: String, parameters: [String: Any] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}

extension DeviceCommand {
    /// A textual description of the command for logging purposes
    var description: String {
        var desc = name
        
        if !parameters.isEmpty {
            let paramsString = parameters.map { key, value in
                return "\(key): \(value)"
            }.joined(separator: ", ")
            
            desc += " [\(paramsString)]"
        }
        
        return desc
    }
}

/// Errors that can occur during device operations
enum DeviceOperationError: Error, Equatable {
    case authenticationRequired
    case authenticationError
    case invalidDeviceId
    case deviceNotFound
    case invalidCommandParameters
    case commandExecutionFailed
    case rateLimitExceeded
    case networkError
    case serverError(statusCode: Int)
    case unsupportedCommand
    case unsupportedDeviceType
    
    // Implement Equatable for testing
    static func == (lhs: DeviceOperationError, rhs: DeviceOperationError) -> Bool {
        switch (lhs, rhs) {
        case (.authenticationRequired, .authenticationRequired),
             (.authenticationError, .authenticationError),
             (.invalidDeviceId, .invalidDeviceId),
             (.deviceNotFound, .deviceNotFound),
             (.invalidCommandParameters, .invalidCommandParameters),
             (.commandExecutionFailed, .commandExecutionFailed),
             (.rateLimitExceeded, .rateLimitExceeded),
             (.networkError, .networkError),
             (.unsupportedCommand, .unsupportedCommand),
             (.unsupportedDeviceType, .unsupportedDeviceType):
            return true
        case (.serverError(let lhsCode), .serverError(let rhsCode)):
            return lhsCode == rhsCode
        default:
            return false
        }
    }
}

/// Represents commands that can be sent to smart devices
enum DeviceCommand: Equatable {
    // Lock commands
    case lock
    case unlock
    
    // Light commands
    case turnOn
    case turnOff
    case setBrightness(Int)
    case setColor(LightColor)
    
    // Thermostat commands
    case setTemperature(Double)
    case setMode(ThermostatMode)
    
    // Generic on/off command
    case setSwitch(Bool)
}

/// Light color representation
struct LightColor: Equatable {
    let hue: Double        // 0-360
    let saturation: Double // 0-100
    let brightness: Double // 0-100
    
    init(hue: Double, saturation: Double, brightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }
}

/// Thermostat modes
enum ThermostatMode: String, Equatable {
    case cool
    case heat
    case auto
    case off
    case eco
}

/// Error types for device operations
enum DeviceOperationError: Error, LocalizedError {
    case operationFailed(String)
    case notAuthenticated
    case deviceOffline
    case networkError
    case rateLimited
    case permissionDenied
    case stateVerificationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .operationFailed(let reason):
            return "Operation failed: \(reason)"
        case .notAuthenticated:
            return "Not authenticated with device provider"
        case .deviceOffline:
            return "Device is offline"
        case .networkError:
            return "Network error communicating with device"
        case .rateLimited:
            return "Too many operations in a short period"
        case .permissionDenied:
            return "You don't have permission for this operation"
        case .stateVerificationFailed(let reason):
            return "State verification failed: \(reason)"
        }
    }
} 