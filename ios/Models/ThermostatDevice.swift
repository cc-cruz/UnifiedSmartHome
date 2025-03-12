import Foundation

class ThermostatDevice: SmartDeviceAdapter {
    enum ThermostatMode: String, CaseIterable, Identifiable {
        case heat
        case cool
        case auto
        case off
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            case .heat: return "Heat"
            case .cool: return "Cool"
            case .auto: return "Auto"
            case .off: return "Off"
            }
        }
        
        var iconName: String {
            switch self {
            case .heat: return "flame"
            case .cool: return "snowflake"
            case .auto: return "thermometer"
            case .off: return "power"
            }
        }
    }
    
    let id: String
    let name: String
    var currentTemperature: Double
    var targetTemperature: Double
    var mode: ThermostatMode
    let availableModes: [ThermostatMode]
    
    init(id: String, name: String, currentTemperature: Double, targetTemperature: Double, mode: ThermostatMode, availableModes: [ThermostatMode] = ThermostatMode.allCases) {
        self.id = id
        self.name = name
        self.currentTemperature = currentTemperature
        self.targetTemperature = targetTemperature
        self.mode = mode
        self.availableModes = availableModes.isEmpty ? ThermostatMode.allCases : availableModes
    }
    
    // Update the target temperature and return the state change to send to the API
    func updateTargetTemperature(to temperature: Double) -> [String: Any] {
        // Store the new target temperature
        self.targetTemperature = temperature
        
        // Create a state update to send to the API
        return [
            "targetTemperature": temperature,
            "mode": mode.rawValue
        ]
    }
    
    // Update the mode and return the state change to send to the API
    func updateMode(to newMode: ThermostatMode) -> [String: Any] {
        // Store the new mode
        self.mode = newMode
        
        // Create a state update to send to the API
        return [
            "mode": newMode.rawValue
        ]
    }
    
    // Format temperature for display
    func formattedTemperature(_ temp: Double, unit: TemperatureUnit = .celsius) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        
        let displayTemp: Double
        let symbol: String
        
        switch unit {
        case .celsius:
            displayTemp = temp
            symbol = "°C"
        case .fahrenheit:
            displayTemp = temp * 9/5 + 32
            symbol = "°F"
        }
        
        guard let formattedValue = formatter.string(from: NSNumber(value: displayTemp)) else {
            return "\(Int(displayTemp))\(symbol)"
        }
        
        return "\(formattedValue)\(symbol)"
    }
}

enum TemperatureUnit {
    case celsius
    case fahrenheit
} 