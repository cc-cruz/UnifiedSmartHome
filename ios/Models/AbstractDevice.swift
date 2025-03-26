import Foundation

/// Protocol defining the interface for all smart devices in the system
public protocol AbstractDevice: Identifiable {
    /// Unique identifier for the device
    var id: String { get }
    
    /// Human readable name
    var name: String { get }
    
    /// The integration or brand that created the device
    var manufacturerName: String? { get }
    
    /// The specific model
    var modelName: String? { get }
    
    /// The type of device
    var deviceTypeName: String? { get }
    
    /// List of device capabilities
    var capabilities: [SmartThingsCapability]? { get }
    
    /// Components within the device
    var components: [String]? { get }
    
    /// Status of the device (online/offline)
    var status: String? { get }
    
    /// Device health check result
    var healthState: String? { get }
    
    /// Device state metadata
    var attributes: [String: AnyCodable]? { get }
}

/// Base implementation of AbstractDevice with common properties
public class BaseDevice: AbstractDevice {
    public let id: String
    public let name: String
    public let manufacturerName: String?
    public let modelName: String?
    public let deviceTypeName: String?
    public let capabilities: [SmartThingsCapability]?
    public let components: [String]?
    public let status: String?
    public let healthState: String?
    public let attributes: [String: AnyCodable]?
    
    public init(
        id: String,
        name: String,
        manufacturerName: String? = nil,
        modelName: String? = nil,
        deviceTypeName: String? = nil,
        capabilities: [SmartThingsCapability]? = nil,
        components: [String]? = nil,
        status: String? = nil,
        healthState: String? = nil,
        attributes: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.name = name
        self.manufacturerName = manufacturerName
        self.modelName = modelName
        self.deviceTypeName = deviceTypeName
        self.capabilities = capabilities
        self.components = components
        self.status = status
        self.healthState = healthState
        self.attributes = attributes
    }
    
    /// Creates a copy of the current device
    public func copy() -> BaseDevice {
        return BaseDevice(
            id: id,
            name: name,
            manufacturerName: manufacturerName,
            modelName: modelName,
            deviceTypeName: deviceTypeName,
            capabilities: capabilities,
            components: components,
            status: status,
            healthState: healthState,
            attributes: attributes
        )
    }
}

protocol AbstractDevice: Identifiable {
    var id: String { get }
    var name: String { get }
    var type: DeviceType { get }
    var state: [String: Any] { get }
    var capabilities: [String] { get }
}

enum DeviceType: String {
    case lock = "lock"
    case thermostat = "thermostat"
    case light = "light"
    case switch_ = "switch"
    case generic = "generic"
}

struct DeviceState {
    let deviceId: String
    let deviceType: DeviceType
    let timestamp: Date
    let attributes: [String: Any]
} 