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
        var determinedSwitchType: SwitchType = .generic
        // Example: if deviceData.capabilities.contains("fanSpeed") { determinedSwitchType = .fan }
        // This would require a more extensive mapping.

        self.init(
            id: id,
            name: name,
            room: deviceData.roomId ?? "Unknown",
            manufacturer: deviceData.manufacturerName ?? "Unknown",
            model: deviceData.deviceTypeName ?? deviceData.ocf?.fv ?? "Switch",
            firmwareVersion: deviceData.ocf?.fv ?? "Unknown",
            isOn: isOnValue,
            switchType: determinedSwitchType // Defaulting to .generic
            // lastToggled: nil // Not available from basic fetch
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
} 