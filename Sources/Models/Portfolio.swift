import Foundation

public struct Portfolio: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var administratorUserIds: [String] // IDs of users who can manage this portfolio
    public var propertyIds: [String]          // IDs of properties belonging to this portfolio
    public var createdAt: Date?
    public var updatedAt: Date?

    public init(
        id: String,
        name: String,
        administratorUserIds: [String] = [],
        propertyIds: [String] = [],
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.id = id
        self.name = name
        self.administratorUserIds = administratorUserIds
        self.propertyIds = propertyIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 