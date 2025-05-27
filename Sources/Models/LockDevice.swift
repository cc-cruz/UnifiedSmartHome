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
        case viewStatus = "VIEW_STATUS"
        case changeSettings = "CHANGE_SETTINGS"
        case viewAccessHistory = "VIEW_ACCESS_HISTORY"
    }
    
    private(set) public var currentState: LockState
    private(set) public var batteryLevel: Int
    private(set) public var lastStateChange: Date?
    private(set) public var isRemoteOperationEnabled: Bool
    private(set) public var accessHistory: [LockAccessRecord]

    // New properties for multi-tenancy
    public var propertyId: String?
    public var unitId: String?
    
    public init(
        id: String,
        name: String,
        room: String, // This might become less relevant or map to a Unit's name
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
        accessHistory: [LockAccessRecord] = [],
        propertyId: String? = nil, // Added
        unitId: String? = nil      // Added
    ) {
        self.currentState = currentState
        self.batteryLevel = batteryLevel
        self.lastStateChange = lastStateChange
        self.isRemoteOperationEnabled = isRemoteOperationEnabled
        self.accessHistory = accessHistory
        self.propertyId = propertyId
        self.unitId = unitId
        
        super.init(
            id: id,
            name: name,
            room: room, // Keep for now, might be derived from Unit later
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

        // propertyId and unitId would typically be set after initialization, 
        // once the app determines which Property/Unit this SmartThings device belongs to.
        self.init(
            id: id,
            name: name,
            room: deviceData.roomId ?? "Unknown Room", // Can map to Unit name or be separate
            manufacturer: deviceData.manufacturerName ?? "Unknown",
            model: deviceData.deviceTypeName ?? deviceData.ocf?.fv ?? "Lock",
            firmwareVersion: deviceData.ocf?.fv ?? "Unknown",
            currentState: lockStateValue,
            batteryLevel: batteryLevelValue,
            lastStateChange: nil, // Not typically available from basic fetch
            isRemoteOperationEnabled: true, // Default, or derive from capabilities if possible
            accessHistory: [], // Default
            propertyId: nil,   // To be set later
            unitId: nil        // To be set later
        )
    }
    
    // New initializer from Models.Device
    public convenience init(fromApiDevice apiDevice: Models.Device) {
        let onlineStatus = (apiDevice.status?.uppercased() == "ONLINE")

        // Extract lock-specific attributes
        var determinedLockState: LockState = .unknown
        if let lockStateStr = apiDevice.attributes?["lock"]?.value as? String {
            determinedLockState = LockState(rawValue: lockStateStr.uppercased()) ?? .unknown
        }

        var determinedBatteryLevel: Int = 0 // Default
        if let batteryAny = apiDevice.attributes?["battery"]?.value {
            if let batInt = batteryAny as? Int {
                determinedBatteryLevel = batInt
            } else if let batDouble = batteryAny as? Double {
                determinedBatteryLevel = Int(batDouble)
            } else if let batStr = batteryAny as? String, let batIntFromString = Int(batStr) {
                determinedBatteryLevel = batIntFromString
            }
        }

        self.init(
            id: apiDevice.id,
            name: apiDevice.name,
            room: "Unknown Room", // Default
            manufacturer: apiDevice.manufacturerName ?? "Unknown",
            model: apiDevice.modelName ?? apiDevice.deviceTypeName ?? "Lock",
            firmwareVersion: "N/A", // Default
            isOnline: onlineStatus,
            currentState: determinedLockState,
            batteryLevel: determinedBatteryLevel,
            lastStateChange: nil, // Not typically available from this API struct
            isRemoteOperationEnabled: true, // Default, can be refined
            accessHistory: [], // Default
            propertyId: nil, // To be set by multi-tenancy logic later
            unitId: nil      // To be set by multi-tenancy logic later
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
            accessHistory: accessHistory,
            propertyId: propertyId, // Added
            unitId: unitId          // Added
        )
        
        return newDevice
    }
    
    // Security audit trail
    public struct LockAccessRecord: Identifiable, Codable {
        public let id: UUID
        public let timestamp: Date
        public let operation: LockOperation
        public let userId: String
        public let success: Bool
        public var failureReason: String?
        
        public init(id: UUID = UUID(), timestamp: Date, operation: LockOperation, userId: String, success: Bool, failureReason: String? = nil) {
            self.id = id
            self.timestamp = timestamp
            self.operation = operation
            self.userId = userId
            self.success = success
            self.failureReason = failureReason
        }
    }
    
    // Security checks - REFACTORED for multi-tenancy
    public func canPerformRemoteOperation(by user: User) -> Bool {
        guard isRemoteOperationEnabled else { return false }
        guard let associations = user.roleAssociations else { return false }

        // Check for Portfolio Admin or Owner role at Portfolio level (implicitly grants access to all within)
        // This requires knowing the portfolioId this device belongs to. For now, we assume direct property/unit check.
        // If a portfolioID is available on the lock, we could check that first.
        // Example: if let portfolioId = self.property?.portfolioId, user.isPortfolioAdmin(portfolioId) { return true }

        for association in associations {
            switch association.associatedEntityType {
            case .portfolio:
                // A PortfolioAdmin or Owner of the Portfolio this lock belongs to (indirectly via Property)
                // This check is more complex as LockDevice doesn't directly link to Portfolio.
                // We'd need to fetch the Property, then its Portfolio, then check user's role for that Portfolio.
                // For now, we'll rely on Property/Unit level access.
                if association.roleWithinEntity == .portfolioAdmin || association.roleWithinEntity == .owner {
                    // To fully implement this, we'd need a way to check if self.propertyId is within this portfolio.
                    // This might be better handled by a service layer that has access to the full hierarchy.
                    // For now, let's assume if they are portfolio admin/owner, they have broad access, 
                    // but this is a simplification and should be tightened.
                    // A more precise check: Is self.propertyId part of portfolio (association.associatedEntityId)?
                    // This requires a data source or service not available directly in the model.
                    // For Sunday: If a user has ANY Portfolio Admin/Owner role, grant access. (Simplification)
                    return true 
                }

            case .property:
                // User is a Property Manager for the Property this lock belongs to
                if let devicePropertyId = self.propertyId,
                   devicePropertyId == association.associatedEntityId,
                   association.roleWithinEntity == .propertyManager {
                    return true
                }
                // Guest with access to this specific property (e.g. common area lock)
                if let guestAccess = user.guestAccess, 
                   let guestPropertyId = guestAccess.propertyId,
                   let devicePropertyId = self.propertyId,
                   guestPropertyId == devicePropertyId,
                   guestAccess.deviceIds.contains(self.id) {
                     let now = Date()
                     if now >= guestAccess.validFrom && now <= guestAccess.validUntil {
                         return true
                     }
                }

            case .unit:
                // User is a Tenant of the Unit this lock belongs to
                if let deviceUnitId = self.unitId,
                   deviceUnitId == association.associatedEntityId,
                   association.roleWithinEntity == .tenant {
                    return true
                }
                // Guest with access to this specific unit
                if let guestAccess = user.guestAccess, 
                   let guestUnitId = guestAccess.unitId,
                   let deviceUnitId = self.unitId,
                   guestUnitId == deviceUnitId,
                   guestAccess.deviceIds.contains(self.id) {
                     let now = Date()
                     if now >= guestAccess.validFrom && now <= guestAccess.validUntil {
                         return true
                     }
                }
            }
        }
        
        // Guest access not tied to a specific property/unit association, but directly to device IDs
        // (This part is similar to original guest logic, but now it's a fallback)
        if let guestAccess = user.guestAccess, guestAccess.deviceIds.contains(self.id) {
            // Check if current time is within the valid access period
            let now = Date()
            if now >= guestAccess.validFrom && now <= guestAccess.validUntil {
                // Ensure guest access is not restricted to a property/unit they don't match
                // If guestPropertyId is nil AND guestUnitId is nil, it's a general device permission.
                if guestAccess.propertyId == nil && guestAccess.unitId == nil {
                    return true
                } 
                // If guestPropertyId matches device's propertyId (and unitId is nil on guest access)
                if let guestPropertyId = guestAccess.propertyId, self.propertyId == guestPropertyId, guestAccess.unitId == nil {
                    return true
                }
                // If guestUnitId matches device's unitId
                if let guestUnitId = guestAccess.unitId, self.unitId == guestUnitId {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Codable Conformance

    private enum CodingKeys: String, CodingKey {
        // Properties specific to LockDevice
        case currentState, batteryLevel, lastStateChange, isRemoteOperationEnabled, accessHistory
        // Tenancy properties also need to be included if they are to be encoded/decoded with LockDevice
        case propertyId, unitId 
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode LockDevice specific properties
        currentState = try container.decode(LockState.self, forKey: .currentState)
        batteryLevel = try container.decode(Int.self, forKey: .batteryLevel)
        lastStateChange = try container.decodeIfPresent(Date.self, forKey: .lastStateChange)
        isRemoteOperationEnabled = try container.decode(Bool.self, forKey: .isRemoteOperationEnabled)
        accessHistory = try container.decode([LockAccessRecord].self, forKey: .accessHistory)
        propertyId = try container.decodeIfPresent(String.self, forKey: .propertyId)
        unitId = try container.decodeIfPresent(String.self, forKey: .unitId)

        // Call super.init(from: decoder) to decode AbstractDevice properties
        // This MUST come AFTER all properties of this class (LockDevice) are initialized.
        try super.init(from: decoder)
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode LockDevice specific properties
        try container.encode(currentState, forKey: .currentState)
        try container.encode(batteryLevel, forKey: .batteryLevel)
        try container.encodeIfPresent(lastStateChange, forKey: .lastStateChange)
        try container.encode(isRemoteOperationEnabled, forKey: .isRemoteOperationEnabled)
        try container.encode(accessHistory, forKey: .accessHistory)
        try container.encodeIfPresent(propertyId, forKey: .propertyId)
        try container.encodeIfPresent(unitId, forKey: .unitId)
        
        // Call super.encode(to: encoder) to encode AbstractDevice properties
        try super.encode(to: encoder)
    }
}

// User model definition removed - now solely defined in User.swift 