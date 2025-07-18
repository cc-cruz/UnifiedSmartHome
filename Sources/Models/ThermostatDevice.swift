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
    
    // REVISED: Convenience initializer for SmartThingsDevice data using documented attributes
    public convenience init?(fromDevice deviceData: SmartThingsDevice) {
        // Essential info from SmartThingsDevice itself
        let id = deviceData.deviceId
        let name = deviceData.name

        // Parse thermostat-specific states from deviceData.state using documented capability attribute names
        var currentTemperatureValue: Double? = nil
        if let tempAnyCodable = deviceData.state["temperature"]?.value {
            if let tempDouble = tempAnyCodable as? Double {
                currentTemperatureValue = tempDouble
            } else if let tempInt = tempAnyCodable as? Int {
                currentTemperatureValue = Double(tempInt)
            }
        }

        // For target temperature, SmartThings might use heatingSetpoint and coolingSetpoint primarily.
        // thermostatSetpoint can be a general one.
        // We'll prioritize specific ones if available, then fall back.
        var targetTemperatureValue: Double? = nil
        if let heatingSet = deviceData.state["heatingSetpoint"]?.value as? Double {
            targetTemperatureValue = heatingSet // Could also store coolingSetpoint separately if model supports dual setpoints
        } else if let coolingSet = deviceData.state["coolingSetpoint"]?.value as? Double {
            targetTemperatureValue = coolingSet // Or average, or prioritize based on mode
        } else if let generalSet = deviceData.state["thermostatSetpoint"]?.value as? Double {
            targetTemperatureValue = generalSet
        } else if let heatingSetInt = deviceData.state["heatingSetpoint"]?.value as? Int {
            targetTemperatureValue = Double(heatingSetInt)
        } else if let coolingSetInt = deviceData.state["coolingSetpoint"]?.value as? Int {
            targetTemperatureValue = Double(coolingSetInt)
        } else if let generalSetInt = deviceData.state["thermostatSetpoint"]?.value as? Int {
            targetTemperatureValue = Double(generalSetInt)
        }

        var modeValue: ThermostatMode = .off // Default to off
        if let modeString = deviceData.state["thermostatMode"]?.value as? String,
           let parsedMode = ThermostatMode(rawValue: modeString.uppercased()) {
            modeValue = parsedMode
        } else {
            // If thermostatMode is critical and missing/unparseable, consider returning nil
            // For now, we default to .off. If .off isn't a universally safe default, 
            // and a thermostat *must* have a mode, then: guard let modeString = ... else { return nil }
        }

        var fanModeValue: ThermostatFanMode = .auto // Default to auto
        if let fanModeString = deviceData.state["thermostatFanMode"]?.value as? String,
           let parsedFanMode = ThermostatFanMode(rawValue: fanModeString.uppercased()) {
            fanModeValue = parsedFanMode
        }
        
        var humidityValue: Double? = nil
        if let humidityAnyCodable = deviceData.state["humidity"]?.value { // From Relative Humidity Measurement
            if let humDouble = humidityAnyCodable as? Double {
                humidityValue = humDouble
            } else if let humInt = humidityAnyCodable as? Int {
                humidityValue = Double(humInt)
            }
        }

        var isHeatingValue: Bool = false
        var isCoolingValue: Bool = false
        if let opStateString = deviceData.state["thermostatOperatingState"]?.value as? String {
            let opStateLower = opStateString.lowercased()
            isHeatingValue = (opStateLower == "heating" || opStateLower == "pending heat")
            isCoolingValue = (opStateLower == "cooling" || opStateLower == "pending cool")
        }
        
        var isFanRunningValue: Bool = false
        if let fanOpStateString = deviceData.state["thermostatOperatingState"]?.value as? String {
             isFanRunningValue = (fanOpStateString.lowercased() == "fan only")
        } else if fanModeValue != .auto { // If explicit fan mode is on/circulate, assume fan is running
            isFanRunningValue = true
        }

        self.init(
            id: id,
            name: name,
            room: deviceData.roomId ?? "Unknown",
            manufacturer: deviceData.manufacturerName ?? "Unknown",
            model: deviceData.deviceTypeName ?? deviceData.ocf?.fv ?? "Thermostat", // Prefer deviceTypeName
            firmwareVersion: deviceData.ocf?.fv ?? "Unknown",
            currentTemperature: currentTemperatureValue,
            targetTemperature: targetTemperatureValue,
            mode: modeValue,
            humidity: humidityValue,
            isHeating: isHeatingValue,
            isCooling: isCoolingValue,
            isFanRunning: isFanRunningValue,
            fanMode: fanModeValue
            // temperatureRange would ideally come from capabilities or device presentation info
        )
    }
    
    // New initializer from Models.Device
    public convenience init(fromApiDevice apiDevice: Models.Device) {
        let onlineStatus = (apiDevice.status?.uppercased() == "ONLINE")

        // Extract thermostat-specific attributes
        var currentTempValue: Double? = nil
        if let tempAny = apiDevice.attributes?["temperature"]?.value {
            if let tempD = tempAny as? Double { currentTempValue = tempD }
            else if let tempI = tempAny as? Int { currentTempValue = Double(tempI) }
            else if let tempS = tempAny as? String, let tempDFromS = Double(tempS) { currentTempValue = tempDFromS }
        }

        var targetTempValue: Double? = nil
        // Prefer specific setpoints, then general setpoint
        if let heatSetAny = apiDevice.attributes?["heatingSetpoint"]?.value {
            if let tempD = heatSetAny as? Double { targetTempValue = tempD }
            else if let tempI = heatSetAny as? Int { targetTempValue = Double(tempI) }
            else if let tempS = heatSetAny as? String, let tempDFromS = Double(tempS) { targetTempValue = tempDFromS }
        } else if let coolSetAny = apiDevice.attributes?["coolingSetpoint"]?.value {
            if let tempD = coolSetAny as? Double { targetTempValue = tempD } 
            else if let tempI = coolSetAny as? Int { targetTempValue = Double(tempI) }
            else if let tempS = coolSetAny as? String, let tempDFromS = Double(tempS) { targetTempValue = tempDFromS }
        } else if let generalSetAny = apiDevice.attributes?["thermostatSetpoint"]?.value {
            if let tempD = generalSetAny as? Double { targetTempValue = tempD }
            else if let tempI = generalSetAny as? Int { targetTempValue = Double(tempI) }
            else if let tempS = generalSetAny as? String, let tempDFromS = Double(tempS) { targetTempValue = tempDFromS }
        }

        var modeValue: ThermostatMode = .off
        if let modeStr = apiDevice.attributes?["thermostatMode"]?.value as? String {
            modeValue = ThermostatMode(rawValue: modeStr.uppercased()) ?? .off
        }

        var fanModeValue: ThermostatFanMode = .auto
        if let fanModeStr = apiDevice.attributes?["thermostatFanMode"]?.value as? String {
            fanModeValue = ThermostatFanMode(rawValue: fanModeStr.uppercased()) ?? .auto
        }

        var humidityValue: Double? = nil
        if let humidityAny = apiDevice.attributes?["humidity"]?.value {
            if let humD = humidityAny as? Double { humidityValue = humD }
            else if let humI = humidityAny as? Int { humidityValue = Double(humI) }
            else if let humS = humidityAny as? String, let humDFromS = Double(humS) { humidityValue = humDFromS }
        }
        
        var heatingState = false
        var coolingState = false
        var fanRunningState = false
        if let opStateStr = apiDevice.attributes?["thermostatOperatingState"]?.value as? String {
            let opStateLower = opStateStr.lowercased()
            heatingState = opStateLower == "heating" || opStateLower == "pending heat"
            coolingState = opStateLower == "cooling" || opStateLower == "pending cool"
            fanRunningState = opStateLower == "fan only"
        } else if fanModeValue != .auto { // if fan is explicitly on or circulate
             fanRunningState = true
        }

        self.init(
            id: apiDevice.id,
            name: apiDevice.name,
            room: "Unknown Room", // Default
            manufacturer: apiDevice.manufacturerName ?? "Unknown",
            model: apiDevice.modelName ?? apiDevice.deviceTypeName ?? "Thermostat",
            firmwareVersion: "N/A", // Default
            isOnline: onlineStatus,
            currentTemperature: currentTempValue,
            targetTemperature: targetTempValue,
            mode: modeValue,
            humidity: humidityValue,
            isHeating: heatingState,
            isCooling: coolingState,
            isFanRunning: fanRunningState,
            fanMode: fanModeValue
            // temperatureRange: default is 40...90. API might provide this in capabilities/details not in Models.Device struct
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

    // MARK: - Codable Conformance

    private enum CodingKeys: String, CodingKey {
        case currentTemperature, targetTemperature, mode, humidity, isHeating, isCooling, isFanRunning, fanMode, temperatureRange
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.currentTemperature = try container.decodeIfPresent(Double.self, forKey: .currentTemperature)
        self.targetTemperature = try container.decodeIfPresent(Double.self, forKey: .targetTemperature)
        self.mode = try container.decode(ThermostatMode.self, forKey: .mode)
        self.humidity = try container.decodeIfPresent(Double.self, forKey: .humidity)
        self.isHeating = try container.decode(Bool.self, forKey: .isHeating)
        self.isCooling = try container.decode(Bool.self, forKey: .isCooling)
        self.isFanRunning = try container.decode(Bool.self, forKey: .isFanRunning)
        self.fanMode = try container.decode(ThermostatFanMode.self, forKey: .fanMode)
        self.temperatureRange = try container.decode(ClosedRange<Double>.self, forKey: .temperatureRange)
        
        try super.init(from: decoder)
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(currentTemperature, forKey: .currentTemperature)
        try container.encodeIfPresent(targetTemperature, forKey: .targetTemperature)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(humidity, forKey: .humidity)
        try container.encode(isHeating, forKey: .isHeating)
        try container.encode(isCooling, forKey: .isCooling)
        try container.encode(isFanRunning, forKey: .isFanRunning)
        try container.encode(fanMode, forKey: .fanMode)
        try container.encode(temperatureRange, forKey: .temperatureRange)
        
        try super.encode(to: encoder)
    }
} 