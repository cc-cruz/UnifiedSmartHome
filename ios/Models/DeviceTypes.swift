import Foundation

/// Represents the state of a lock device
public enum LockState: String, Codable {
    case locked = "locked"
    case unlocked = "unlocked"
    case unknown = "unknown"
    case jammed = "jammed"
}

/// Represents the operation mode of a thermostat
public enum ThermostatMode: String, Codable {
    case heat = "heat"
    case cool = "cool"
    case auto = "auto"
    case off = "off"
    case emergencyHeat = "emergencyHeat"
}

/// Represents the fan mode of a thermostat
public enum ThermostatFanMode: String, Codable {
    case auto = "auto"
    case on = "on"
    case circulate = "circulate"
}

/// Represents a color for light devices
public struct LightColor: Codable {
    public let hue: Double
    public let saturation: Double
    public let brightness: Double
    
    public init(hue: Double, saturation: Double, brightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }
}

/// Represents a record of lock access
public struct LockAccessRecord: Codable {
    public let timestamp: Date
    public let operation: LockOperation
    public let userId: String
    public let success: Bool
    
    public enum LockOperation: String, Codable {
        case lock = "lock"
        case unlock = "unlock"
    }
    
    public init(timestamp: Date, operation: LockOperation, userId: String, success: Bool) {
        self.timestamp = timestamp
        self.operation = operation
        self.userId = userId
        self.success = success
    }
} 