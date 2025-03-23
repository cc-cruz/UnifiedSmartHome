import Foundation

/// Represents color data for a color-capable light
public struct LightColor: Codable, Equatable {
    /// Hue value (0-360)
    public let hue: Double
    
    /// Saturation value (0-100)
    public let saturation: Double
    
    /// Brightness value (0-100)
    public let brightness: Double
    
    public init(hue: Double, saturation: Double, brightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }
    
    /// Convert HSB to RGB values
    public func toRGB() -> (red: Int, green: Int, blue: Int) {
        let h = hue / 60.0
        let s = saturation / 100.0
        let b = brightness / 100.0
        
        let c = b * s
        let x = c * (1 - abs(fmod(h, 2) - 1))
        let m = b - c
        
        var r: Double = 0
        var g: Double = 0
        var b2: Double = 0
        
        if h >= 0 && h < 1 {
            r = c
            g = x
            b2 = 0
        } else if h >= 1 && h < 2 {
            r = x
            g = c
            b2 = 0
        } else if h >= 2 && h < 3 {
            r = 0
            g = c
            b2 = x
        } else if h >= 3 && h < 4 {
            r = 0
            g = x
            b2 = c
        } else if h >= 4 && h < 5 {
            r = x
            g = 0
            b2 = c
        } else {
            r = c
            g = 0
            b2 = x
        }
        
        let red = Int(round((r + m) * 255))
        let green = Int(round((g + m) * 255))
        let blue = Int(round((b2 + m) * 255))
        
        return (red, green, blue)
    }
}

/// A smart light device that can be controlled
public class LightDevice: AbstractDevice {
    // MARK: - Properties
    
    /// Whether the light is on or off
    public var isOn: Bool
    
    /// Current brightness level (0-100)
    public var brightness: Int?
    
    /// Current color settings (if the light supports color)
    public var color: LightColor?
    
    /// Whether the light supports dimming
    public var supportsDimming: Bool
    
    /// Whether the light supports color changing
    public var supportsColor: Bool
    
    /// Whether the light supports color temperature
    public var supportsTemperature: Bool
    
    /// Color temperature in Kelvin (if supported)
    public var colorTemperature: Int?
    
    /// Minimum supported color temperature
    public var minColorTemperature: Int?
    
    /// Maximum supported color temperature
    public var maxColorTemperature: Int?
    
    // MARK: - Initializer
    
    public init(id: String?, name: String, manufacturer: String = "Generic", 
         model: String = "Smart Light", firmwareVersion: String? = nil, 
         serviceName: String, isOnline: Bool = true, dateAdded: Date = Date(), 
         metadata: [String: String] = [:], isOn: Bool = false, brightness: Int? = nil, 
         color: LightColor? = nil, supportsDimming: Bool = false, 
         supportsColor: Bool = false, supportsTemperature: Bool = false, 
         colorTemperature: Int? = nil, minColorTemperature: Int? = nil, 
         maxColorTemperature: Int? = nil) {
        
        self.isOn = isOn
        self.brightness = brightness
        self.color = color
        self.supportsDimming = supportsDimming
        self.supportsColor = supportsColor
        self.supportsTemperature = supportsTemperature
        self.colorTemperature = colorTemperature
        self.minColorTemperature = minColorTemperature
        self.maxColorTemperature = maxColorTemperature
        
        super.init(id: id, name: name, manufacturer: manufacturer, model: model, 
              firmwareVersion: firmwareVersion, serviceName: serviceName, 
              isOnline: isOnline, dateAdded: dateAdded, metadata: metadata)
    }
    
    // MARK: - Methods
    
    /// Creates a copy of this device
    public override func copy() -> AbstractDevice {
        return LightDevice(
            id: id,
            name: name,
            manufacturer: manufacturer,
            model: model,
            firmwareVersion: firmwareVersion,
            serviceName: serviceName,
            isOnline: isOnline,
            dateAdded: dateAdded,
            metadata: metadata,
            isOn: isOn,
            brightness: brightness,
            color: color,
            supportsDimming: supportsDimming,
            supportsColor: supportsColor,
            supportsTemperature: supportsTemperature,
            colorTemperature: colorTemperature,
            minColorTemperature: minColorTemperature,
            maxColorTemperature: maxColorTemperature
        )
    }
    
    // MARK: - Coding
    
    enum CodingKeys: String, CodingKey {
        case isOn, brightness, color, supportsDimming, supportsColor
        case supportsTemperature, colorTemperature, minColorTemperature, maxColorTemperature
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn) ?? false
        self.brightness = try container.decodeIfPresent(Int.self, forKey: .brightness)
        self.color = try container.decodeIfPresent(LightColor.self, forKey: .color)
        self.supportsDimming = try container.decodeIfPresent(Bool.self, forKey: .supportsDimming) ?? false
        self.supportsColor = try container.decodeIfPresent(Bool.self, forKey: .supportsColor) ?? false
        self.supportsTemperature = try container.decodeIfPresent(Bool.self, forKey: .supportsTemperature) ?? false
        self.colorTemperature = try container.decodeIfPresent(Int.self, forKey: .colorTemperature)
        self.minColorTemperature = try container.decodeIfPresent(Int.self, forKey: .minColorTemperature)
        self.maxColorTemperature = try container.decodeIfPresent(Int.self, forKey: .maxColorTemperature)
        
        try super.init(from: decoder)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(isOn, forKey: .isOn)
        try container.encodeIfPresent(brightness, forKey: .brightness)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encode(supportsDimming, forKey: .supportsDimming)
        try container.encode(supportsColor, forKey: .supportsColor)
        try container.encode(supportsTemperature, forKey: .supportsTemperature)
        try container.encodeIfPresent(colorTemperature, forKey: .colorTemperature)
        try container.encodeIfPresent(minColorTemperature, forKey: .minColorTemperature)
        try container.encodeIfPresent(maxColorTemperature, forKey: .maxColorTemperature)
        
        try super.encode(to: encoder)
    }
} 