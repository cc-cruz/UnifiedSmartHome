import Foundation
import Models

// Move enum outside protocol
enum LockCommand {
    case lock
    case unlock
}

// Base protocol for Lock adapters
protocol LockAdapter {
    func initialize(with authToken: String) throws
    func fetchLocks() async throws -> [LockDevice]
    
    func getLockStatus(id: String) async throws -> LockDevice
    func controlLock(id: String, command: LockCommand) async throws -> LockDevice.LockState
}

// Error types specific to lock operations
enum LockOperationError: Error, LocalizedError {
    case operationFailed(String)
    case notAuthenticated
    case lockJammed
    case lowBattery
    case networkError
    case rateLimited
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .operationFailed(let reason):
            return "Lock operation failed: \(reason)"
        case .notAuthenticated:
            return "Not authenticated with lock provider"
        case .lockJammed:
            return "Lock mechanism is jammed"
        case .lowBattery:
            return "Lock battery is too low for operation"
        case .networkError:
            return "Network error communicating with lock"
        case .rateLimited:
            return "Too many operations in a short period"
        case .permissionDenied:
            return "You don't have permission for this operation"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .operationFailed:
            return "Please try again or check the lock manually"
        case .notAuthenticated:
            return "Please log in again to your account"
        case .lockJammed:
            return "Check if something is obstructing the lock mechanism"
        case .lowBattery:
            return "Replace the lock batteries soon"
        case .networkError:
            return "Check your network connection"
        case .rateLimited:
            return "Please wait a moment before trying again"
        case .permissionDenied:
            return "Contact your property manager for access"
        }
    }
} 