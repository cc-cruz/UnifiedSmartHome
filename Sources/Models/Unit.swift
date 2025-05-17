import Foundation

public struct Unit: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String                     // e.g., "Apartment 101", "Suite 2B"
    public let propertyId: String               // Link to the parent Property
    public var tenantUserIds: [String]          // IDs of users who are tenants of this unit
    public var deviceIds: [String]              // IDs of devices (like locks) within this unit
    public var commonAreaAccessIds: [String]?   // IDs of common areas this unit has access to (e.g. main entrance lock ID)
    public var createdAt: Date?
    public var updatedAt: Date?

    public init(
        id: String,
        name: String,
        propertyId: String,
        tenantUserIds: [String] = [],
        deviceIds: [String] = [],
        commonAreaAccessIds: [String]? = nil,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.id = id
        self.name = name
        self.propertyId = propertyId
        self.tenantUserIds = tenantUserIds
        self.deviceIds = deviceIds
        self.commonAreaAccessIds = commonAreaAccessIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 