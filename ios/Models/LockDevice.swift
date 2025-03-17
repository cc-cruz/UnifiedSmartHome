import Foundation

class LockDevice: AbstractDevice {
    enum LockState: String, Codable {
        case locked = "LOCKED"
        case unlocked = "UNLOCKED"
        case jammed = "JAMMED"
        case unknown = "UNKNOWN"
    }
    
    enum LockOperation: String, Codable {
        case lock = "LOCK"
        case unlock = "UNLOCK"
    }
    
    private(set) var currentState: LockState
    private(set) var batteryLevel: Int // 0-100
    private(set) var lastStateChange: Date?
    private(set) var isRemoteOperationEnabled: Bool
    
    // Access history for security audit
    private(set) var accessHistory: [LockAccessRecord]
    
    init(id: String, name: String, manufacturer: Device.Manufacturer, 
         roomId: String?, propertyId: String, status: Device.DeviceStatus,
         capabilities: [Device.DeviceCapability], currentState: LockState,
         batteryLevel: Int, lastStateChange: Date?, isRemoteOperationEnabled: Bool,
         accessHistory: [LockAccessRecord] = []) {
        
        self.currentState = currentState
        self.batteryLevel = batteryLevel
        self.lastStateChange = lastStateChange
        self.isRemoteOperationEnabled = isRemoteOperationEnabled
        self.accessHistory = accessHistory
        
        super.init(
            id: id,
            name: name,
            manufacturer: manufacturer,
            type: .lock,
            roomId: roomId,
            propertyId: propertyId,
            status: status,
            capabilities: capabilities
        )
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentState = try container.decode(LockState.self, forKey: .currentState)
        batteryLevel = try container.decode(Int.self, forKey: .batteryLevel)
        lastStateChange = try container.decodeIfPresent(Date.self, forKey: .lastStateChange)
        isRemoteOperationEnabled = try container.decode(Bool.self, forKey: .isRemoteOperationEnabled)
        accessHistory = try container.decodeIfPresent([LockAccessRecord].self, forKey: .accessHistory) ?? []
        
        try super.init(from: decoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentState, forKey: .currentState)
        try container.encode(batteryLevel, forKey: .batteryLevel)
        try container.encodeIfPresent(lastStateChange, forKey: .lastStateChange)
        try container.encode(isRemoteOperationEnabled, forKey: .isRemoteOperationEnabled)
        try container.encode(accessHistory, forKey: .accessHistory)
    }
    
    private enum CodingKeys: String, CodingKey {
        case currentState, batteryLevel, lastStateChange, isRemoteOperationEnabled, accessHistory
    }
    
    // Key methods
    func updateLockState(to state: LockState, initiatedBy userId: String) -> DeviceState {
        self.currentState = state
        self.lastStateChange = Date()
        
        // Record access history
        let accessRecord = LockAccessRecord(
            timestamp: Date(),
            operation: state == .locked ? .lock : .unlock,
            userId: userId,
            success: true
        )
        self.accessHistory.append(accessRecord)
        
        // Return device state for adapter
        var attributes: [String: AnyCodable] = [:]
        attributes["lockState"] = AnyCodable(state.rawValue)
        
        return DeviceState(isOnline: status == .online, attributes: attributes)
    }
    
    // Battery monitoring
    func updateBatteryLevel(_ level: Int) {
        self.batteryLevel = min(100, max(0, level))
    }
    
    // Security audit trail
    struct LockAccessRecord: Codable, Identifiable {
        let id = UUID()
        let timestamp: Date
        let operation: LockOperation
        let userId: String
        let success: Bool
        let failureReason: String?
        
        init(timestamp: Date, operation: LockOperation, userId: String, success: Bool, failureReason: String? = nil) {
            self.timestamp = timestamp
            self.operation = operation
            self.userId = userId
            self.success = success
            self.failureReason = failureReason
        }
    }
    
    // Security checks
    func canPerformRemoteOperation(by user: User) -> Bool {
        guard isRemoteOperationEnabled else { return false }
        
        // Check if user has appropriate role
        switch user.role {
        case .owner, .propertyManager:
            return true
        case .tenant:
            // Tenants can only control locks in their assigned units
            guard let roomId = self.roomId else { return false }
            return user.properties.contains(where: { $0.id == self.propertyId }) &&
                  user.assignedRooms.contains(roomId)
        case .guest:
            // Guests have time-limited access
            guard let guestAccess = user.guestAccess else { return false }
            let now = Date()
            return guestAccess.validFrom <= now && now <= guestAccess.validUntil &&
                  guestAccess.deviceIds.contains(self.id)
        }
    }
} 