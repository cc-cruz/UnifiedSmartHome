import Foundation

public struct User: Codable, Identifiable {
    public let id: String
    public let email: String
    public let firstName: String
    public let lastName: String
    public var role: Role
    public var properties: [String]
    public var assignedRooms: [String]
    public var guestAccess: GuestAccess?
    
    public enum Role: String, Codable {
        case owner = "OWNER"
        case propertyManager = "PROPERTY_MANAGER"
        case tenant = "TENANT"
        case guest = "GUEST"
    }
    
    public struct GuestAccess: Codable {
        public let validFrom: Date
        public let validUntil: Date
        public let deviceIds: [String]
        
        public init(validFrom: Date, validUntil: Date, deviceIds: [String]) {
            self.validFrom = validFrom
            self.validUntil = validUntil
            self.deviceIds = deviceIds
        }
    }
    
    public var fullName: String {
        return "\(firstName) \(lastName)"
    }
    
    public init(id: String, email: String, firstName: String, lastName: String, role: Role, properties: [String], assignedRooms: [String], guestAccess: GuestAccess? = nil) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.role = role
        self.properties = properties
        self.assignedRooms = assignedRooms
        self.guestAccess = guestAccess
    }
}

public struct LoginCredentials: Codable {
    public let email: String
    public let password: String
    
    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct AuthResponse: Codable {
    public let user: User
    public let token: String
    
    public init(user: User, token: String) {
        self.user = user
        self.token = token
    }
} 