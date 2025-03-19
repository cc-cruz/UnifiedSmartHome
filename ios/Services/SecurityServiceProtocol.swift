import Foundation

/// Protocol for security services that perform critical operations checks
protocol SecurityServiceProtocol {
    /// Performs a security check for critical operations
    func secureCriticalOperation(completion: @escaping () throws -> Void) async throws
    
    /// Requires biometric authentication before performing an operation
    func authenticateAndPerform(_ reason: String, completion: @escaping () throws -> Void) async throws
    
    /// Checks if device is jailbroken
    func isDeviceJailbroken() -> Bool
    
    /// Validates if a user has permission to perform an operation on a device
    func validateUserPermission(userId: String, deviceId: String, operation: String) async throws -> Bool
}

/// Default implementation to comply with SmartThings adapter
extension SecurityService: SecurityServiceProtocol {
    func secureCriticalOperation(completion: @escaping () throws -> Void) async throws {
        // Check for jailbreak
        if isDeviceJailbroken() {
            throw SecurityError.operationNotAllowed
        }
        
        // Proceed with completion
        try completion()
    }
    
    func authenticateAndPerform(_ reason: String, completion: @escaping () throws -> Void) async throws {
        // In a real implementation, this would use LocalAuthentication to verify
        // biometrics (Face ID or Touch ID)
        
        // For now, we'll simulate success and call the completion
        try completion()
    }
    
    func isDeviceJailbroken() -> Bool {
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
        let restrictedPath = "/private/jailbreak_test"
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
    
    func validateUserPermission(userId: String, deviceId: String, operation: String) async throws -> Bool {
        // In a real implementation, this would check the user's role and device permissions
        // For now, we'll use the existing security validation
        
        // Map operation string to LockOperation (for compatibility with existing code)
        let lockOperation: LockDevice.LockOperation
        switch operation {
        case "unlock":
            lockOperation = .unlock
        case "lock":
            lockOperation = .lock
        default:
            lockOperation = .statusCheck
        }
        
        do {
            try await validateLockOperation(deviceId: deviceId, userId: userId, operation: lockOperation)
            return true
        } catch {
            return false
        }
    }
} 