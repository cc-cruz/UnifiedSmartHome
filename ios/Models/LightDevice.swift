import Foundation

/// Model for light devices
class LightDevice: AbstractDevice {
    // MARK: - Properties
    
    /// Current brightness level (0-100)
    var brightness: Int?
    
    /// Current color (if supported)
    var color: LightColor?
    
    /// Whether the light is currently on
    var isOn: Bool
    
    /// Whether the device supports color
    var supportsColor: Bool {
        return color != nil
    }
    
    /// Whether the device supports brightness adjustment
    var supportsBrightness: Bool {
        return brightness != nil
    }
    
    // MARK: - Initializers
    
    init(id: String, name: String, room: String?, manufacturer: String, model: String, 
         firmwareVersion: String, isOnline: Bool, lastSeen: Date, dateAdded: Date,
         metadata: [String: String], brightness: Int?, color: LightColor?, isOn: Bool) {
        
        self.brightness = brightness
        self.color = color
        self.isOn = isOn
        
        super.init(
            id: id,
            name: name,
            manufacturer: .other, // Default, should be mapped by adapter
            type: .light,
            roomId: room,
            propertyId: "default", // Should be set by property management system
            status: isOnline ? .online : .offline,
            capabilities: []
        )
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        brightness = try container.decodeIfPresent(Int.self, forKey: .brightness)
        color = try container.decodeIfPresent(LightColor.self, forKey: .color)
        isOn = try container.decode(Bool.self, forKey: .isOn)
        
        try super.init(from: decoder)
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case brightness, color, isOn
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(brightness, forKey: .brightness)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encode(isOn, forKey: .isOn)
        
        try super.encode(to: encoder)
    }
    
    // MARK: - Copying
    
    /// Creates a copy of the light device
    func copy() -> LightDevice {
        return LightDevice(
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
            brightness: brightness,
            color: color,
            isOn: isOn
        )
    }
} 