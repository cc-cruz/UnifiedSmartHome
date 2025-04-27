import Foundation
import Models
import Security

public class SecurityService: SecurityServiceProtocol {
    private let userManager: UserManager
    private let auditLogger: AuditLogger
    private let deviceManager: DeviceManagerProtocol
    
    public init(userManager: UserManager, auditLogger: AuditLogger, deviceManager: DeviceManagerProtocol) {
        self.userManager = userManager
        self.auditLogger = auditLogger
        self.deviceManager = deviceManager
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
        
        // Get the lock device using the injected deviceManager
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
        // TODO: Update permission check logic based on User model properties (Sprint 3)
        // For now, assume a simple check exists on LockDevice or User
        // guard lock.canPerformRemoteOperation(by: user) else { 
        guard user.role == .OWNER || user.role == .PROPERTY_MANAGER else { // Simplified check for now
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
        // TODO: Refine biometric check logic
        // if operation == .unlock && userManager.requiresBiometricConfirmationForUnlock {
        //     // In a real implementation, we would verify that biometric auth was performed
        //     // For now, we'll assume it was done at the UI level
        // }
        
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
    
    // Helper method to get a lock device using the injected deviceManager
    private func getLockDevice(id: String) async throws -> LockDevice {
        // Removed: let deviceService = DeviceService.shared
        
        // Use injected deviceManager and getDeviceState (replaces getDevice)
        guard let device = try? await self.deviceManager.getDeviceState(id: id),
              let lockDevice = device as? LockDevice else {
            throw SecurityError.deviceNotFound
        }
        return lockDevice
    }

    // --- Start: Check Protocol Conformance --- 
    // These methods seem to align with a potential SecurityServiceProtocol
    // Check if OperationalSecurityProtocol is the correct one defined elsewhere.

    public func secureCriticalOperation(completion: @escaping () throws -> Void) async throws {
        // Check for jailbreak
        guard !isDeviceJailbroken() else {
            throw SecurityError.operationNotAllowed
        }
        
        // Execute operation
        // Running detached might not be necessary unless completion() is blocking.
        // Consider if just `try completion()` is sufficient.
        try await Task.detached {
            try completion()
        }.value
    }

    public func authenticateAndPerform(_ reason: String, completion: @escaping () throws -> Void) async throws {
        // In a real implementation, this would use LocalAuthentication to verify
        // biometrics (Face ID or Touch ID)
        print("TODO: Implement biometric check for reason: \\(reason)")
        // For now, we'll simulate success and call the completion
        try completion()
    }

    public func isDeviceJailbroken() -> Bool {
        // Basic jailbreak detection
        // In a real implementation, this would include multiple checks
        
        #if targetEnvironment(simulator)
        return false
        #else
        // Check for common jailbreak files
        let jailbreakFiles = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]
        
        for path in jailbreakFiles {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Check if app can write to restricted locations
        let restrictedPath = "/private/" + UUID().uuidString
        do {
            try "test".write(toFile: restrictedPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: restrictedPath)
            return true // Could write to restricted directory
        } catch {
            // Unable to write, which is expected
        }
        
        return false
        #endif
    }

    public func validateUserPermission(userId: String, deviceId: String, operation: String) async throws -> Bool {
        // In a real implementation, this would check the user's role and device permissions
        // For now, we'll use the existing security validation
        
        // Map operation string to LockOperation (for compatibility with existing code)
        let lockOperation: LockDevice.LockOperation
        switch operation.lowercased() { // Use lowercased for case-insensitivity
        case "unlock":
            lockOperation = .unlock
        case "lock":
            lockOperation = .lock
        default:
            // This method returns Bool, maybe just return false for unsupported?
            // Throwing seems harsh if just checking permission.
            // Let's return false for now.
            // throw SecurityError.unsupportedOperation 
            print("Warning: Unsupported operation type '\\(operation)' for permission check.")
            return false
        }
        
        // Assuming validateLockOperation exists and handles LockOperation
        // We need to handle the throw from validateLockOperation appropriately.
        do {
            try await validateLockOperation(deviceId: deviceId, userId: userId, operation: lockOperation)
            return true // If validateLockOperation doesn't throw, permission is granted
        } catch let error as SecurityError where error == .insufficientPermissions {
            return false // Specific permission denial
        } catch {
            // Other errors during validation (user not found, device not found, etc.)
            // Re-throwing might be appropriate here, or log and return false?
            // Let's re-throw for now, as it indicates a more fundamental problem.
            print("Error during permission validation: \\(error)")
            throw error 
        }
    }

    // --- End: Check Protocol Conformance --- 
}

// Security-related errors
public enum SecurityError: Error, LocalizedError {
    case userNotFound
    case deviceNotFound
    case insufficientPermissions
    case biometricAuthRequired
    case biometricAuthFailed
    case operationNotAllowed
    case unsupportedOperation
    
    public var errorDescription: String? {
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
        case .unsupportedOperation:
            return "This operation type is not supported for validation"
        }
    }
} 