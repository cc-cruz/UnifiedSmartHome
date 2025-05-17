import Foundation

public struct Property: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public let portfolioId: String            // Link to the parent Portfolio
    public var address: PropertyAddress?
    public var managerUserIds: [String]       // IDs of users who can manage this property
    public var unitIds: [String]              // IDs of units within this property
    public var defaultTimeZone: String?       // e.g., "America/New_York"
    public var createdAt: Date?
    public var updatedAt: Date?

    public init(
        id: String,
        name: String,
        portfolioId: String,
        address: PropertyAddress? = nil,
        managerUserIds: [String] = [],
        unitIds: [String] = [],
        defaultTimeZone: String? = nil,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.id = id
        self.name = name
        self.portfolioId = portfolioId
        self.address = address
        self.managerUserIds = managerUserIds
        self.unitIds = unitIds
        self.defaultTimeZone = defaultTimeZone
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct PropertyAddress: Codable, Hashable {
    public var street: String?
    public var city: String?
    public var state: String?
    public var postalCode: String?
    public var country: String?

    public init(
        street: String? = nil,
        city: String? = nil,
        state: String? = nil,
        postalCode: String? = nil,
        country: String? = nil
    ) {
        self.street = street
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
    }
} 