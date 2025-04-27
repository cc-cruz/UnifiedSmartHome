import Foundation

/// Scene request for creation/update
// public struct SmartThingsSceneRequest: Codable {
//     public let name: String
//     public let actions: [SmartThingsSceneAction]
//     public let roomId: String?
// }

/// Scene action definition
public struct SmartThingsSceneAction: Codable {
    public let deviceId: String
    public let component: String
    public let capability: String
    public let command: String
    public let arguments: [String: AnyCodable]?
    
    private enum CodingKeys: String, CodingKey {
        case deviceId = "deviceId"
        case component = "component"
        case capability = "capability"
        case command = "command"
        case arguments = "arguments"
    }
}

/// Scene response from API
public struct SmartThingsSceneResponse: Codable {
    public let sceneId: String
    public let name: String
    public let actions: [SmartThingsSceneAction]
    public let roomId: String?
    public let status: String
    public let createdAt: String
    public let updatedAt: String
    
    private enum CodingKeys: String, CodingKey {
        case sceneId = "sceneId"
        case name = "name"
        case actions = "actions"
        case roomId = "roomId"
        case status = "status"
        case createdAt = "createdAt"
        case updatedAt = "updatedAt"
    }
}

/// Scene execution response
public struct SmartThingsSceneExecutionResponse: Codable {
    public let status: String
    public let message: String?
    public let executionId: String?
    
    private enum CodingKeys: String, CodingKey {
        case status = "status"
        case message = "message"
        case executionId = "executionId"
    }
} 