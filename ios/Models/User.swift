import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    var role: Role
    var properties: [String]
    var assignedRooms: [String]
    var guestAccess: GuestAccess?
    
    enum Role: String, Codable {
        case owner = "OWNER"
        case propertyManager = "PROPERTY_MANAGER"
        case tenant = "TENANT"
        case guest = "GUEST"
    }
    
    struct GuestAccess: Codable {
        let validFrom: Date
        let validUntil: Date
        let deviceIds: [String]
    }
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}

struct LoginCredentials: Codable {
    let email: String
    let password: String
}

struct AuthResponse: Codable {
    let user: User
    let token: String
} 