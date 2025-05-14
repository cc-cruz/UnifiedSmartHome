import Foundation

// Add definitions for missing group types

public struct SmartThingsGroup: Codable, Identifiable {
    public let id: String // Assuming an ID exists
    public let name: String
    // Add other relevant properties based on API documentation
}

public struct SmartThingsGroupResponse: Codable {
    // Define properties based on actual API response
    public let group: SmartThingsGroup
}

/// Request body when creating or updating a SmartThings Group
public struct SmartThingsGroupRequest: Codable {
    /// The display name of the group (required)
    public let name: String
    /// IDs of the devices that belong to this group
    public let deviceIds: [String]
    /// Optional room the group should belong to
    public let roomId: String?
}

// Request body for executing commands on a SmartThings group
public struct SmartThingsGroupCommandRequest: Codable {
    // Define properties based on command API requirements
    // Use the new Codable SmartThingsCommand struct
    public let commands: [SmartThingsCommand]
} 