import Foundation

/// Represents a command to be sent to the SmartThings API.
public struct SmartThingsCommand: Codable {
    /// The component on the device to target (default is "main").
    public let component: String
    
    /// The capability the command belongs to (e.g., "lock", "switchLevel").
    public let capability: String
    
    /// The specific command to execute (e.g., "lock", "unlock", "setLevel").
    public let command: String
    
    /// Optional arguments for the command.
    public let arguments: [AnyCodable]? // Use AnyCodable for flexibility

    /// Initializes a new SmartThings command.
    public init(component: String = "main", capability: String, command: String, arguments: [AnyCodable]? = nil) {
        self.component = component
        self.capability = capability
        self.command = command
        self.arguments = arguments
    }
} 