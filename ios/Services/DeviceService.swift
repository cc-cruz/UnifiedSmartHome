import Foundation

// Service for managing devices
class DeviceService {
    // Shared instance
    static let shared = DeviceService()
    
    // Private initializer for singleton
    private init() {}
    
    // Get a device by ID (in a real app, this would fetch from an API)
    func getDevice(id: String) async throws -> AbstractDevice {
        // Mock data for testing
        let mockLocks = [
            LockDevice(
                id: "lock1",
                name: "Front Door",
                room: "Living Room",
                manufacturer: "August",
                model: "Smart Lock Pro",
                firmwareVersion: "1.2.3",
                isOnline: true,
                lastSeen: Date(),
                dateAdded: Date().addingTimeInterval(-86400 * 30), // 30 days ago
                metadata: ["color": "silver"],
                currentState: .locked,
                batteryLevel: 85,
                lastStateChange: Date().addingTimeInterval(-3600), // 1 hour ago
                isRemoteOperationEnabled: true,
                accessHistory: [
                    LockDevice.LockAccessRecord(
                        timestamp: Date().addingTimeInterval(-3600),
                        operation: .lock,
                        userId: "user1",
                        success: true
                    ),
                    LockDevice.LockAccessRecord(
                        timestamp: Date().addingTimeInterval(-7200),
                        operation: .unlock,
                        userId: "user1",
                        success: true
                    )
                ]
            ),
            LockDevice(
                id: "lock2",
                name: "Master Bedroom",
                room: "Master Bedroom",
                manufacturer: "Yale",
                model: "Assure Lock",
                firmwareVersion: "2.0.1",
                isOnline: true,
                lastSeen: Date(),
                dateAdded: Date().addingTimeInterval(-86400 * 15), // 15 days ago
                metadata: ["color": "bronze"],
                currentState: .unlocked,
                batteryLevel: 65,
                lastStateChange: Date().addingTimeInterval(-1800), // 30 minutes ago
                isRemoteOperationEnabled: true,
                accessHistory: [
                    LockDevice.LockAccessRecord(
                        timestamp: Date().addingTimeInterval(-1800),
                        operation: .unlock,
                        userId: "user2",
                        success: true
                    )
                ]
            ),
            LockDevice(
                id: "lock3",
                name: "Guest Bedroom",
                room: "Guest Bedroom",
                manufacturer: "August",
                model: "Smart Lock",
                firmwareVersion: "1.1.5",
                isOnline: false,
                lastSeen: Date().addingTimeInterval(-86400), // 1 day ago
                dateAdded: Date().addingTimeInterval(-86400 * 45), // 45 days ago
                metadata: ["color": "black"],
                currentState: .unknown,
                batteryLevel: 15,
                lastStateChange: Date().addingTimeInterval(-86400), // 1 day ago
                isRemoteOperationEnabled: true,
                accessHistory: []
            ),
            LockDevice(
                id: "lock4",
                name: "Office Door",
                room: "Office",
                manufacturer: "Yale",
                model: "Assure Lock SL",
                firmwareVersion: "2.1.0",
                isOnline: true,
                lastSeen: Date(),
                dateAdded: Date().addingTimeInterval(-86400 * 10), // 10 days ago
                metadata: ["color": "silver"],
                currentState: .locked,
                batteryLevel: 90,
                lastStateChange: Date().addingTimeInterval(-43200), // 12 hours ago
                isRemoteOperationEnabled: true,
                accessHistory: [
                    LockDevice.LockAccessRecord(
                        timestamp: Date().addingTimeInterval(-43200),
                        operation: .lock,
                        userId: "user1",
                        success: true
                    )
                ]
            )
        ]
        
        // Find the device with the matching ID
        if let device = mockLocks.first(where: { $0.id == id }) {
            return device
        }
        
        // If no device is found, throw an error
        throw DeviceServiceError.deviceNotFound
    }
    
    // Get all devices (in a real app, this would fetch from an API)
    func getAllDevices() async throws -> [AbstractDevice] {
        // In a real implementation, this would fetch from an API
        // For now, just return the device with the given ID
        let mockLocks = [
            LockDevice(
                id: "lock1",
                name: "Front Door",
                room: "Living Room",
                manufacturer: "August",
                model: "Smart Lock Pro",
                firmwareVersion: "1.2.3",
                isOnline: true,
                lastSeen: Date(),
                dateAdded: Date().addingTimeInterval(-86400 * 30), // 30 days ago
                metadata: ["color": "silver"],
                currentState: .locked,
                batteryLevel: 85,
                lastStateChange: Date().addingTimeInterval(-3600), // 1 hour ago
                isRemoteOperationEnabled: true,
                accessHistory: []
            ),
            LockDevice(
                id: "lock2",
                name: "Master Bedroom",
                room: "Master Bedroom",
                manufacturer: "Yale",
                model: "Assure Lock",
                firmwareVersion: "2.0.1",
                isOnline: true,
                lastSeen: Date(),
                dateAdded: Date().addingTimeInterval(-86400 * 15), // 15 days ago
                metadata: ["color": "bronze"],
                currentState: .unlocked,
                batteryLevel: 65,
                lastStateChange: Date().addingTimeInterval(-1800), // 30 minutes ago
                isRemoteOperationEnabled: true,
                accessHistory: []
            ),
            LockDevice(
                id: "lock3",
                name: "Guest Bedroom",
                room: "Guest Bedroom",
                manufacturer: "August",
                model: "Smart Lock",
                firmwareVersion: "1.1.5",
                isOnline: false,
                lastSeen: Date().addingTimeInterval(-86400), // 1 day ago
                dateAdded: Date().addingTimeInterval(-86400 * 45), // 45 days ago
                metadata: ["color": "black"],
                currentState: .unknown,
                batteryLevel: 15,
                lastStateChange: Date().addingTimeInterval(-86400), // 1 day ago
                isRemoteOperationEnabled: true,
                accessHistory: []
            ),
            LockDevice(
                id: "lock4",
                name: "Office Door",
                room: "Office",
                manufacturer: "Yale",
                model: "Assure Lock SL",
                firmwareVersion: "2.1.0",
                isOnline: true,
                lastSeen: Date(),
                dateAdded: Date().addingTimeInterval(-86400 * 10), // 10 days ago
                metadata: ["color": "silver"],
                currentState: .locked,
                batteryLevel: 90,
                lastStateChange: Date().addingTimeInterval(-43200), // 12 hours ago
                isRemoteOperationEnabled: true,
                accessHistory: []
            )
        ]
        
        return mockLocks
    }
}

// Error types for DeviceService
enum DeviceServiceError: Error, LocalizedError {
    case deviceNotFound
    case networkError
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Device not found"
        case .networkError:
            return "Network error occurred"
        case .serverError:
            return "Server error occurred"
        }
    }
} 