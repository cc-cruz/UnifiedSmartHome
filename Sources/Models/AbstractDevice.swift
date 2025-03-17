import Foundation

/// Base class for all smart home devices
public class AbstractDevice: Identifiable, ObservableObject {
    /// Unique identifier for the device
    public let id: String
    
    /// Human-readable name of the device
    @Published public var name: String
    
    /// The room where the device is located
    @Published public var room: String
    
    /// The manufacturer of the device
    public let manufacturer: String
    
    /// The model number or name
    public let model: String
    
    /// The firmware version running on the device
    @Published public var firmwareVersion: String
    
    /// Whether the device is currently online and reachable
    @Published public var isOnline: Bool
    
    /// Last time the device was seen online
    @Published public var lastSeen: Date?
    
    /// When the device was added to the system
    public let dateAdded: Date
    
    /// Additional metadata as key-value pairs
    public var metadata: [String: String]
    
    /// Initialize a new device
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - name: Human-readable name
    ///   - room: Location of the device
    ///   - manufacturer: Device manufacturer
    ///   - model: Model number or name
    ///   - firmwareVersion: Current firmware version
    ///   - isOnline: Whether device is reachable
    ///   - lastSeen: When device was last seen
    ///   - dateAdded: When device was added to system
    ///   - metadata: Additional device information
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
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.room = room
        self.manufacturer = manufacturer
        self.model = model
        self.firmwareVersion = firmwareVersion
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.dateAdded = dateAdded
        self.metadata = metadata
    }
    
    /// Update the device's online status
    /// - Parameter isOnline: New online status
    public func updateOnlineStatus(isOnline: Bool) {
        self.isOnline = isOnline
        if isOnline {
            self.lastSeen = Date()
        }
    }
    
    /// Update the device's firmware version
    /// - Parameter version: New firmware version
    public func updateFirmware(version: String) {
        self.firmwareVersion = version
    }
    
    /// Add or update metadata
    /// - Parameters:
    ///   - key: Metadata key
    ///   - value: Metadata value
    public func setMetadata(key: String, value: String) {
        self.metadata[key] = value
    }
    
    /// Get metadata value for key
    /// - Parameter key: Metadata key
    /// - Returns: Value if exists, nil otherwise
    public func getMetadata(key: String) -> String? {
        return self.metadata[key]
    }
} 