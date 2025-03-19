import Foundation

/// Model for basic switch devices
class SwitchDevice: AbstractDevice {
    // MARK: - Properties
    
    /// Whether the switch is currently on
    var isOn: Bool
    
    // MARK: - Initializers
    
    init(id: String, name: String, room: String?, manufacturer: String, model: String, 
         firmwareVersion: String, isOnline: Bool, lastSeen: Date, dateAdded: Date,
         metadata: [String: String], isOn: Bool) {
        
        self.isOn = isOn
        
        super.init(
            id: id,
            name: name,
            manufacturer: .other, // Default, should be mapped by adapter
            type: .other, // Switches may fall into "other" category
            roomId: room,
            propertyId: "default", // Should be set by property management system
            status: isOnline ? .online : .offline,
            capabilities: []
        )
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        isOn = try container.decode(Bool.self, forKey: .isOn)
        
        try super.init(from: decoder)
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case isOn
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(isOn, forKey: .isOn)
        
        try super.encode(to: encoder)
    }
    
    // MARK: - Copying
    
    /// Creates a copy of the switch device
    func copy() -> SwitchDevice {
        return SwitchDevice(
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
            isOn: isOn
        )
    }
} 