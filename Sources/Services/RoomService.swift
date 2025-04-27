import Foundation
import Models

// Service for managing rooms
class RoomService {
    // Shared instance
    static let shared = RoomService()
    
    // Private initializer for singleton
    private init() {}
    
    // Get all rooms (in a real app, this would fetch from an API)
    func getRooms() -> [Room] {
        // Mock data for testing
        return [
            Room(id: "room1", name: "Living Room", propertyId: "property1", type: .livingRoom, deviceIds: ["lock1", "thermostat1"]),
            Room(id: "room2", name: "Master Bedroom", propertyId: "property1", type: .bedroom, deviceIds: ["lock2"]),
            Room(id: "room3", name: "Kitchen", propertyId: "property1", type: .kitchen, deviceIds: []),
            Room(id: "room4", name: "Guest Bedroom", propertyId: "property1", type: .bedroom, deviceIds: ["lock3"]),
            Room(id: "room5", name: "Office", propertyId: "property1", type: .office, deviceIds: ["lock4"])
        ]
    }
    
    // Get a specific room by ID
    func getRoom(id: String) -> Room? {
        return getRooms().first { $0.id == id }
    }
    
    // Get rooms for a specific property
    func getRoomsForProperty(propertyId: String) -> [Room] {
        return getRooms().filter { $0.propertyId == propertyId }
    }
    
    // Get rooms that contain a specific device
    func getRoomsContainingDevice(deviceId: String) -> [Room] {
        return getRooms().filter { $0.deviceIds?.contains(deviceId) ?? false }
    }
} 