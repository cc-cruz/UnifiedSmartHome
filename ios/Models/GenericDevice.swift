import Foundation

/// Model for generic/unrecognized device types
class GenericDevice: AbstractDevice {
    // MARK: - Initializers
    
    init(id: String, name: String, isOnline: Bool, manufacturer: String, model: String,
         firmwareVersion: String, dateAdded: Date, lastSeen: Date, metadata: [String: String]) {
        
        super.init(
            id: id,
            name: name,
            manufacturer: .other, // Default, should be mapped by adapter
            type: .other, // Generic type
            roomId: nil,
            propertyId: "default", // Should be set by property management system
            status: isOnline ? .online : .offline,
            capabilities: []
        )
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
} 