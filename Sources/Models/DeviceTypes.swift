import Foundation

/// Represents the state of a lock device
public enum LockState: String, Codable {
    case locked = "locked"
    case unlocked = "unlocked"
    case unknown = "unknown"
    case jammed = "jammed"
}

/// Represents a record of lock access
public struct LockAccessRecord: Codable {
    public let timestamp: Date
    public let operation: LockOperation
    public let userId: String
    public let success: Bool
    
    public enum LockOperation: String, Codable {
        case lock = "lock"
        case unlock = "unlock"
    }
    
    public init(timestamp: Date, operation: LockOperation, userId: String, success: Bool) {
        self.timestamp = timestamp
        self.operation = operation
        self.userId = userId
        self.success = success
    }
} 