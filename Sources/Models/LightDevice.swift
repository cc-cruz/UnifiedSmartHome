import Foundation

/// Represents a color for a light device with hue, saturation and brightness components
public struct LightColor: Equatable, Codable {
    /// Hue value (0-360)
    public let hue: Double
    
    /// Saturation value (0-100)
    public let saturation: Double
    
    /// Brightness value (0-100)
    public let brightness: Double
    
    /// Initialize a new light color
    public init(hue: Double, saturation: Double, brightness: Double) {
        self.hue = max(0, min(360, hue))
        self.saturation = max(0, min(100, saturation))
        self.brightness = max(0, min(100, brightness))
    }
    
    /// Create a light color from RGB values
    public static func fromRGB(red: Int, green: Int, blue: Int) -> LightColor {
        // Convert RGB to HSV
        let r = Double(red) / 255.0
        let g = Double(green) / 255.0
        let b = Double(blue) / 255.0
        
        let maxValue = max(r, max(g, b))
        let minValue = min(r, min(g, b))
        let delta = maxValue - minValue
        
        // Calculate hue
        var hue: Double = 0
        if delta != 0 {
            if maxValue == r {
                hue = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxValue == g {
                hue = 60 * ((b - r) / delta + 2)
            } else {
                hue = 60 * ((r - g) / delta + 4)
            }
        }
        
        if hue < 0 {
            hue += 360
        }
        
        // Calculate saturation
        let saturation = maxValue == 0 ? 0 : (delta / maxValue) * 100
        
        // Calculate brightness
        let brightness = maxValue * 100
        
        return LightColor(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    /// Convert color to RGB values
    public func toRGB() -> (red: Int, green: Int, blue: Int) {
        let h = hue / 60
        let s = saturation / 100
        let v = brightness / 100
        
        let c = v * s
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        
        var r, g, b: Double
        
        switch h {
        case 0..<1:
            r = c; g = x; b = 0
        case 1..<2:
            r = x; g = c; b = 0
        case 2..<3:
            r = 0; g = c; b = x
        case 3..<4:
            r = 0; g = x; b = c
        case 4..<5:
            r = x; g = 0; b = c
        case 5..<6:
            r = c; g = 0; b = x
        default:
            r = 0; g = 0; b = 0
        }
        
        let red = Int((r + m) * 255)
        let green = Int((g + m) * 255)
        let blue = Int((b + m) * 255)
        
        return (red, green, blue)
    }
    
    /// Convert to hex color string
    public func toHexString() -> String {
        let rgb = toRGB()
        return String(format: "#%02X%02X%02X", rgb.red, rgb.green, rgb.blue)
    }
}

/// Represents a smart light device with on/off state, brightness, and color capabilities
public class LightDevice: AbstractDevice {
    /// Whether the light is currently on
    @Published public var isOn: Bool
    
    /// Current brightness level (0-100) if supported
    @Published public var brightness: Double?
    
    /// Current color if the light supports color
    @Published public var color: LightColor?
    
    /// Whether the device supports color
    public let supportsColor: Bool
    
    /// Whether the device supports brightness adjustment
    public let supportsDimming: Bool
    
    /// Initialize a new light device
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
        brightness: Double? = nil,
        color: LightColor? = nil,
        supportsColor: Bool = false,
        supportsDimming: Bool = false
    ) {
        self.isOn = isOn
        self.brightness = brightness
        self.color = color
        self.supportsColor = supportsColor
        self.supportsDimming = supportsDimming
        
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

        var brightnessValue: Double? = nil
        let dimmingSupported = deviceData.capabilities.contains("switchLevel")
        if dimmingSupported {
            if let levelAnyCodable = deviceData.state["level"]?.value { // From Switch Level capability
                if let levelDouble = levelAnyCodable as? Double {
                    brightnessValue = levelDouble
                } else if let levelInt = levelAnyCodable as? Int {
                    brightnessValue = Double(levelInt)
                }
            }
        }

        var colorValue: LightColor? = nil
        let colorSupported = deviceData.capabilities.contains("colorControl")
        if colorSupported {
            // SmartThings hue and saturation are 0-100 (percent)
            // Our LightColor hue is 0-360. Brightness is 0-100.
            var huePercent: Double? = nil
            var saturationPercent: Double? = nil

            if let hueAny = deviceData.state["hue"]?.value {
                if let h = hueAny as? Double { huePercent = h }
                else if let h = hueAny as? Int { huePercent = Double(h) }
            }
            if let saturationAny = deviceData.state["saturation"]?.value {
                if let s = saturationAny as? Double { saturationPercent = s }
                else if let s = saturationAny as? Int { saturationPercent = Double(s) }
            }
            
            // If hue and saturation are present, construct LightColor
            // Brightness for LightColor can come from the main brightnessValue if available,
            // or a default if not (e.g., 100% if light is on and no specific brightness found).
            if let h = huePercent, let s = saturationPercent {
                let hueDegrees = h * 3.6 // Convert 0-100 scale to 0-360 scale
                let finalBrightness = brightnessValue ?? (isOnValue ? 100.0 : 0.0)
                colorValue = LightColor(hue: hueDegrees, saturation: s, brightness: finalBrightness)
            } else if let colorMap = deviceData.state["color"]?.value as? [String: Any] {
                // Fallback to 'color' attribute if hue/saturation direct attributes aren't there
                if let hAny = colorMap["hue"], let sAny = colorMap["saturation"] {
                    var hPercent: Double? = nil
                    var sPercent: Double? = nil
                    if let h = hAny as? Double { hPercent = h }
                    else if let h = hAny as? Int { hPercent = Double(h) }
                    if let s = sAny as? Double { sPercent = s }
                    else if let s = sAny as? Int { sPercent = Double(s) }

                    if let hVal = hPercent, let sVal = sPercent {
                        let hueDegrees = hVal * 3.6
                        let bVal = colorMap["level"] as? Double ?? brightnessValue ?? (isOnValue ? 100.0 : 0.0)
                        colorValue = LightColor(hue: hueDegrees, saturation: sVal, brightness: bVal)
                    }
                }
            }
        }
        
        self.init(
            id: id,
            name: name,
            room: deviceData.roomId ?? "Unknown",
            manufacturer: deviceData.manufacturerName ?? "Unknown",
            model: deviceData.deviceTypeName ?? deviceData.ocf?.fv ?? "Light",
            firmwareVersion: deviceData.ocf?.fv ?? "Unknown",
            isOnline: true,
            lastSeen: nil,
            dateAdded: Date(),
            metadata: [:],
            isOn: isOnValue,
            brightness: brightnessValue,
            color: colorValue,
            supportsColor: colorSupported,
            supportsDimming: dimmingSupported
        )
    }
    
    /// Turn the light on
    public func turnOn() {
        self.isOn = true
    }
    
    /// Turn the light off
    public func turnOff() {
        self.isOn = false
    }
    
    /// Set the brightness level
    /// - Parameter level: Brightness level (0-100)
    /// - Returns: True if successfully set
    public func setBrightness(_ level: Double) -> Bool {
        guard supportsDimming else { return false }
        
        let clampedLevel = max(0, min(100, level))
        self.brightness = clampedLevel
        
        // If brightness is set to 0, turn off the light
        if clampedLevel == 0 {
            isOn = false
        } else if !isOn {
            // If the light was off, turn it on when brightness is set
            isOn = true
        }
        
        return true
    }
    
    /// Set the light color
    /// - Parameter newColor: The desired color
    /// - Returns: True if successfully set
    public func setColor(_ newColor: LightColor) -> Bool {
        guard supportsColor else { return false }
        
        self.color = newColor
        
        // Update brightness from color if brightness is supported
        if supportsDimming {
            self.brightness = newColor.brightness
        }
        
        // Setting a color implies turning the light on
        if !isOn {
            isOn = true
        }
        
        return true
    }
    
    /// Creates a copy of the light device
    public func copy() -> LightDevice {
        return LightDevice(
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
            brightness: brightness,
            color: color,
            supportsColor: supportsColor,
            supportsDimming: supportsDimming
        )
    }
} 