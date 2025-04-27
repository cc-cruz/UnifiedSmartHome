import Foundation

/// Represents a device in the system
public struct Device: Codable, Identifiable {
    public let id: String
    public let name: String
    public let manufacturerName: String?
    public let modelName: String?
    public let deviceTypeName: String?
    public let capabilities: [SmartThingsCapability]?
    public let components: [String]?
    public let status: String?
    public let healthState: String?
    public let attributes: [String: AnyCodable]?
    
    // Add CodingKeys if needed, or rely on synthesized conformance
    // Assuming synthesized conformance is sufficient for the struct
}

// ALL OTHER CLASS DEFINITIONS (LockDevice, ThermostatDevice, LightDevice) REMOVED FROM THIS FILE. 