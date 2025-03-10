import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let role: UserRole
    var properties: [Property]?
    
    enum UserRole: String, Codable {
        case owner = "OWNER"
        case propertyManager = "PROPERTY_MANAGER"
        case tenant = "TENANT"
        case guest = "GUEST"
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