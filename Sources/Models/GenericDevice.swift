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
    
    // ADDED: Convenience initializer for SmartThingsDevice data
    public convenience init?(fromDevice deviceData: SmartThingsDevice) {
        let id = deviceData.deviceId
        let name = deviceData.name

        // Convert [String: AnyCodable] to [String: Any]
        // This might lose some type information if AnyCodable was wrapping complex Codable types,
        // but for basic JSON-like values, it should be acceptable for GenericDevice.attributes.
        let rawAttributes = deviceData.state.mapValues { $0.value } 

        self.init(
            id: id,
            name: name,
            room: deviceData.roomId ?? "Unknown",
            manufacturer: deviceData.manufacturerName ?? "Unknown",
            model: deviceData.deviceTypeName ?? deviceData.ocf?.fv ?? "Generic",
            firmwareVersion: deviceData.ocf?.fv ?? "Unknown",
            capabilities: deviceData.capabilities,
            attributes: rawAttributes
        )
    }
    
    // New initializer from Models.Device
    public convenience init(fromApiDevice apiDevice: Models.Device) {
        let capabilitiesStrings = apiDevice.capabilities?.map { $0.id } ?? []
        let attributesAny = apiDevice.attributes?.mapValues { $0.value } ?? [:]
        let onlineStatus = (apiDevice.status?.uppercased() == "ONLINE")

        self.init(
            id: apiDevice.id,
            name: apiDevice.name,
            room: "Unknown Room", // Default or decide how to source this
            manufacturer: apiDevice.manufacturerName ?? "Unknown",
            model: apiDevice.modelName ?? apiDevice.deviceTypeName ?? "Unknown",
            firmwareVersion: "N/A", // Default or decide how to source this
            isOnline: onlineStatus,
            // lastSeen: Date() if online, or nil? API doesn't provide this directly.
            // dateAdded: Date(), // Or parse from API if available, else current date.
            // metadata: [:], // Or extract from apiDevice if relevant fields exist
            capabilities: capabilitiesStrings,
            attributes: attributesAny
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

    // MARK: - Codable Conformance

    private enum CodingKeys: String, CodingKey {
        case capabilities
        // Note: 'attributes: [String: Any]' is not directly Codable.
        // If attributes need to be decoded, this requires a custom solution or a type-erasing wrapper.
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.capabilities = try container.decode([String].self, forKey: .capabilities)
        // self.attributes would need custom handling here if it's to be decoded.
        // For now, initializing as empty or based on other logic if not in JSON.
        self.attributes = [:] // Or handle based on design
        try super.init(from: decoder)
    }
} 