import Foundation

struct Property: Codable, Identifiable {
    let id: String
    let name: String
    let address: Address
    let rooms: [Room]?
    let devices: [Device]?
    
    struct Address: Codable {
        let street: String
        let city: String
        let state: String
        let zipCode: String
        let country: String
        
        var formattedAddress: String {
            return "\(street), \(city), \(state) \(zipCode)"
        }
    }
} 