import Foundation

/// Represents a simple switch device with on/off capability
public class SwitchDevice: AbstractDevice {
    /// Whether the switch is currently on
    @Published public var isOn: Bool
    
    /// The type of device this switch controls
    public let switchType: SwitchType
    
    /// Timestamp when the switch was last toggled
    public private(set) var lastToggled: Date?
    
    /// Type of device the switch controls
    public enum SwitchType: String, Codable {
        case light = "LIGHT"
        case outlet = "OUTLET"
        case fan = "FAN"
        case appliance = "APPLIANCE"
        case generic = "GENERIC"
    }
    
    /// Initialize a new switch device
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
        isOn: Bool = false,
        switchType: SwitchType = .generic,
        lastToggled: Date? = nil
    ) {
        self.isOn = isOn
        self.switchType = switchType
        self.lastToggled = lastToggled
        
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

        var isOnValue: Bool = false
        if let switchState = deviceData.state["switch"]?.value as? String {
            isOnValue = (switchState.lowercased() == "on")
        }

        // switchType cannot be reliably determined from basic SmartThingsDevice data without more context
        // or specific capability checks. Defaulting to .generic.
        // If deviceData.deviceTypeName or capabilities give a hint, that could be used.
        let determinedSwitchType: SwitchType = .generic
        // Example: if deviceData.capabilities.contains("fanSpeed") { determinedSwitchType = .fan }
        // This would require a more extensive mapping.

        self.init(
            id: id,
            name: name,
            room: deviceData.roomId ?? "Unknown",
            manufacturer: deviceData.manufacturerName ?? "Unknown",
            model: deviceData.deviceTypeName ?? deviceData.ocf?.fv ?? "Switch",
            firmwareVersion: deviceData.ocf?.fv ?? "Unknown",
            isOnline: true, // Default to true, as SmartThingsDevice doesn't directly provide this
            lastSeen: nil, // SmartThingsDevice doesn't directly provide this
            dateAdded: Date(), // Default to current date
            metadata: [:], // Default to empty metadata
            isOn: isOnValue,
            switchType: determinedSwitchType // Defaulting to .generic
            // lastToggled: nil // Not available from basic fetch
        )
    }
    
    // New initializer from Models.Device
    public convenience init(fromApiDevice apiDevice: Models.Device) {
        let onlineStatus = (apiDevice.status?.uppercased() == "ONLINE")

        var determinedIsOn = false
        if let switchState = apiDevice.attributes?["switch"]?.value as? String {
            determinedIsOn = (switchState.lowercased() == "on")
        } else if let switchBool = apiDevice.attributes?["switch"]?.value as? Bool {
            determinedIsOn = switchBool
        }
        
        var determinedSwitchType: SwitchType = .generic
        if let typeName = apiDevice.deviceTypeName?.lowercased() {
            if typeName.contains("light") { determinedSwitchType = .light }
            else if typeName.contains("outlet") { determinedSwitchType = .outlet }
            else if typeName.contains("fan") { determinedSwitchType = .fan }
            else if typeName.contains("appliance") { determinedSwitchType = .appliance }
        } else if let capabilities = apiDevice.capabilities?.map({ $0.id.lowercased() }) {
            if capabilities.contains("switchlevel") || capabilities.contains("colorcontrol") {
                 determinedSwitchType = .light
            } else if capabilities.contains("fancontrol") {
                 determinedSwitchType = .fan
            }
        }

        // Calls the designated initializer of SwitchDevice
        self.init(
            id: apiDevice.id,
            name: apiDevice.name,
            room: "Unknown Room", 
            manufacturer: apiDevice.manufacturerName ?? "Unknown",
            model: apiDevice.modelName ?? apiDevice.deviceTypeName ?? "Switch",
            firmwareVersion: "N/A", 
            isOnline: onlineStatus, // This comes from apiDevice.status
            // lastSeen, dateAdded, metadata will use defaults from the designated init
            isOn: determinedIsOn,
            switchType: determinedSwitchType,
            lastToggled: nil 
        )
    }
    
    /// Turn the switch on
    /// - Returns: True if state changed successfully
    public func turnOn() -> Bool {
        guard isOnline else { return false }
        
        isOn = true
        lastToggled = Date()
        return true
    }
    
    /// Turn the switch off
    /// - Returns: True if state changed successfully
    public func turnOff() -> Bool {
        guard isOnline else { return false }
        
        isOn = false
        lastToggled = Date()
        return true
    }
    
    /// Toggle the switch state
    /// - Returns: The new state after toggling
    public func toggle() -> Bool {
        guard isOnline else { return isOn }
        
        isOn.toggle()
        lastToggled = Date()
        return isOn
    }
    
    /// Set the switch to a specific state
    /// - Parameter on: The desired on/off state
    /// - Returns: True if state changed successfully
    public func setState(on: Bool) -> Bool {
        guard isOnline else { return false }
        
        if isOn != on {
            isOn = on
            lastToggled = Date()
        }
        
        return true
    }
    
    /// Creates a copy of the switch device
    public func copy() -> SwitchDevice {
        return SwitchDevice(
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
            isOn: isOn,
            switchType: switchType,
            lastToggled: lastToggled
        )
    }

    // MARK: - Codable Conformance

    private enum CodingKeys: String, CodingKey {
        case isOn, switchType, lastToggled
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isOn = try container.decode(Bool.self, forKey: .isOn)
        self.switchType = try container.decode(SwitchType.self, forKey: .switchType)
        self.lastToggled = try container.decodeIfPresent(Date.self, forKey: .lastToggled)
        
        try super.init(from: decoder)
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isOn, forKey: .isOn)
        try container.encode(switchType, forKey: .switchType)
        try container.encodeIfPresent(lastToggled, forKey: .lastToggled)
        
        try super.encode(to: encoder)
    }
} 