import Foundation
import Models // Ensure Models is imported for LockDevice, User etc.

// Protocol-based approach for LockDAL
protocol LockDALProtocol {
    // userId is still needed here to fetch the User object for permission checks
    func lock(deviceId: String, userId: String) async throws -> LockDevice.LockState
    func unlock(deviceId: String, userId: String) async throws -> LockDevice.LockState
    func getStatus(deviceId: String) async throws -> LockDevice // Assuming getStatus might not need explicit user permission check in DAL, or it's handled differently
    func getAccessHistory(deviceId: String, limit: Int) async throws -> [LockDevice.LockAccessRecord] // Similar to getStatus
}

// Concrete implementation
class LockDAL: LockDALProtocol {
    private let lockAdapter: LockAdapter
    private let securityService: SecurityService // SecurityService already has userManager and deviceManager
    private let auditLogger: AuditLogger
    private let userManager: UserManager // Added UserManager dependency
    private let deviceManager: DeviceManagerProtocol // Added DeviceManager to fetch device state if needed by LockDAL directly

    init(lockAdapter: LockAdapter, securityService: SecurityService, auditLogger: AuditLogger, userManager: UserManager, deviceManager: DeviceManagerProtocol) {
        self.lockAdapter = lockAdapter
        self.securityService = securityService
        self.auditLogger = auditLogger
        self.userManager = userManager
        self.deviceManager = deviceManager
    }
    
    private func getFullUser(userId: String) async throws -> User {
        guard let user = await userManager.getUser(id: userId) else {
            auditLogger.logSecurityEvent(
                type: "access_denied_dal",
                details: ["reason": "user_not_found_in_dal", "userId": userId]
            )
            throw LockDALError.userNotFoundForAction(userId: userId)
        }
        return user
    }

    private func getFullLockDevice(deviceId: String) async throws -> LockDevice {
        // Option 1: Use DeviceManager injected into LockDAL
        // guard let device = try? await self.deviceManager.getDeviceState(id: deviceId),
        //       let lockDevice = device as? LockDevice else {
        //     auditLogger.logSystemEvent(type: "error", message: "LockDAL: Failed to get LockDevice with ID: \\(deviceId).", details: ["deviceId": deviceId])
        //     throw LockDALError.deviceNotFoundForAction(deviceId: deviceId)
        // }
        // return lockDevice

        // Option 2: Use SecurityService's helper if preferred (SecurityService also uses DeviceManager)
        // This keeps device fetching consistent with how SecurityService itself might get it.
        do {
            return try await securityService.getLockDevice(id: deviceId)
        } catch let error as SecurityError where error == .deviceNotFound {
             auditLogger.logSystemEvent(type: "error", message: "LockDAL: SecurityService failed to get LockDevice with ID: \\(deviceId).", details: ["deviceId": deviceId, "originalError": error.localizedDescription])
            throw LockDALError.deviceNotFoundForAction(deviceId: deviceId)
        } catch {
            auditLogger.logSystemEvent(type: "error", message: "LockDAL: Unexpected error fetching LockDevice with ID: \\(deviceId).", details: ["deviceId": deviceId, "error": error.localizedDescription])
            throw error // Re-throw other errors
        }
    }

    func lock(deviceId: String, userId: String) async throws -> LockDevice.LockState {
        // Fetch full User and LockDevice objects
        let user = try await getFullUser(userId: userId)
        let lockDevice = try await getFullLockDevice(deviceId: deviceId)

        // Security check using the refactored method in SecurityService
        try await securityService.validateLockOperation(user: user, device: lockDevice, operation: .lock)
        
        // Log audit trail before operation
        auditLogger.logSensitiveOperation(
            type: "lock_operation_dal",
            details: ["deviceId": deviceId, "userId": userId, "operation": "lock"]
        )
        
        // Perform operation
        do {
            let lockState = try await lockAdapter.controlLock(
                id: deviceId,
                command: LockAdapter.LockCommand.lock
            )
            
            auditLogger.logOperationResult(
                type: "lock_operation_dal",
                success: true,
                details: ["deviceId": deviceId, "newState": lockState.rawValue, "userId": userId]
            )
            return lockState
        } catch let adaptError {
            auditLogger.logOperationResult(
                type: "lock_operation_dal",
                success: false,
                details: ["deviceId": deviceId, "error": adaptError.localizedDescription, "userId": userId]
            )
            // Check if it's a LockAdapterError and wrap it, otherwise rethrow
            if let specificAdapterError = adaptError as? LockAdapterError {
                 throw LockDALError.adapterError(source: specificAdapterError)
            } else {
                throw adaptError // Rethrow other types of errors
            }
        }
    }
    
