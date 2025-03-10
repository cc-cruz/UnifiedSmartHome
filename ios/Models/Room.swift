import Foundation

struct Room: Codable, Identifiable {
    let id: String
    let name: String
    let propertyId: String
    let type: RoomType
    var deviceIds: [String]?
    
    enum RoomType: String, Codable {
        case livingRoom = "LIVING_ROOM"
        case bedroom = "BEDROOM"
        case kitchen = "KITCHEN"
        case bathroom = "BATHROOM"
        case office = "OFFICE"
        case garage = "GARAGE"
        case other = "OTHER"
    }
} 