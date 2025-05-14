import Foundation

/// Represents a command that can be sent to a device to change its state
public enum DeviceCommand {
    // Lock commands
    case lock
    case unlock
    
    // Thermostat commands
    case setTemperature(Double)
    case setMode(ThermostatMode)
    case setFanMode(ThermostatFanMode)
    case setHeatingSetpoint(Double)
    case setCoolingSetpoint(Double)
    
    // Light commands
    case turnOn
    case turnOff
    case setBrightness(Double) // 0-100
    case setColor(LightColor)
    
    // Switch commands
    case setSwitch(Bool)
    
    // Generic commands
    case setAttribute(key: String, value: Any)
    case executeCustomCommand(name: String, parameters: [String: Any])
}

/// Represents a single device attribute with a value and metadata
public struct DeviceAttribute {
    /// The attribute value
    public let value: Any
    
    /// When the attribute was last updated
    public let lastUpdated: Date
    
    /// Additional metadata for the attribute
    public let metadata: [String: String]
    
    /// Initializes a new device attribute
    public init(value: Any, lastUpdated: Date = Date(), metadata: [String: String] = [:]) {
        self.value = value
        self.lastUpdated = lastUpdated
        self.metadata = metadata
    }
}

/// Error types that can occur during device operations
public enum DeviceOperationError: Error {
    /// Authentication is required
    case authenticationRequired
    
    /// Authentication failed
    case authenticationError
    
    /// Invalid command parameters were provided
    case invalidCommandParameters
    
    /// The device was not found
    case deviceNotFound
    
    /// The device doesn't support the requested operation
    case unsupportedOperation
    
    /// The device type doesn't support the requested command
    case unsupportedDeviceType
    
    /// The command type is not supported
    case unsupportedCommand
    
    /// The operation was rejected due to rate limiting
    case rateLimitExceeded
    
    /// Network communication error
    case networkError
    
    /// Server returned an error
    case serverError(statusCode: Int)
    
    /// Device state couldn't be verified after operation
    case stateVerificationFailed(String)
    
    /// User doesn't have permission to perform operation
    case permissionDenied
    
    /// Biometric authentication failed
    case biometricAuthenticationFailed
    
    /// Operation was rejected due to security policy
    case securityPolicyViolation(String)
    
    /// Device is offline
    case deviceOffline
    
    /// Error message
    public var message: String {
        switch self {
        case .authenticationRequired:
            return "Authentication is required to perform this operation"
        case .authenticationError:
            return "Authentication failed"
        case .invalidCommandParameters:
            return "Invalid command parameters"
        case .deviceNotFound:
            return "Device not found"
        case .unsupportedOperation:
            return "Operation not supported by this device"
        case .unsupportedDeviceType:
            return "Device type doesn't support this command"
        case .unsupportedCommand:
            return "Command not supported"
        case .rateLimitExceeded:
            return "Rate limit exceeded, please try again later"
        case .networkError:
            return "Network communication error"
        case .serverError(let statusCode):
            return "Server error (status code: \(statusCode))"
        case .stateVerificationFailed(let reason):
            return "State verification failed: \(reason)"
        case .permissionDenied:
            return "You don't have permission to perform this operation"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        case .securityPolicyViolation(let reason):
            return "Operation rejected due to security policy: \(reason)"
        case .deviceOffline:
            return "Device is offline"
        }
    }
} 