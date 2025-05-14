import Foundation

// Lock device implementation
public class LockDevice: AbstractDevice {
    public enum LockState: String, Codable {
        case locked = "LOCKED"
        case unlocked = "UNLOCKED"
        case jammed = "JAMMED"
        case unknown = "UNKNOWN"
    }
    
    public enum LockOperation: String, Codable {
        case lock = "LOCK"
        case unlock = "UNLOCK"
        case autoLock = "AUTO_LOCK"
        case autoUnlock = "AUTO_UNLOCK"
    }
    
    private(set) public var currentState: LockState
    private(set) public var batteryLevel: Int
    private(set) public var lastStateChange: Date?
    private(set) public var isRemoteOperationEnabled: Bool
    private(set) public var accessHistory: [LockAccessRecord]
    
    public init(
        id: String,
        name: String,
        room: String,
        manufacturer: String,
        model: String,
        firmwareVersion: String,
        isOnline: Bool = true,
        lastSeen: Date? = nil,
        dateAdded: Date = Date(),
        metadata: [String: String] = [:],
        currentState: LockState,
        batteryLevel: Int,
        lastStateChange: Date?,
        isRemoteOperationEnabled: Bool,
        accessHistory: [LockAccessRecord] = []
    ) {
        self.currentState = currentState
        self.batteryLevel = batteryLevel
        self.lastStateChange = lastStateChange
        self.isRemoteOperationEnabled = isRemoteOperationEnabled
        self.accessHistory = accessHistory
        
        super.init(
            id: id,
            name: name,
            room: room,
            manufacturer: manufacturer,
            model: model,
            firmwareVersion: firmwareVersion,
            isOnline: isOnline,
            lastSeen: lastSeen,
            dateAdded: dateAdded,
            metadata: metadata
        )
    }
    
    // ADDED: Convenience initializer for SmartThingsDevice data
    public convenience init?(fromDevice deviceData: SmartThingsDevice) {
        let id = deviceData.deviceId
        let name = deviceData.name

        var lockStateValue: LockState = .unknown
        if let lockString = deviceData.state["lock"]?.value as? String {
            switch lockString.lowercased() {
            case "locked":
                lockStateValue = .locked
            case "unlocked":
                lockStateValue = .unlocked
            case "jammed":
                lockStateValue = .jammed
            default:
                lockStateValue = .unknown
            }
        } else {
            // If lock state is critical and missing, consider returning nil
            // For now, defaults to .unknown
        }

        var batteryLevelValue: Int = 0 // Default to 0 if not found or unparseable
        if let batteryAnyCodable = deviceData.state["battery"]?.value { // From Battery capability
            if let batInt = batteryAnyCodable as? Int {
                batteryLevelValue = batInt
            } else if let batDouble = batteryAnyCodable as? Double {
                batteryLevelValue = Int(batDouble)
            }
        }

        // Other properties like lastStateChange, isRemoteOperationEnabled, accessHistory
        // are not directly available from the basic SmartThingsDevice state/capabilities usually.
        // They would be managed internally by the app or require more detailed API calls.

        self.init(
            id: id,
            name: name,
            room: deviceData.roomId ?? "Unknown",
            manufacturer: deviceData.manufacturerName ?? "Unknown",
            model: deviceData.deviceTypeName ?? deviceData.ocf?.fv ?? "Lock",
            firmwareVersion: deviceData.ocf?.fv ?? "Unknown",
            currentState: lockStateValue,
            batteryLevel: batteryLevelValue,
            lastStateChange: nil, // Not typically available from basic fetch
            isRemoteOperationEnabled: true // Default, or derive from capabilities if possible
            // accessHistory: [] // Default
        )
    }
    
    // Key methods
    public func updateLockState(to state: LockState, initiatedBy userId: String) {
        self.currentState = state
        self.lastStateChange = Date()
        
        // Add to access history
        let operation: LockOperation
        switch state {
        case .locked:
            operation = .lock
        case .unlocked:
            operation = .unlock
        default:
            operation = .lock // Default for unknown states
        }
        
        let record = LockAccessRecord(
            timestamp: Date(),
            operation: operation,
            userId: userId,
            success: true
        )
        
        self.accessHistory.append(record)
    }
    
    public func updateBatteryLevel(to level: Int) {
        self.batteryLevel = min(100, max(0, level))
    }
    
    // MARK: - Copying
    
    /// Creates a copy of the lock device
    public func copy() -> LockDevice {
        let newDevice = LockDevice(
            id: id,
            name: name,
            room: room,
            manufacturer: manufacturer,
            model: model,
            firmwareVersion: firmwareVersion,
            isOnline: isOnline,
            lastSeen: lastSeen,
            dateAdded: dateAdded,
            metadata: metadata,
            currentState: currentState,
            batteryLevel: batteryLevel,
            lastStateChange: lastStateChange,
            isRemoteOperationEnabled: isRemoteOperationEnabled,
            accessHistory: accessHistory
        )
        
        return newDevice
    }
    
    // Security audit trail
    public struct LockAccessRecord: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let operation: LockOperation
        public let userId: String
        public let success: Bool
        public var failureReason: String?
        
        public init(timestamp: Date, operation: LockOperation, userId: String, success: Bool, failureReason: String? = nil) {
            self.timestamp = timestamp
            self.operation = operation
            self.userId = userId
            self.success = success
            self.failureReason = failureReason
        }
    }
    
    // Security checks
    public func canPerformRemoteOperation(by user: User) -> Bool {
        guard isRemoteOperationEnabled else { return false }
        
        switch user.role {
        case .owner, .propertyManager:
            // Owners and property managers can control all locks in their properties
            return user.properties.contains(self.metadata["propertyId"] ?? "")
        case .tenant:
            // Tenants can only control locks in their assigned units
            return user.properties.contains(self.metadata["propertyId"] ?? "") &&
                  user.assignedRooms.contains(self.room)
        case .guest:
            // Guests can only control specific locks they have access to
            guard let guestAccess = user.guestAccess else { return false }
            
            // Check if current time is within the valid access period
            let now = Date()
            guard now >= guestAccess.validFrom && now <= guestAccess.validUntil else {
                return false
            }
            
            // Check if this lock is in the allowed devices
            return guestAccess.deviceIds.contains(self.id)
        }
    }
}

// User model definition removed - now solely defined in User.swift 