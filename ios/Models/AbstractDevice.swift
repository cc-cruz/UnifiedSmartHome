import Foundation

/// Base abstract class for all smart devices
public class AbstractDevice: Identifiable, Codable, Equatable {
    // MARK: - Properties
    
    /// Unique identifier for the device
    public var id: String?
    
    /// Human-readable name of the device
    public var name: String
    
    /// Manufacturer of the device
    public var manufacturer: String
    
    /// Model identifier of the device
    public var model: String
    
    /// Firmware version of the device
    public var firmwareVersion: String?
    
    /// API service this device is connected through
    public var serviceName: String
    
    /// If the device is currently online/accessible
    public var isOnline: Bool
    
    /// Date when this device was added to the system
    public var dateAdded: Date
    
    /// Additional metadata specific to the device
    public var metadata: [String: String]
    
    // MARK: - Initializer
    
    public init(id: String?, name: String, manufacturer: String, model: String, 
         firmwareVersion: String?, serviceName: String, isOnline: Bool, 
         dateAdded: Date, metadata: [String: String]) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.model = model
        self.firmwareVersion = firmwareVersion
        self.serviceName = serviceName
        self.isOnline = isOnline
        self.dateAdded = dateAdded
        self.metadata = metadata
    }
    
    // MARK: - Methods
    
    /// Creates a copy of the current device
    public func copy() -> AbstractDevice {
        return AbstractDevice(
            id: id,
            name: name,
            manufacturer: manufacturer,
            model: model,
            firmwareVersion: firmwareVersion,
            serviceName: serviceName,
            isOnline: isOnline,
            dateAdded: dateAdded,
            metadata: metadata
        )
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: AbstractDevice, rhs: AbstractDevice) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.manufacturer == rhs.manufacturer &&
               lhs.model == rhs.model &&
               lhs.firmwareVersion == rhs.firmwareVersion &&
               lhs.serviceName == rhs.serviceName &&
               lhs.isOnline == rhs.isOnline
    }
} 