    func unlock(deviceId: String, userId: String) async throws -> LockDevice.LockState {
        // Fetch full User and LockDevice objects
        let user = try await getFullUser(userId: userId)
        let lockDevice = try await getFullLockDevice(deviceId: deviceId)

        // Security check using the refactored method in SecurityService
        try await securityService.validateLockOperation(user: user, device: lockDevice, operation: .unlock)
        
        auditLogger.logSensitiveOperation(
            type: "lock_operation_dal",
            details: ["deviceId": deviceId, "userId": userId, "operation": "unlock"]
        )
        
        do {
            let lockState = try await lockAdapter.controlLock(
                id: deviceId,
                command: LockAdapter.LockCommand.unlock
            )
            
            auditLogger.logOperationResult(
                type: "lock_operation_dal",
                success: true,
                details: ["deviceId": deviceId, "newState": lockState.rawValue, "userId": userId]
            )
            return lockState
        } catch let adaptError {
            auditLogger.logOperationResult(
                type: "lock_operation_dal",
                success: false,
                details: ["deviceId": deviceId, "error": adaptError.localizedDescription, "userId": userId]
            )
            if let specificAdapterError = adaptError as? LockAdapterError {
                 throw LockDALError.adapterError(source: specificAdapterError)
            } else {
                throw adaptError
            }
        }
    }
    
    func getStatus(deviceId: String) async throws -> LockDevice {
        // Note: This method currently does not perform a user-specific permission check via SecurityService.
        // If viewStatus requires specific user permissions, this should be added, similar to lock/unlock.
        // For now, assuming it's a more open status check or permissions are handled at a higher layer (ViewModel/UI).
        // To add permission check: Get current user, then call securityService.validateLockOperation with .viewStatus.
        return try await lockAdapter.getLockStatus(id: deviceId)
    }
    
    func getAccessHistory(deviceId: String, limit: Int = 20) async throws -> [LockDevice.LockAccessRecord] {
        // Similar to getStatus, no explicit user permission check here currently.
        // If viewAccessHistory requires permissions, it should be added.
        // Example: try await securityService.validateLockOperation(user: user, device: device, operation: .viewAccessHistory)
        let lock = try await lockAdapter.getLockStatus(id: deviceId)        
        return Array(lock.accessHistory.prefix(limit))
    }
}

// Define LockDALError if it's not already defined elsewhere
public enum LockDALError: Error, LocalizedError {
    case userNotFoundForAction(userId: String)
    case deviceNotFoundForAction(deviceId: String)
    case securityCheckFailed(error: SecurityError) // If SecurityService throws an error
    case adapterError(source: LockAdapterError) // Wrapping LockAdapterError
    case unknownError(message: String)

    public var errorDescription: String? {
        switch self {
        case .userNotFoundForAction(let userId):
            return "User with ID '\\(userId)' not found to perform action."
        case .deviceNotFoundForAction(let deviceId):
            return "LockDevice with ID '\\(deviceId)' not found to perform action."
        case .securityCheckFailed(let securityError):
            return "Security check failed: \\(securityError.localizedDescription)"
        case .adapterError(let sourceError):
            return "Lock adapter operation failed: \\(sourceError.localizedDescription)"
        case .unknownError(let message):
            return "An unknown error occurred in LockDAL: \\(message)"
        }
    }
}

// Assuming LockAdapterError is defined something like this (for context):
/*
 public enum LockAdapterError: Error, LocalizedError {
    case deviceCommunicationError(message: String)
    case commandNotSupported
    case deviceOffline
    case unknownError(message: String)

    public var errorDescription: String? {
        // ... descriptions
    }
 }
 */

// Ensure Models.User, Models.LockDevice, etc. are available.
// Ensure UserManager, DeviceManagerProtocol are available. 