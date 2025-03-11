import Foundation

class ThermostatDevice: AbstractDevice {
    // Thermostat-specific properties
    private(set) var currentTemperature: Double
    private(set) var targetTemperature: Double
    private(set) var mode: ThermostatMode
    private(set) var units: TemperatureUnit
    
    enum ThermostatMode: String, Codable {
        case heat = "HEAT"
        case cool = "COOL"
        case auto = "AUTO"
        case off = "OFF"
        case eco = "ECO"
    }
    
    enum TemperatureUnit: String, Codable {
        case celsius = "CELSIUS"
        case fahrenheit = "FAHRENHEIT"
    }
    
    init(id: String, name: String, manufacturer: Device.Manufacturer, roomId: String?, propertyId: String,
         status: Device.DeviceStatus, capabilities: [Device.DeviceCapability],
         currentTemperature: Double, targetTemperature: Double, mode: ThermostatMode, units: TemperatureUnit) {
        
        self.currentTemperature = currentTemperature
        self.targetTemperature = targetTemperature
        self.mode = mode
        self.units = units
        
        super.init(
            id: id,
            name: name,
            manufacturer: manufacturer,
            type: .thermostat,
            roomId: roomId,
            propertyId: propertyId,
            status: status,
            capabilities: capabilities
        )
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentTemperature = try container.decode(Double.self, forKey: .currentTemperature)
        targetTemperature = try container.decode(Double.self, forKey: .targetTemperature)
        mode = try container.decode(ThermostatMode.self, forKey: .mode)
        units = try container.decode(TemperatureUnit.self, forKey: .units)
        
        try super.init(from: decoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentTemperature, forKey: .currentTemperature)
        try container.encode(targetTemperature, forKey: .targetTemperature)
        try container.encode(mode, forKey: .mode)
        try container.encode(units, forKey: .units)
    }
    
    private enum CodingKeys: String, CodingKey {
        case currentTemperature, targetTemperature, mode, units
    }
    
    // MARK: - Thermostat Control Functions
    
    func updateTargetTemperature(to temperature: Double) -> DeviceState {
        targetTemperature = temperature
        
        // Create a DeviceState with the updated temperature
        var attributes: [String: AnyCodable] = [:]
        attributes["targetTemperature"] = AnyCodable(temperature)
        attributes["mode"] = AnyCodable(mode.rawValue)
        
        return DeviceState(isOnline: status == .online, attributes: attributes)
    }
    
    func updateMode(to newMode: ThermostatMode) -> DeviceState {
        mode = newMode
        
        // Create a DeviceState with the updated mode
        var attributes: [String: AnyCodable] = [:]
        attributes["mode"] = AnyCodable(newMode.rawValue)
        
        return DeviceState(isOnline: status == .online, attributes: attributes)
    }
    
    // Helper method to convert temperature between units
    func convertTemperature(from value: Double, sourceUnit: TemperatureUnit, targetUnit: TemperatureUnit) -> Double {
        if sourceUnit == targetUnit {
            return value
        }
        
        if sourceUnit == .celsius && targetUnit == .fahrenheit {
            return (value * 9/5) + 32
        } else {
            return (value - 32) * 5/9
        }
    }
} 