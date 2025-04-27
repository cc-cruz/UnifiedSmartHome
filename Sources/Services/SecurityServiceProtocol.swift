import Foundation
import Models
import Security

/// Protocol for operational security services (permissions, jailbreak, etc.)
public protocol OperationalSecurityProtocol {
    /// Performs a security check for critical operations
    func secureCriticalOperation(completion: @escaping () throws -> Void) async throws
    
    /// Requires biometric authentication before performing an operation
    func authenticateAndPerform(_ reason: String, completion: @escaping () throws -> Void) async throws
    
    /// Checks if device is jailbroken
    func isDeviceJailbroken() -> Bool
    
    /// Validates if a user has permission to perform an operation on a device
    func validateUserPermission(userId: String, deviceId: String, operation: String) async throws -> Bool
}

/// Permissions enum
public enum Permission: String {
    case manageLocks = "manage_locks"
    case viewHistory = "view_history"
    case manageUsers = "manage_users"
}

/// Helper function to check for jailbreak
private func isJailbroken() -> Bool {
    // Standard jailbreak detection checks
    #if targetEnvironment(simulator)
    return false // Simulator is not jailbroken
    #else
    let suspiciousPaths = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt/",
        "/usr/libexec/cydia/",
        "/usr/bin/ssh"
    ]
    
    for path in suspiciousPaths {
        if FileManager.default.fileExists(atPath: path) {
            return true
        }
    }
    
    // Check if we can write outside sandbox
    let testPath = "/private/" + UUID().uuidString
    do {
        try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(atPath: testPath)
        return true
    } catch {
        return false
    }
    #endif
}