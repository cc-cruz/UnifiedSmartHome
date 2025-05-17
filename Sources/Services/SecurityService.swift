import Foundation
import Models
import Security

public class SecurityService: OperationalSecurityProtocol {
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
        guard let lockDevice = try? await getLockDevice(id: deviceId) else {
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
        
        // Check if user has permission to control this lock using the refactored method on LockDevice
        guard lockDevice.canPerformRemoteOperation(by: user) else {
            // Prepare details for logging, including relevant roles if available
            var logDetails: [String: String] = [
                "reason": "insufficient_permissions",
                "userId": userId,
                "deviceId": deviceId,
                "operation": operation.rawValue,
                "lockPropertyId": lockDevice.propertyId ?? "N/A",
                "lockUnitId": lockDevice.unitId ?? "N/A"
            ]
            // Add user roles description if possible
            if let associations = user.roleAssociations {
                let rolesDescription = associations.map { "\($0.roleWithinEntity.rawValue)@\($0.associatedEntityType.rawValue):\($0.associatedEntityId)" }.joined(separator: ", ")
                logDetails["userRoles"] = rolesDescription
            } else {
                logDetails["userRoles"] = "No associations found"
            }

            auditLogger.logSecurityEvent(type: "access_denied", details: logDetails)
            throw SecurityError.insufficientPermissions
        }
        
        // For unlock operations, check if additional security is required (biometrics, etc.)
        // This logic can remain or be enhanced as per requirements.
        // TODO: Refine biometric check logic (e.g., integrate with self.authenticateAndPerform)
        if operation == .unlock && userManager.requiresBiometricConfirmationForUnlock {
            // In a real app, this would likely throw if biometric check failed or wasn't performed.
            // For now, this check seems to be managed by UserManager state.
            // Consider if this service should actively trigger the biometric check via authenticateAndPerform.
            print("INFO: Biometric confirmation would be required for unlock operation by user \(userId) on device \(deviceId).")
        }
        
        // Log successful validation
        // Include property/unit IDs for better audit context
        var successLogDetails: [String: String] = [
            "userId": userId,
            "deviceId": deviceId,
            "operation": operation.rawValue,
            "lockPropertyId": lockDevice.propertyId ?? "N/A",
            "lockUnitId": lockDevice.unitId ?? "N/A"
        ]
        if let associations = user.roleAssociations, let primaryAssociation = associations.first {
             successLogDetails["userPrimaryRole"] = "\(primaryAssociation.roleWithinEntity.rawValue)@\(primaryAssociation.associatedEntityType.rawValue):\(primaryAssociation.associatedEntityId)"
        }

        auditLogger.logSecurityEvent(type: "access_granted", details: successLogDetails)
    }
    
    // Helper method to get a lock device using the injected deviceManager
    private func getLockDevice(id: String) async throws -> LockDevice {
        guard let device = try? await self.deviceManager.getDeviceState(id: id),
              let lockDevice = device as? LockDevice else {
            // Log device not found or wrong type before throwing
            auditLogger.logSystemEvent(type: "error", message: "Failed to get LockDevice with ID: \(id). Device not found or not a LockDevice.")
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
            auditLogger.logSecurityEvent(type: "security_violation", details: ["reason": "jailbroken_device"])
            throw SecurityError.operationNotAllowed("Operation not allowed on jailbroken device.")
        }
        
        // Execute operation
        try await Task.detached {
            try completion()
        }.value
    }

    public func authenticateAndPerform(_ reason: String, completion: @escaping () throws -> Void) async throws {
        // In a real implementation, this would use LocalAuthentication to verify
        // biometrics (Face ID or Touch ID)
        // For now, we'll simulate success and call the completion
        // TODO: Implement actual biometric check using LocalAuthentication.
        // If it fails, throw SecurityError.biometricAuthFailed
        // auditLogger.logSecurityEvent(type: "biometric_auth_attempt", details: ["reason": reason, "status": "simulated_success"])
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
                auditLogger.logSecurityEvent(type: "security_alert", details: ["reason": "jailbreak_file_found", "path": path])
                return true
            }
        }
        
        // Check if app can write to restricted locations
        let restrictedPath = "/private/" + UUID().uuidString
        do {
            try "test".write(toFile: restrictedPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: restrictedPath)
            auditLogger.logSecurityEvent(type: "security_alert", details: ["reason": "jailbreak_write_check_successful", "path": restrictedPath])
            return true // Could write to restricted directory
        } catch {
            // Unable to write, which is expected
        }
        
        return false
        #endif
    }

    // This method seems to be a duplicate or an alternative way to check permissions.
    // For now, it will also be updated to use the canPerformRemoteOperation on the LockDevice itself.
    // Consider if this method is still needed or if callers should use validateLockOperation directly (which throws on failure).
    public func validateUserPermission(userId: String, deviceId: String, operation: String) async throws -> Bool {
        guard let user = await userManager.getUser(id: userId) else {
            // No user, no permission.
            // auditLogger.logSecurityEvent here if needed
            return false 
        }
        guard let lockDevice = try? await getLockDevice(id: deviceId) else {
            // No device, no permission.
            // auditLogger.logSecurityEvent here if needed
            return false
        }

        // The LockDevice.LockOperation enum is more specific than a generic String operation.
        // However, this function takes a String. We should try to map it or require LockOperation.
        // For now, we directly use lockDevice.canPerformRemoteOperation. If this function is
        // meant for more generic operations beyond lock/unlock, it needs rethinking.
        
        let hasPermission = lockDevice.canPerformRemoteOperation(by: user)
        
        if !hasPermission {
            // Log denied access if using this path specifically
            var logDetails: [String: String] = [
                "reason": "insufficient_permissions_check",
                "userId": userId,
                "deviceId": deviceId,
                "operation_string": operation, // Log the original string operation
                "lockPropertyId": lockDevice.propertyId ?? "N/A",
                "lockUnitId": lockDevice.unitId ?? "N/A"
            ]
            if let associations = user.roleAssociations {
                let rolesDescription = associations.map { "\($0.roleWithinEntity.rawValue)@\($0.associatedEntityType.rawValue):\($0.associatedEntityId)" }.joined(separator: ", ")
                logDetails["userRoles"] = rolesDescription
            }
            auditLogger.logSecurityEvent(type: "permission_check_denied", details: logDetails)
        }
        return hasPermission
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
    case operationNotAllowed(String? = nil) // Added optional reason
    case unsupportedOperation
    
    public var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .deviceNotFound:
            return "Device not found"
        case .insufficientPermissions:
            return "You don\'t have permission to perform this operation"
        case .biometricAuthRequired:
            return "Biometric authentication is required for this operation"
        case .biometricAuthFailed:
            return "Biometric authentication failed"
        case .operationNotAllowed(let reason):
            return reason ?? "This operation is not allowed"
        case .unsupportedOperation:
            return "This operation type is not supported for validation"
        }
    }
}

// Protocol definition for AuditLogger (assuming it might look like this)
// If it exists elsewhere, this is just for context.
protocol AuditLogger {
    func logSecurityEvent(type: String, details: [String: String])
    func logSystemEvent(type: String, message: String, details: [String: String]?)
    // Add other logging methods as needed
}

// Ensure OperationalSecurityProtocol is defined if SecurityService conforms to it.
// Example:
protocol OperationalSecurityProtocol {
    func secureCriticalOperation(completion: @escaping () throws -> Void) async throws
    func authenticateAndPerform(_ reason: String, completion: @escaping () throws -> Void) async throws
    func isDeviceJailbroken() -> Bool
    func validateUserPermission(userId: String, deviceId: String, operation: String) async throws -> Bool
} 