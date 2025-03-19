import Foundation

/// Model for thermostat devices
class ThermostatDevice: AbstractDevice {
    // MARK: - Properties
    
    /// Current temperature reading
    var currentTemperature: Double?
    
    /// Target temperature setting
    var targetTemperature: Double?
    
    /// Current mode of operation
    var mode: ThermostatMode?
    
    /// Supported modes of this thermostat
    var supportedModes: [ThermostatMode]
    
    /// Current humidity reading (if available)
    var humidity: Double?
    
    /// Whether heating is currently active
    var isHeating: Bool
    
    /// Whether cooling is currently active
    var isCooling: Bool
    
    /// Whether the fan is currently running
    var isFanRunning: Bool
    
    // MARK: - Initializers
    
    init(id: String, name: String, room: String?, manufacturer: String, model: String, 
         firmwareVersion: String, isOnline: Bool, lastSeen: Date, dateAdded: Date,
         metadata: [String: String], currentTemperature: Double?, targetTemperature: Double?) {
        
        self.currentTemperature = currentTemperature
        self.targetTemperature = targetTemperature
        self.mode = .off
        self.supportedModes = [.heat, .cool, .auto, .off]
        self.humidity = nil
        self.isHeating = false
        self.isCooling = false
        self.isFanRunning = false
        
        super.init(
            id: id,
            name: name,
            manufacturer: .other, // Default, should be mapped by adapter
            type: .thermostat,
            roomId: room,
            propertyId: "default", // Should be set by property management system
            status: isOnline ? .online : .offline,
            capabilities: []
        )
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        currentTemperature = try container.decodeIfPresent(Double.self, forKey: .currentTemperature)
        targetTemperature = try container.decodeIfPresent(Double.self, forKey: .targetTemperature)
        mode = try container.decodeIfPresent(ThermostatMode.self, forKey: .mode)
        supportedModes = try container.decode([ThermostatMode].self, forKey: .supportedModes)
        humidity = try container.decodeIfPresent(Double.self, forKey: .humidity)
        isHeating = try container.decode(Bool.self, forKey: .isHeating)
        isCooling = try container.decode(Bool.self, forKey: .isCooling)
        isFanRunning = try container.decode(Bool.self, forKey: .isFanRunning)
        
        try super.init(from: decoder)
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case currentTemperature, targetTemperature, mode, supportedModes
        case humidity, isHeating, isCooling, isFanRunning
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(currentTemperature, forKey: .currentTemperature)
        try container.encodeIfPresent(targetTemperature, forKey: .targetTemperature)
        try container.encodeIfPresent(mode, forKey: .mode)
        try container.encode(supportedModes, forKey: .supportedModes)
        try container.encodeIfPresent(humidity, forKey: .humidity)
        try container.encode(isHeating, forKey: .isHeating)
        try container.encode(isCooling, forKey: .isCooling)
        try container.encode(isFanRunning, forKey: .isFanRunning)
        
        try super.encode(to: encoder)
    }
    
    // MARK: - Copying
    
    /// Creates a copy of the thermostat device
    func copy() -> ThermostatDevice {
        return ThermostatDevice(
            id: id,
            name: name,
            room: roomId,
            manufacturer: manufacturer.rawValue,
            model: type.rawValue,
            firmwareVersion: "Unknown",
            isOnline: status == .online,
            lastSeen: Date(),
            dateAdded: Date(),
            metadata: [:],
            currentTemperature: currentTemperature,
            targetTemperature: targetTemperature,
            mode: mode,
            fanMode: fanMode,
            humidity: humidity
        )
    }
}

enum ThermostatMode: String, CaseIterable, Identifiable {
    case heat
    case cool
    case auto
    case off
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .heat: return "Heat"
        case .cool: return "Cool"
        case .auto: return "Auto"
        case .off: return "Off"
        }
    }
    
    var iconName: String {
        switch self {
        case .heat: return "flame"
        case .cool: return "snowflake"
        case .auto: return "thermometer"
        case .off: return "power"
        }
    }
}

enum TemperatureUnit {
    case celsius
    case fahrenheit
} 