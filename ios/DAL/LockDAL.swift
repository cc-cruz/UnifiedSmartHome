import Foundation

// Protocol-based approach for LockDAL
protocol LockDALProtocol {
    func lock(deviceId: String, userId: String) async throws -> LockDevice.LockState
    func unlock(deviceId: String, userId: String) async throws -> LockDevice.LockState
    func getStatus(deviceId: String) async throws -> LockDevice
    func getAccessHistory(deviceId: String, limit: Int) async throws -> [LockDevice.LockAccessRecord]
}

// Concrete implementation
class LockDAL: LockDALProtocol {
    private let lockAdapter: LockAdapter
    private let securityService: SecurityService
    private let auditLogger: AuditLogger
    
    init(lockAdapter: LockAdapter, securityService: SecurityService, auditLogger: AuditLogger) {
        self.lockAdapter = lockAdapter
        self.securityService = securityService
        self.auditLogger = auditLogger
    }
    
    func lock(deviceId: String, userId: String) async throws -> LockDevice.LockState {
        // Security check
        try await securityService.validateLockOperation(deviceId: deviceId, userId: userId, operation: .lock)
        
        // Log audit trail before operation
        auditLogger.logSensitiveOperation(
            type: "lock_operation",
            details: ["deviceId": deviceId, "userId": userId, "operation": "lock"]
        )
        
        // Perform operation
        do {
            let lockState = try await lockAdapter.controlLock(
                id: deviceId,
                command: LockAdapter.LockCommand.lock
            )
            
            // Log success
            auditLogger.logOperationResult(
                type: "lock_operation",
                success: true,
                details: ["deviceId": deviceId, "newState": lockState.rawValue]
            )
            
            return lockState
        } catch {
            // Log failure
            auditLogger.logOperationResult(
                type: "lock_operation",
                success: false,
                details: ["deviceId": deviceId, "error": error.localizedDescription]
            )
            
            throw error
        }
    }
    
    func unlock(deviceId: String, userId: String) async throws -> LockDevice.LockState {
        // Security check
        try await securityService.validateLockOperation(deviceId: deviceId, userId: userId, operation: .unlock)
        
        // Log audit trail before operation
        auditLogger.logSensitiveOperation(
            type: "lock_operation",
            details: ["deviceId": deviceId, "userId": userId, "operation": "unlock"]
        )
        
        // Perform operation
        do {
            let lockState = try await lockAdapter.controlLock(
                id: deviceId,
                command: LockAdapter.LockCommand.unlock
            )
            
            // Log success
            auditLogger.logOperationResult(
                type: "lock_operation",
                success: true,
                details: ["deviceId": deviceId, "newState": lockState.rawValue]
            )
            
            return lockState
        } catch {
            // Log failure
            auditLogger.logOperationResult(
                type: "lock_operation",
                success: false,
                details: ["deviceId": deviceId, "error": error.localizedDescription]
            )
            
            throw error
        }
    }
    
    func getStatus(deviceId: String) async throws -> LockDevice {
        // Get the lock status from the adapter
        return try await lockAdapter.getLockStatus(id: deviceId)
    }
    
    func getAccessHistory(deviceId: String, limit: Int = 20) async throws -> [LockDevice.LockAccessRecord] {
        // Get access history from the adapter
        let lock = try await lockAdapter.getLockStatus(id: deviceId)
        
        // Return the most recent records up to the limit
        return Array(lock.accessHistory.prefix(limit))
    }
} 