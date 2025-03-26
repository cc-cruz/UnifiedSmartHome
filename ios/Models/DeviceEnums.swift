import Foundation

/// Represents the type of a device
public enum DeviceType: String, Codable {
    case light = "LIGHT"
    case thermostat = "THERMOSTAT"
    case lock = "LOCK"
    case camera = "CAMERA"
    case doorbell = "DOORBELL"
    case speaker = "SPEAKER"
    case tv = "TV"
    case appliance = "APPLIANCE"
    case sensor = "SENSOR"
    case other = "OTHER"
}

/// Represents the manufacturer of a device
public enum DeviceManufacturer: String, Codable {
    case samsung = "SAMSUNG"
    case lg = "LG"
    case ge = "GE"
    case googleNest = "GOOGLE_NEST"
    case philipsHue = "PHILIPS_HUE"
    case amazon = "AMAZON"
    case apple = "APPLE"
    case other = "OTHER"
}

/// Represents the status of a device
public enum DeviceStatus: String, Codable {
    case online = "ONLINE"
    case offline = "OFFLINE"
    case error = "ERROR"
} 