import Foundation

/// Represents a SmartThings device capability
public struct SmartThingsCapability: Codable {
    /// Unique identifier for the capability
    public let id: String
    
    /// Version of the capability
    public let version: Int
    
    /// Status of the capability
    public let status: String?
    
    /// Attributes supported by this capability
    public let attributes: [String: AnyCodable]?
    
    /// Commands supported by this capability
    public let commands: [String]?
    
    /// Arguments required for each command
    public let commandArguments: [String: [String]]?
} 