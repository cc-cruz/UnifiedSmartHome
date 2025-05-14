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
    
    /// The type of device (e.g., "VIPER")
    public let type: String
    
    /// Optional manufacturer name
    public let manufacturerName: String?
    
    /// Optional device type name (more specific than type, e.g., "Smart Lock")
    public let deviceTypeName: String?
    
    /// Optional room ID
    public let roomId: String?
    
    /// Optional OCF (Open Connectivity Foundation) data
    public let ocf: OcfData?
    
    /// Device state metadata
    public let state: [String: AnyCodable]
    
    /// List of device capabilities
    public let capabilities: [String]
    
    /// Nested struct for OCF data
    public struct OcfData: Codable {
        /// Firmware version
        public let fv: String?
    }
    
    /// Coding keys to map properties to JSON fields
    private enum CodingKeys: String, CodingKey {
        case deviceId = "deviceId"
        case name
        case type
        case manufacturerName
        case deviceTypeName
        case roomId
        case ocf
        case state
        case capabilities
    }
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

public struct SmartThingsCommandResponse: Codable {
    public let status: String
    public let message: String?
} 