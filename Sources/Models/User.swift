import Foundation

public struct User: Codable, Identifiable {
    public let id: String
    public let email: String
    public let firstName: String
    public let lastName: String
    public var guestAccess: GuestAccess?

    // New properties for multi-tenancy
    public var roleAssociations: [UserRoleAssociation]?
    public var defaultPortfolioId: String?
    public var defaultPropertyId: String?
    public var defaultUnitId: String?

    public enum Role: String, Codable {
        case owner = "OWNER"                     // Owner of a Portfolio
        case propertyManager = "PROPERTY_MANAGER"  // Manager of a Property
        case tenant = "TENANT"                    // Tenant of a Unit
        case guest = "GUEST"                     // Guest with specific device access
        case portfolioAdmin = "PORTFOLIO_ADMIN"    // Admin of a Portfolio (can manage properties, managers)
    }

    public enum AssociatedEntityType: String, Codable {
        case portfolio = "PORTFOLIO"
        case property = "PROPERTY"
        case unit = "UNIT"
    }

    public struct UserRoleAssociation: Codable, Identifiable, Hashable {
        public var id = UUID().uuidString // For list identification if needed in UI
        public let associatedEntityType: AssociatedEntityType
        public let associatedEntityId: String
        public let roleWithinEntity: User.Role

        public init(associatedEntityType: AssociatedEntityType, associatedEntityId: String, roleWithinEntity: User.Role) {
            self.associatedEntityType = associatedEntityType
            self.associatedEntityId = associatedEntityId
            self.roleWithinEntity = roleWithinEntity
        }
    }

    public struct GuestAccess: Codable {
        public let validFrom: Date
        public let validUntil: Date
        public let deviceIds: [String] // Specific device IDs guest can access
        public let unitId: String?       // Optionally, guest access might be tied to a unit
        public let propertyId: String?   // Or a property (e.g. for common areas)

        public init(validFrom: Date, validUntil: Date, deviceIds: [String], unitId: String? = nil, propertyId: String? = nil) {
            self.validFrom = validFrom
            self.validUntil = validUntil
            self.deviceIds = deviceIds
            self.unitId = unitId
            self.propertyId = propertyId
        }
    }

    public var fullName: String {
        return "\(firstName) \(lastName)"
    }

    // Updated initializer
    public init(
        id: String, 
        email: String, 
        firstName: String, 
        lastName: String, 
        guestAccess: GuestAccess? = nil,
        roleAssociations: [UserRoleAssociation]? = nil,
        defaultPortfolioId: String? = nil,
        defaultPropertyId: String? = nil,
        defaultUnitId: String? = nil
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.guestAccess = guestAccess
        self.roleAssociations = roleAssociations
        self.defaultPortfolioId = defaultPortfolioId
        self.defaultPropertyId = defaultPropertyId
        self.defaultUnitId = defaultUnitId
    }

    // Convenience method to get roles for a specific property ID
    public func roles(forPropertyId propertyId: String) -> [User.Role] {
        return roleAssociations?.filter { $0.associatedEntityType == .property && $0.associatedEntityId == propertyId }
                               .map { $0.roleWithinEntity } ?? []
    }

    // Convenience method to get roles for a specific unit ID
    public func roles(forUnitId unitId: String) -> [User.Role] {
        return roleAssociations?.filter { $0.associatedEntityType == .unit && $0.associatedEntityId == unitId }
                               .map { $0.roleWithinEntity } ?? []
    }
    
    // Convenience method to get roles for a specific portfolio ID
    public func roles(forPortfolioId portfolioId: String) -> [User.Role] {
        return roleAssociations?.filter { $0.associatedEntityType == .portfolio && $0.associatedEntityId == portfolioId }
                               .map { $0.roleWithinEntity } ?? []
    }

    // Convenience method to check if user is a manager of a specific property
    public func isManager(ofPropertyId propertyId: String) -> Bool {
        return roles(forPropertyId: propertyId).contains(.propertyManager)
    }

    // Convenience method to check if user is a tenant of a specific unit
    public func isTenant(ofUnitId unitId: String) -> Bool {
        return roles(forUnitId: unitId).contains(.tenant)
    }

    // Convenience method to check if user is an owner of a specific portfolio
    public func isOwner(ofPortfolioId portfolioId: String) -> Bool {
        return roles(forPortfolioId: portfolioId).contains(.owner)
    }

    // Convenience method to check if user is an admin of a specific portfolio
    public func isPortfolioAdmin(ofPortfolioId portfolioId: String) -> Bool {
        return roles(forPortfolioId: portfolioId).contains(.portfolioAdmin)
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