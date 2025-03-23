import Foundation

/// Represents a generic device that doesn't fit into specific device categories
public class GenericDevice: AbstractDevice {
    /// Capabilities supported by this device
    public var capabilities: [String]
    
    /// Custom attributes specific to this device type
    @Published public var attributes: [String: Any]
    
    /// Initialize a new generic device
    public init(
        id: String,
        name: String,
        room: String,
        manufacturer: String,
        model: String,
        firmwareVersion: String,
        isOnline: Bool = true,
        lastSeen: Date? = nil,
        dateAdded: Date = Date(),
        metadata: [String: String] = [:],
        capabilities: [String] = [],
        attributes: [String: Any] = [:]
    ) {
        self.capabilities = capabilities
        self.attributes = attributes
        
        super.init(
            id: id,
            name: name,
            room: room,
            manufacturer: manufacturer,
            model: model,
            firmwareVersion: firmwareVersion,
            isOnline: isOnline,
            lastSeen: lastSeen,
            dateAdded: dateAdded,
            metadata: metadata
        )
    }
    
    /// Check if the device has a specific capability
    /// - Parameter capability: The capability to check
    /// - Returns: True if the device has the capability
    public func hasCapability(_ capability: String) -> Bool {
        return capabilities.contains(capability)
    }
    
    /// Add a capability to the device
    /// - Parameter capability: The capability to add
    public func addCapability(_ capability: String) {
        if !capabilities.contains(capability) {
            capabilities.append(capability)
        }
    }
    
    /// Get an attribute value
    /// - Parameter key: The attribute key
    /// - Returns: The attribute value if it exists
    public func getAttribute<T>(_ key: String) -> T? {
        return attributes[key] as? T
    }
    
    /// Set an attribute value
    /// - Parameters:
    ///   - key: The attribute key
    ///   - value: The attribute value
    public func setAttribute<T>(_ key: String, value: T) {
        attributes[key] = value
    }
    
    /// Creates a copy of the generic device
    public func copy() -> GenericDevice {
        return GenericDevice(
            id: id,
            name: name,
            room: room,
            manufacturer: manufacturer,
            model: model,
            firmwareVersion: firmwareVersion,
            isOnline: isOnline,
            lastSeen: lastSeen,
            dateAdded: dateAdded,
            metadata: metadata,
            capabilities: capabilities,
            attributes: attributes
        )
    }
} 