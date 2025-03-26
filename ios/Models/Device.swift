import Foundation

/// Represents a device in the system
public struct Device: Codable, Identifiable {
    public let id: String
    public let name: String
    public let manufacturer: DeviceManufacturer
    public let type: DeviceType
    public let roomId: String?
    public let propertyId: String
    public var status: DeviceStatus
    public var capabilities: [DeviceCapability]
    
    public struct DeviceCapability: Codable {
        public let type: String
        public let attributes: [String: AnyCodable]
    }
    
    public init(
        id: String,
        name: String,
        manufacturer: DeviceManufacturer,
        type: DeviceType,
        roomId: String? = nil,
        propertyId: String,
        status: DeviceStatus = .offline,
        capabilities: [DeviceCapability] = []
    ) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.type = type
        self.roomId = roomId
        self.propertyId = propertyId
        self.status = status
        self.capabilities = capabilities
    }
}

/// Represents a smart lock device
public class LockDevice: BaseDevice {
    /// Current state of the lock (locked/unlocked)
    public var currentState: LockState
    
    /// Battery level percentage
    public var batteryLevel: Int?
    
    /// Timestamp of last state change
    public var lastStateChange: Date?
    
    /// Whether remote operation is enabled
    public var isRemoteOperationEnabled: Bool
    
    /// History of lock access events
    public var accessHistory: [LockAccessRecord]
    
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
        attributes: [String: AnyCodable]? = nil,
        currentState: LockState = .unknown,
        batteryLevel: Int? = nil,
        lastStateChange: Date? = nil,
        isRemoteOperationEnabled: Bool = true,
        accessHistory: [LockAccessRecord] = []
    ) {
        self.currentState = currentState
        self.batteryLevel = batteryLevel
        self.lastStateChange = lastStateChange
        self.isRemoteOperationEnabled = isRemoteOperationEnabled
        self.accessHistory = accessHistory
        
        super.init(
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
    
    /// Creates a copy of the current device
    public override func copy() -> LockDevice {
        return LockDevice(
            id: id,
            name: name,
            manufacturerName: manufacturerName,
            modelName: modelName,
            deviceTypeName: deviceTypeName,
            capabilities: capabilities,
            components: components,
            status: status,
            healthState: healthState,
            attributes: attributes,
            currentState: currentState,
            batteryLevel: batteryLevel,
            lastStateChange: lastStateChange,
            isRemoteOperationEnabled: isRemoteOperationEnabled,
            accessHistory: accessHistory
        )
    }
}

/// Represents a smart thermostat device
public class ThermostatDevice: BaseDevice {
    /// Current temperature reading
    public var currentTemperature: Double?
    
    /// Target temperature setting
    public var targetTemperature: Double?
    
    /// Current operation mode
    public var mode: ThermostatMode?
    
    /// Current humidity level
    public var humidity: Double?
    
    /// Whether the heating system is active
    public var isHeating: Bool
    
    /// Whether the cooling system is active
    public var isCooling: Bool
    
    /// Whether the fan is running
    public var isFanRunning: Bool
    
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
        attributes: [String: AnyCodable]? = nil,
        currentTemperature: Double? = nil,
        targetTemperature: Double? = nil,
        mode: ThermostatMode? = nil,
        humidity: Double? = nil,
        isHeating: Bool = false,
        isCooling: Bool = false,
        isFanRunning: Bool = false
    ) {
        self.currentTemperature = currentTemperature
        self.targetTemperature = targetTemperature
        self.mode = mode
        self.humidity = humidity
        self.isHeating = isHeating
        self.isCooling = isCooling
        self.isFanRunning = isFanRunning
        
        super.init(
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
    
    /// Creates a copy of the current device
    public override func copy() -> ThermostatDevice {
        return ThermostatDevice(
            id: id,
            name: name,
            manufacturerName: manufacturerName,
            modelName: modelName,
            deviceTypeName: deviceTypeName,
            capabilities: capabilities,
            components: components,
            status: status,
            healthState: healthState,
            attributes: attributes,
            currentTemperature: currentTemperature,
            targetTemperature: targetTemperature,
            mode: mode,
            humidity: humidity,
            isHeating: isHeating,
            isCooling: isCooling,
            isFanRunning: isFanRunning
        )
    }
}

/// Represents a smart light device
public class LightDevice: BaseDevice {
    /// Current brightness level (0-100)
    public var brightness: Int?
    
    /// Current color settings
    public var color: LightColor?
    
    /// Whether the light is currently on
    public var isOn: Bool
    
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
        attributes: [String: AnyCodable]? = nil,
        brightness: Int? = nil,
        color: LightColor? = nil,
        isOn: Bool = false
    ) {
        self.brightness = brightness
        self.color = color
        self.isOn = isOn
        
        super.init(
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
    
    /// Creates a copy of the current device
    public override func copy() -> LightDevice {
        return LightDevice(
            id: id,
            name: name,
            manufacturerName: manufacturerName,
            modelName: modelName,
            deviceTypeName: deviceTypeName,
            capabilities: capabilities,
            components: components,
            status: status,
            healthState: healthState,
            attributes: attributes,
            brightness: brightness,
            color: color,
            isOn: isOn
        )
    }
}

/// Represents a smart switch device
public class SwitchDevice: BaseDevice {
    /// Whether the switch is currently on
    public var isOn: Bool
    
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
        attributes: [String: AnyCodable]? = nil,
        isOn: Bool = false
    ) {
        self.isOn = isOn
        
        super.init(
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
    
    /// Creates a copy of the current device
    public override func copy() -> SwitchDevice {
        return SwitchDevice(
            id: id,
            name: name,
            manufacturerName: manufacturerName,
            modelName: modelName,
            deviceTypeName: deviceTypeName,
            capabilities: capabilities,
            components: components,
            status: status,
            healthState: healthState,
            attributes: attributes,
            isOn: isOn
        )
    }
}

/// Represents a generic smart device
public class GenericDevice: BaseDevice {
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
        super.init(
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
    
    /// Creates a copy of the current device
    public override func copy() -> GenericDevice {
        return GenericDevice(
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