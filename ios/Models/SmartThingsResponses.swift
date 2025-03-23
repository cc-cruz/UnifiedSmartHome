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
    
    /// The integration or brand that created the device
    public let manufacturerName: String?
    
    /// The specific model
    public let modelName: String?
    
    /// The type of device
    public let deviceTypeName: String?
    
    /// List of device capabilities
    public let capabilities: [SmartThingsCapability]?
    
    /// Components within the device
    public let components: [String]?
    
    /// Status of the device (online/offline)
    public let status: String?
    
    /// Device health check result
    public let healthState: String?
    
    /// Device state metadata
    public let attributes: [String: AnyCodable]?
    
    /// Coding keys to map properties to JSON fields
    private enum CodingKeys: String, CodingKey {
        case deviceId
        case name
        case manufacturerName
        case modelName
        case deviceTypeName = "deviceType" 
        case components
        case capabilities
        case status
        case healthState
        case attributes
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