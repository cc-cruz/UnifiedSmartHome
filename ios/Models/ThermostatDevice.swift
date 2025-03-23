import Foundation

public enum ThermostatMode: String, Codable, Equatable {
    case off = "OFF"
    case heat = "HEAT"
    case cool = "COOL"
    case auto = "AUTO"
    case eco = "ECO"
    case fanOnly = "FAN_ONLY"
}

public enum ThermostatFanMode: String, Codable, Equatable {
    case auto = "AUTO"
    case on = "ON"
    case circulate = "CIRCULATE"
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
}

/// Represents a thermostat device with heating and cooling capabilities
public class ThermostatDevice: AbstractDevice {
    /// Current temperature reading
    public var currentTemperature: Double?
    
    /// Target temperature setting
    public var targetTemperature: Double?
    
    /// Current mode of operation
    public var mode: ThermostatMode?
    
    /// Current humidity reading (if supported)
    public var humidity: Double?
    
    /// Whether the thermostat is currently heating
    public var isHeating: Bool
    
    /// Whether the thermostat is currently cooling
    public var isCooling: Bool
    
    /// Whether the fan is currently running
    public var isFanRunning: Bool
    
    /// Fan mode setting
    public var fanMode: ThermostatFanMode?
    
    /// Temperature range supported by the device
    public let temperatureRange: ClosedRange<Double>
    
    /// Initialize a new thermostat device
    public init(
        id: String?,
        name: String,
        manufacturer: String,
        model: String = "Thermostat",
        firmwareVersion: String? = nil,
        serviceName: String,
        isOnline: Bool = true,
        dateAdded: Date = Date(),
        metadata: [String: String] = [:],
        currentTemperature: Double? = nil,
        targetTemperature: Double? = nil,
        mode: ThermostatMode? = nil,
        humidity: Double? = nil,
        isHeating: Bool = false,
        isCooling: Bool = false,
        isFanRunning: Bool = false,
        fanMode: ThermostatFanMode? = nil,
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
            manufacturer: manufacturer,
            model: model,
            firmwareVersion: firmwareVersion,
            serviceName: serviceName,
            isOnline: isOnline,
            dateAdded: dateAdded,
            metadata: metadata
        )
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        currentTemperature = try container.decodeIfPresent(Double.self, forKey: .currentTemperature)
        targetTemperature = try container.decodeIfPresent(Double.self, forKey: .targetTemperature)
        mode = try container.decodeIfPresent(ThermostatMode.self, forKey: .mode)
        humidity = try container.decodeIfPresent(Double.self, forKey: .humidity)
        isHeating = try container.decode(Bool.self, forKey: .isHeating)
        isCooling = try container.decode(Bool.self, forKey: .isCooling)
        isFanRunning = try container.decode(Bool.self, forKey: .isFanRunning)
        fanMode = try container.decodeIfPresent(ThermostatFanMode.self, forKey: .fanMode)
        
        // Default temperature range if not provided
        let minTemp = try container.decodeIfPresent(Double.self, forKey: .minTemperature) ?? 40.0
        let maxTemp = try container.decodeIfPresent(Double.self, forKey: .maxTemperature) ?? 90.0
        temperatureRange = minTemp...maxTemp
        
        try super.init(from: decoder)
    }
    
    private enum CodingKeys: String, CodingKey {
        case currentTemperature, targetTemperature, mode, humidity
        case isHeating, isCooling, isFanRunning, fanMode
        case minTemperature, maxTemperature
    }
    
    /// Creates a copy of the thermostat device
    public override func copy() -> AbstractDevice {
        return ThermostatDevice(
            id: id,
            name: name,
            manufacturer: manufacturer,
            model: model,
            firmwareVersion: firmwareVersion,
            serviceName: serviceName,
            isOnline: isOnline,
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

enum TemperatureUnit {
    case celsius
    case fahrenheit
} 