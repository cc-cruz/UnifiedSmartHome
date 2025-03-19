import Foundation

/// Represents the response structure when fetching devices from SmartThings.
struct SmartThingsDevicesResponse: Decodable {
    let items: [SmartThingsDevice]
}

/// Represents an individual SmartThings device.
struct SmartThingsDevice: Decodable {
    let deviceId: String
    let name: String
    let label: String?
    let roomId: String?
    let type: String
    let components: [SmartThingsComponent]
    
    struct SmartThingsComponent: Decodable {
        let id: String
        let capabilities: [SmartThingsCapability]
    }
    
    struct SmartThingsCapability: Decodable {
        let id: String
        let version: Int?
    }
}

/// Represents the status structure for a single device.
struct SmartThingsDeviceStatusResponse: Decodable {
    let components: [String: [String: [String: SmartThingsCapabilityStatus]]]
    
    struct SmartThingsCapabilityStatus: Decodable {
        // Because values can be different types, we use AnyCodable or a similar approach.
        let value: AnyCodable
    }
}

/// Placeholder for empty command response.
struct EmptyResponse: Decodable {} 