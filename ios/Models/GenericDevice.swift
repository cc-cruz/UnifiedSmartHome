import Foundation

/// Represents a generic device that doesn't fit into specific device categories
public class GenericDevice: AbstractDevice {
    /// Capabilities supported by this device
    public var deviceCapabilities: [String]
    
    /// Custom attributes specific to this device type
    public var attributes: [String: Any]
    
    /// Initialize a new generic device
    public init(
        id: String,
        name: String,
        manufacturer: Device.Manufacturer,
        type: Device.DeviceType = .other,
        roomId: String?,
        propertyId: String,
        status: Device.DeviceStatus,
        capabilities: [Device.DeviceCapability] = [],
        deviceCapabilities: [String] = [],
        attributes: [String: Any] = [:]
    ) {
        self.deviceCapabilities = deviceCapabilities
        self.attributes = attributes
        
        super.init(
            id: id,
            name: name,
            manufacturer: manufacturer,
            type: type,
            roomId: roomId,
            propertyId: propertyId,
            status: status,
            capabilities: capabilities
        )
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        deviceCapabilities = try container.decode([String].self, forKey: .deviceCapabilities)
        
        // Decode attributes as AnyCodable dictionary, then convert to [String: Any]
        let codableAttributes = try container.decode([String: AnyCodable].self, forKey: .attributes)
        attributes = codableAttributes.mapValues { $0.value }
        
        try super.init(from: decoder)
    }
    
    private enum CodingKeys: String, CodingKey {
        case deviceCapabilities, attributes
    }
    
    /// Check if the device has a specific capability
    /// - Parameter capability: The capability to check
    /// - Returns: True if the device has the capability
    public func hasCapability(_ capability: String) -> Bool {
        return deviceCapabilities.contains(capability)
    }
    
    /// Get an attribute value
    /// - Parameter key: The attribute key
    /// - Returns: The attribute value if it exists
    public func getAttribute<T>(_ key: String) -> T? {
        return attributes[key] as? T
    }
    
    /// Creates a copy of the generic device
    public func copy() -> GenericDevice {
        return GenericDevice(
            id: id,
            name: name,
            manufacturer: manufacturer,
            type: type,
            roomId: roomId,
            propertyId: propertyId,
            status: status,
            capabilities: capabilities,
            deviceCapabilities: deviceCapabilities,
            attributes: attributes
        )
    }
} 