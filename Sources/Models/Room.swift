import Foundation

public struct Room: Codable, Identifiable {
    public let id: String
    public let name: String
    public let propertyId: String
    public let type: RoomType
    public var deviceIds: [String]?
    
    public enum RoomType: String, Codable {
        case livingRoom = "LIVING_ROOM"
        case bedroom = "BEDROOM"
        case kitchen = "KITCHEN"
        case bathroom = "BATHROOM"
        case office = "OFFICE"
        case garage = "GARAGE"
        case other = "OTHER"
    }
    
    public init(id: String, name: String, propertyId: String, type: RoomType, deviceIds: [String]?) {
        self.id = id
        self.name = name
        self.propertyId = propertyId
        self.type = type
        self.deviceIds = deviceIds
    }
} 