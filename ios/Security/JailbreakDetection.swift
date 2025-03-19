import Foundation
import UIKit

/// Utility class to detect if the device is jailbroken
public class JailbreakDetection {
    
    /// Returns whether the device is jailbroken
    /// - Returns: true if jailbroken, false otherwise
    public static func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        // Skip jailbreak detection on simulator
        return false
        #else
        // Check for common jailbreak files
        if fileExists("/Applications/Cydia.app") ||
           fileExists("/Library/MobileSubstrate/MobileSubstrate.dylib") ||
           fileExists("/bin/bash") ||
           fileExists("/usr/sbin/sshd") ||
           fileExists("/etc/apt") ||
           fileExists("/private/var/lib/apt/") ||
           fileExists("/usr/bin/ssh") {
            return true
        }
        
        // Check if app can open system directories that would be restricted
        let restrictedDirectories = ["/private/var/lib/apt"]
        for directory in restrictedDirectories {
            do {
                try "Jailbreak Detection".write(toFile: "\(directory)/jailbreak_test.txt", atomically: true, encoding: .utf8)
                try FileManager.default.removeItem(atPath: "\(directory)/jailbreak_test.txt")
                // If write succeeded, the directory is accessible (device is jailbroken)
                return true
            } catch {
                // Expected error on non-jailbroken devices
            }
        }
        
        // Check for suspicious environment variables
        if getenv("DYLD_INSERT_LIBRARIES") != nil {
            return true
        }
        
        // Check if the app can fork (should not be allowed on non-jailbroken devices)
        let pid = fork()
        if pid >= 0 {
            if pid > 0 {
                // Parent process, kill the child
                kill(pid, SIGTERM)
            }
            return true
        }
        
        // Check if symbolic links exist in the app's bundle
        if checkSymbolicLinks() {
            return true
        }
        
        return false
        #endif
    }
    
    /// Check if a file exists at the given path
    /// - Parameter path: Path to check
    /// - Returns: true if file exists, false otherwise
    private static func fileExists(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// Check for symbolic links in the app's bundle
    /// - Returns: true if suspicious symbolic links are found, false otherwise
    private static func checkSymbolicLinks() -> Bool {
        guard let bundlePath = Bundle.main.bundlePath else {
            return false
        }
        
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
            for item in items {
                let path = "\(bundlePath)/\(item)"
                var isSymLink: ObjCBool = false
                
                if FileManager.default.fileExists(atPath: path, isDirectory: nil) {
                    if FileManager.default.fileExists(atPath: path, isDirectory: &isSymLink) {
                        if isSymLink.boolValue {
                            return true
                        }
                    }
                }
            }
        } catch {
            return false
        }
        
        return false
    }
}

// Extension to integrate jailbreak detection with SecurityService
extension SecurityService {
    /// Checks if the device is in a secure state for critical operations
    /// - Returns: true if secure, false if jailbroken or otherwise compromised
    public func isDeviceSecure() -> Bool {
        return !JailbreakDetection.isJailbroken()
    }
    
    /// Verifies that the device is secure before allowing a critical operation
    /// - Parameter operation: A closure that will be executed only if the device is secure
    /// - Throws: SecurityError.deviceCompromised if the device is jailbroken
    /// - Returns: The result of the operation if the device is secure
    public func secureCriticalOperation<T>(_ operation: () throws -> T) throws -> T {
        guard isDeviceSecure() else {
            throw SecurityError.deviceCompromised
        }
        
        return try operation()
    }
    
    /// Asynchronously verifies that the device is secure before allowing a critical operation
    /// - Parameter operation: An async closure that will be executed only if the device is secure
    /// - Throws: SecurityError.deviceCompromised if the device is jailbroken
    /// - Returns: The result of the operation if the device is secure
    public func secureCriticalOperation<T>(_ operation: () async throws -> T) async throws -> T {
        guard isDeviceSecure() else {
            throw SecurityError.deviceCompromised
        }
        
        return try await operation()
    }
}

// Security errors
public enum SecurityError: Error, LocalizedError {
    case deviceCompromised
    
    public var errorDescription: String? {
        switch self {
        case .deviceCompromised:
            return "This operation cannot be performed because the device appears to be compromised."
        }
    }
} 