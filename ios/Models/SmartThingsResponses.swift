import Foundation

/// Response from the SmartThings API when fetching devices
public struct SmartThingsDevicesResponse: Codable {
    /// List of devices returned by the API
    public let items: [SmartThingsDevice]
    
    /// Data about the API request
    public let _links: Links?
    
    public struct Links: Codable {
        public let next: Link?
        public let previous: Link?
        
        public struct Link: Codable {
            public let href: String
        }
    }
}

/// Individual SmartThings device data
public struct SmartThingsDevice: Codable {
    /// Device identifier
    public let deviceId: String
    
    /// Human readable name
    public let name: String
    
    /// The type of device
    public let type: String
    
    /// Device state metadata
    public let state: [String: Any]
    
    /// List of device capabilities
    public let capabilities: [String]
    
    /// Coding keys to map properties to JSON fields
    private enum CodingKeys: String, CodingKey {
        case deviceId = "deviceId"
        case name = "name"
        case type = "type"
        case state = "state"
        case capabilities = "capabilities"
    }
}

/// Device capability description
public struct SmartThingsCapability: Codable {
    /// Capability ID
    public let id: String
    
    /// Capability version
    public let version: Int?
    
    /// Capability status
    public let status: String?
}

/// Response from the SmartThings API when fetching device status
public struct SmartThingsDeviceStatusResponse: Codable {
    /// Device components with their statuses
    public let components: [String: [String: [String: SmartThingsStateValue]]]
    
    /// Device health information
    public let healthState: HealthState?
    
    /// Device health struct
    public struct HealthState: Codable {
        public let state: String
        public let lastUpdatedDate: String
    }
}

/// State value from SmartThings API
public struct SmartThingsStateValue: Codable {
    /// The value itself
    public let value: AnyCodable
    
    /// When the value was last updated
    public let timestamp: String?
    
    /// Unit for the value (e.g., "F" for temperature)
    public let unit: String?
    
    /// Data for the value
    public let data: AnyCodable?
}

struct SmartThingsCommandResponse: Codable {
    let status: String
    let message: String?
} 