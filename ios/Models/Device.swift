import Foundation

struct Device: Codable, Identifiable {
    let id: String
    let name: String
    let manufacturer: Manufacturer
    let type: DeviceType
    let roomId: String?
    let propertyId: String
    var status: DeviceStatus
    var capabilities: [DeviceCapability]
    
    enum Manufacturer: String, Codable {
        case samsung = "SAMSUNG"
        case lg = "LG"
        case ge = "GE"
        case googleNest = "GOOGLE_NEST"
        case philipsHue = "PHILIPS_HUE"
        case amazon = "AMAZON"
        case apple = "APPLE"
        case other = "OTHER"
    }
    
    enum DeviceType: String, Codable {
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
    
    enum DeviceStatus: String, Codable {
        case online = "ONLINE"
        case offline = "OFFLINE"
        case error = "ERROR"
    }
    
    struct DeviceCapability: Codable {
        let type: String
        let attributes: [String: AnyCodable]
    }
}

// Helper structure to handle dynamic values in JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self.value = value
        } else if let value = try? container.decode([AnyCodable].self) {
            self.value = value
        } else if container.decodeNil() {
            self.value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let value as String:
            try container.encode(value)
        case let value as Int:
            try container.encode(value)
        case let value as Double:
            try container.encode(value)
        case let value as Bool:
            try container.encode(value)
        case let value as [String: AnyCodable]:
            try container.encode(value)
        case let value as [AnyCodable]:
            try container.encode(value)
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable cannot encode value")
            )
        }
    }
} 