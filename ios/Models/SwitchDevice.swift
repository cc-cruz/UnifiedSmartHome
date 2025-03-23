import Foundation

/// A smart switch device that can be turned on and off
public class SwitchDevice: AbstractDevice {
    // MARK: - Properties
    
    /// Whether the switch is currently on
    public var isOn: Bool
    
    /// Energy usage in watts (if supported)
    public var powerUsage: Double?
    
    /// Energy usage over time in kWh (if supported)
    public var energyUsage: Double?
    
    /// If the switch is scheduled to turn on/off
    public var hasSchedule: Bool
    
    /// Next scheduled state change
    public var nextScheduledChange: Date?
    
    /// The type of device this switch controls
    public let switchType: SwitchType
    
    /// Timestamp when the switch was last toggled
    public var lastToggled: Date?
    
    /// Type of device the switch controls
    public enum SwitchType: String, Codable {
        case light = "LIGHT"
        case outlet = "OUTLET"
        case fan = "FAN"
        case appliance = "APPLIANCE"
        case generic = "GENERIC"
    }
    
    // MARK: - Initializer
    
    public init(id: String?, name: String, manufacturer: String = "Generic", 
         model: String = "Smart Switch", firmwareVersion: String? = nil, 
         serviceName: String, isOnline: Bool = true, dateAdded: Date = Date(), 
         metadata: [String: String] = [:], isOn: Bool = false, powerUsage: Double? = nil, 
         energyUsage: Double? = nil, hasSchedule: Bool = false, 
         nextScheduledChange: Date? = nil, switchType: SwitchType = .generic, lastToggled: Date? = nil) {
        
        self.isOn = isOn
        self.powerUsage = powerUsage
        self.energyUsage = energyUsage
        self.hasSchedule = hasSchedule
        self.nextScheduledChange = nextScheduledChange
        self.switchType = switchType
        self.lastToggled = lastToggled
        
        super.init(id: id, name: name, manufacturer: manufacturer, model: model, 
              firmwareVersion: firmwareVersion, serviceName: serviceName, 
              isOnline: isOnline, dateAdded: dateAdded, metadata: metadata)
    }
    
    // MARK: - Methods
    
    /// Creates a copy of this device
    public override func copy() -> AbstractDevice {
        return SwitchDevice(
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
            powerUsage: powerUsage,
            energyUsage: energyUsage,
            hasSchedule: hasSchedule,
            nextScheduledChange: nextScheduledChange,
            switchType: switchType,
            lastToggled: lastToggled
        )
    }
    
    // MARK: - Coding
    
    enum CodingKeys: String, CodingKey {
        case isOn, powerUsage, energyUsage, hasSchedule, nextScheduledChange, switchType, lastToggled
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn) ?? false
        self.powerUsage = try container.decodeIfPresent(Double.self, forKey: .powerUsage)
        self.energyUsage = try container.decodeIfPresent(Double.self, forKey: .energyUsage)
        self.hasSchedule = try container.decodeIfPresent(Bool.self, forKey: .hasSchedule) ?? false
        self.nextScheduledChange = try container.decodeIfPresent(Date.self, forKey: .nextScheduledChange)
        self.switchType = try container.decode(SwitchType.self, forKey: .switchType)
        self.lastToggled = try container.decodeIfPresent(Date.self, forKey: .lastToggled)
        
        try super.init(from: decoder)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(isOn, forKey: .isOn)
        try container.encodeIfPresent(powerUsage, forKey: .powerUsage)
        try container.encodeIfPresent(energyUsage, forKey: .energyUsage)
        try container.encode(hasSchedule, forKey: .hasSchedule)
        try container.encodeIfPresent(nextScheduledChange, forKey: .nextScheduledChange)
        try container.encode(switchType, forKey: .switchType)
        try container.encodeIfPresent(lastToggled, forKey: .lastToggled)
        
        try super.encode(to: encoder)
    }
} 