import Foundation

class SecurityService {
    private let userManager: UserManager
    private let auditLogger: AuditLogger
    
    init(userManager: UserManager, auditLogger: AuditLogger) {
        self.userManager = userManager
        self.auditLogger = auditLogger
    }
    
    // Validate if a user can perform a lock operation
    func validateLockOperation(deviceId: String, userId: String, operation: LockDevice.LockOperation) async throws {
        // Check if user exists
        guard let user = await userManager.getUser(id: userId) else {
            auditLogger.logSecurityEvent(
                type: "access_denied",
                details: [
                    "reason": "user_not_found",
                    "userId": userId,
                    "deviceId": deviceId,
                    "operation": operation.rawValue
                ]
            )
            throw SecurityError.userNotFound
        }
        
        // Get the lock device
        guard let lock = try? await getLockDevice(id: deviceId) else {
            auditLogger.logSecurityEvent(
                type: "access_denied",
                details: [
                    "reason": "device_not_found",
                    "userId": userId,
                    "deviceId": deviceId,
                    "operation": operation.rawValue
                ]
            )
            throw SecurityError.deviceNotFound
        }
        
        // Check if user has permission to control this lock
        guard lock.canPerformRemoteOperation(by: user) else {
            auditLogger.logSecurityEvent(
                type: "access_denied",
                details: [
                    "reason": "insufficient_permissions",
                    "userId": userId,
                    "deviceId": deviceId,
                    "operation": operation.rawValue,
                    "userRole": user.role.rawValue
                ]
            )
            throw SecurityError.insufficientPermissions
        }
        
        // For unlock operations, check if additional security is required
        if operation == .unlock && userManager.requiresBiometricConfirmationForUnlock {
            // In a real implementation, we would verify that biometric auth was performed
            // For now, we'll assume it was done at the UI level
        }
        
        // Log successful validation
        auditLogger.logSecurityEvent(
            type: "access_granted",
            details: [
                "userId": userId,
                "deviceId": deviceId,
                "operation": operation.rawValue,
                "userRole": user.role.rawValue
            ]
        )
    }
    
    // Helper method to get a lock device
    private func getLockDevice(id: String) async throws -> LockDevice {
        // In a real implementation, this would fetch from a device repository
        // For now, we'll use a mock implementation
        let deviceService = DeviceService.shared
        guard let device = try? await deviceService.getDevice(id: id),
              let lockDevice = device as? LockDevice else {
            throw SecurityError.deviceNotFound
        }
        return lockDevice
    }
}

// Security-related errors
enum SecurityError: Error, LocalizedError {
    case userNotFound
    case deviceNotFound
    case insufficientPermissions
    case biometricAuthRequired
    case biometricAuthFailed
    case operationNotAllowed
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .deviceNotFound:
            return "Device not found"
        case .insufficientPermissions:
            return "You don't have permission to perform this operation"
        case .biometricAuthRequired:
            return "Biometric authentication is required for this operation"
        case .biometricAuthFailed:
            return "Biometric authentication failed"
        case .operationNotAllowed:
            return "This operation is not allowed"
        }
    }
} 