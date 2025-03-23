import Foundation

/// Represents different possible lock states
public enum LockState: String, Codable {
    case locked = "locked"
    case unlocked = "unlocked"
    case jammed = "jammed"
    case unknown = "unknown"
}

/// A smart lock device that can be locked and unlocked
public class LockDevice: AbstractDevice {
    // MARK: - Properties
    
    /// Current state of the lock
    public var currentState: LockState
    
    /// Battery level percentage 0-100
    public var batteryLevel: Int?
    
    /// Last time the lock's state changed
    public var lastStateChange: Date?
    
    /// Whether the lock can be operated remotely
    public var isRemoteOperationEnabled: Bool
    
    /// Lock access history records
    public var accessHistory: [LockAccessRecord]
    
    // MARK: - Initializer
    
    public init(id: String?, name: String, manufacturer: String = "Generic", 
         model: String = "Smart Lock", firmwareVersion: String? = nil, 
         serviceName: String, isOnline: Bool = true, dateAdded: Date = Date(), 
         metadata: [String: String] = [:], currentState: LockState = .unknown, 
         batteryLevel: Int? = nil, lastStateChange: Date? = nil, 
         isRemoteOperationEnabled: Bool = true, accessHistory: [LockAccessRecord] = []) {
        
        self.currentState = currentState
        self.batteryLevel = batteryLevel
        self.lastStateChange = lastStateChange
        self.isRemoteOperationEnabled = isRemoteOperationEnabled
        self.accessHistory = accessHistory
        
        super.init(id: id, name: name, manufacturer: manufacturer, model: model, 
              firmwareVersion: firmwareVersion, serviceName: serviceName, 
              isOnline: isOnline, dateAdded: dateAdded, metadata: metadata)
    }
    
    // MARK: - Methods
    
    /// Creates a copy of this device
    public override func copy() -> AbstractDevice {
        return LockDevice(
            id: id,
            name: name,
            manufacturer: manufacturer,
            model: model,
            firmwareVersion: firmwareVersion,
            serviceName: serviceName,
            isOnline: isOnline,
            dateAdded: dateAdded,
            metadata: metadata,
            currentState: currentState,
            batteryLevel: batteryLevel,
            lastStateChange: lastStateChange,
            isRemoteOperationEnabled: isRemoteOperationEnabled,
            accessHistory: accessHistory
        )
    }
    
    // MARK: - Nested Types
    
    /// Record of lock access activity
    public struct LockAccessRecord: Codable, Equatable {
        /// Time of access
        public let timestamp: Date
        
        /// Type of operation performed
        public let operation: LockOperation
        
        /// User ID who performed or requested the operation
        public let userId: String
        
        /// Whether the operation succeeded
        public let success: Bool
        
        /// Error message if any
        public let errorMessage: String?
        
        /// Additional context about the access
        public let metadata: [String: String]?
        
        public init(timestamp: Date, operation: LockOperation, userId: String, success: Bool, 
             errorMessage: String? = nil, metadata: [String: String]? = nil) {
            self.timestamp = timestamp
            self.operation = operation
            self.userId = userId
            self.success = success
            self.errorMessage = errorMessage
            self.metadata = metadata
        }
    }
    
    /// Types of lock operations that can be performed
    public enum LockOperation: String, Codable {
        case lock = "lock"
        case unlock = "unlock"
        case autoLock = "auto_lock"
    }
    
    // MARK: - Coding
    
    enum CodingKeys: String, CodingKey {
        case currentState, batteryLevel, lastStateChange, isRemoteOperationEnabled, accessHistory
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.currentState = try container.decodeIfPresent(LockState.self, forKey: .currentState) ?? .unknown
        self.batteryLevel = try container.decodeIfPresent(Int.self, forKey: .batteryLevel)
        self.lastStateChange = try container.decodeIfPresent(Date.self, forKey: .lastStateChange)
        self.isRemoteOperationEnabled = try container.decodeIfPresent(Bool.self, forKey: .isRemoteOperationEnabled) ?? true
        self.accessHistory = try container.decodeIfPresent([LockAccessRecord].self, forKey: .accessHistory) ?? []
        
        try super.init(from: decoder)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentState, forKey: .currentState)
        try container.encodeIfPresent(batteryLevel, forKey: .batteryLevel)
        try container.encodeIfPresent(lastStateChange, forKey: .lastStateChange)
        try container.encode(isRemoteOperationEnabled, forKey: .isRemoteOperationEnabled)
        try container.encode(accessHistory, forKey: .accessHistory)
        
        try super.encode(to: encoder)
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