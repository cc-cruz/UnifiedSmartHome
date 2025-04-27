// This file is no longer needed as the types are defined in SmartThingsResponses.swift 

/// Request body for creating/updating a SmartThings group
public struct SmartThingsGroupRequest: Codable {
    public let name: String
    public let deviceIds: [String]
    public let roomId: String?

    // Add memberwise initializer
    public init(name: String, deviceIds: [String], roomId: String? = nil) {
        self.name = name
        self.deviceIds = deviceIds
        self.roomId = roomId
    }
}

/// Request body for creating/updating a SmartThings scene
public struct SmartThingsSceneRequest: Codable {
    public let name: String
    public let actions: [SmartThingsSceneAction]
    public let roomId: String?

    // Add memberwise initializer
    public init(name: String, actions: [SmartThingsSceneAction], roomId: String? = nil) {
        self.name = name
        self.actions = actions
        self.roomId = roomId
    }
} 