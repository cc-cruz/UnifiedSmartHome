import Foundation

public struct Property: Codable, Identifiable {
    public let id: String
    public let name: String
    public let address: Address
    public let rooms: [Room]?
    public let devices: [Device]?
    
    public struct Address: Codable {
        public let street: String
        public let city: String
        public let state: String
        public let zipCode: String
        public let country: String
        
        public init(street: String, city: String, state: String, zipCode: String, country: String) {
            self.street = street
            self.city = city
            self.state = state
            self.zipCode = zipCode
            self.country = country
        }
        
        public var formattedAddress: String {
            return "\(street), \(city), \(state) \(zipCode)"
        }
    }
    
    public init(id: String, name: String, address: Address, rooms: [Room]?, devices: [Device]?) {
        self.id = id
        self.name = name
        self.address = address
        self.rooms = rooms
        self.devices = devices
    }
} 