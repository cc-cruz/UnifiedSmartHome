import Foundation

public enum ThermostatMode: String, Codable {
    case off = "OFF"
    case heat = "HEAT"
    case cool = "COOL"
    case auto = "AUTO"
    case fanOnly = "FAN_ONLY"
}

public enum ThermostatFanMode: String, Codable {
    case auto = "AUTO"
    case on = "ON"
    case circulate = "CIRCULATE"
}

/// Represents a thermostat device with heating and cooling capabilities
public class ThermostatDevice: AbstractDevice {
    /// Current temperature reading
    @Published public var currentTemperature: Double?
    
    /// Target temperature setting
    @Published public var targetTemperature: Double?
    
    /// Current mode of operation
    @Published public var mode: ThermostatMode
    
    /// Current humidity reading (if supported)
    @Published public var humidity: Double?
    
    /// Whether the thermostat is currently heating
    @Published public var isHeating: Bool
    
    /// Whether the thermostat is currently cooling
    @Published public var isCooling: Bool
    
    /// Whether the fan is currently running
    @Published public var isFanRunning: Bool
    
    /// Fan mode setting
    @Published public var fanMode: ThermostatFanMode
    
    /// Temperature range supported by the device
    public let temperatureRange: ClosedRange<Double>
    
    /// Initialize a new thermostat device
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
        currentTemperature: Double? = nil,
        targetTemperature: Double? = nil,
        mode: ThermostatMode = .off,
        humidity: Double? = nil,
        isHeating: Bool = false,
        isCooling: Bool = false,
        isFanRunning: Bool = false,
        fanMode: ThermostatFanMode = .auto,
        temperatureRange: ClosedRange<Double> = 40...90
    ) {
        self.currentTemperature = currentTemperature
        self.targetTemperature = targetTemperature
        self.mode = mode
        self.humidity = humidity
        self.isHeating = isHeating
        self.isCooling = isCooling
        self.isFanRunning = isFanRunning
        self.fanMode = fanMode
        self.temperatureRange = temperatureRange
        
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
    
    /// Set a new target temperature
    /// - Parameter temperature: The desired temperature
    /// - Returns: True if the temperature was set successfully
    public func setTargetTemperature(_ temperature: Double) -> Bool {
        // Validate the temperature is within the supported range
        guard temperatureRange.contains(temperature) else {
            return false
        }
        
        targetTemperature = temperature
        return true
    }
    
    /// Set a new thermostat mode
    /// - Parameter newMode: The desired mode
    public func setMode(_ newMode: ThermostatMode) {
        mode = newMode
        
        // Reset heating/cooling status based on mode
        switch newMode {
        case .off:
            isHeating = false
            isCooling = false
        case .heat:
            isHeating = true
            isCooling = false
        case .cool:
            isHeating = false
            isCooling = true
        case .auto:
            // In auto mode, heating/cooling depends on current vs. target temp
            if let current = currentTemperature, let target = targetTemperature {
                isHeating = current < target
                isCooling = current > target
            }
        case .fanOnly:
            isHeating = false
            isCooling = false
            isFanRunning = true
        }
    }
    
    /// Set the fan mode
    /// - Parameter newMode: The desired fan mode
    public func setFanMode(_ newMode: ThermostatFanMode) {
        fanMode = newMode
        isFanRunning = newMode != .auto || isHeating || isCooling
    }
    
    /// Creates a copy of the thermostat device
    public func copy() -> ThermostatDevice {
        return ThermostatDevice(
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
            currentTemperature: currentTemperature,
            targetTemperature: targetTemperature,
            mode: mode,
            humidity: humidity,
            isHeating: isHeating,
            isCooling: isCooling,
            isFanRunning: isFanRunning,
            fanMode: fanMode,
            temperatureRange: temperatureRange
        )
    }
} 