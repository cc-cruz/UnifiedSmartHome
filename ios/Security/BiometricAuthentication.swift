import Foundation
import LocalAuthentication

/// Utility class for biometric authentication (Touch ID / Face ID)
public class BiometricAuthentication {
    
    /// Result of biometric authentication
    public enum BiometricResult {
        case success
        case failed
        case fallback
        case canceled
        case notAvailable
        case notEnrolled
        case lockedOut
        case notConfigured
    }
    
    /// Type of biometric authentication available
    public enum BiometricType {
        case none
        case touchID
        case faceID
        
        /// User-friendly name of the biometric type
        public var displayName: String {
            switch self {
            case .none:
                return "None"
            case .touchID:
                return "Touch ID"
            case .faceID:
                return "Face ID"
            }
        }
    }
    
    /// Determine what kind of biometric authentication is available
    /// - Returns: The type of biometric authentication available
    public static func biometricType() -> BiometricType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        
        switch context.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        @unknown default:
            return .none
        }
    }
    
    /// Check if biometric authentication is available
    /// - Returns: True if biometric authentication is available
    public static func isBiometricAvailable() -> Bool {
        return biometricType() != .none
    }
    
    /// Authenticate using biometrics
    /// - Parameters:
    ///   - reason: Reason for the authentication to display to the user
    ///   - fallbackTitle: Title for the fallback button (or nil to not show it)
    ///   - completion: Completion handler with the result
    public static func authenticate(
        reason: String,
        fallbackTitle: String? = nil,
        completion: @escaping (BiometricResult) -> Void
    ) {
        let context = LAContext()
        
        // Configure fallback title if provided
        if let title = fallbackTitle {
            context.localizedFallbackTitle = title
        } else {
            context.localizedFallbackTitle = ""
        }
        
        // Check if we can use biometric authentication
        var authError: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            // Perform authentication
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(.success)
                        return
                    }
                    
                    // Handle authentication errors
                    if let error = error {
                        let laError = error as NSError
                        switch laError.code {
                        case LAError.authenticationFailed.rawValue:
                            completion(.failed)
                        case LAError.userCancel.rawValue:
                            completion(.canceled)
                        case LAError.userFallback.rawValue:
                            completion(.fallback)
                        case LAError.biometryNotAvailable.rawValue:
                            completion(.notAvailable)
                        case LAError.biometryNotEnrolled.rawValue:
                            completion(.notEnrolled)
                        case LAError.biometryLockout.rawValue:
                            completion(.lockedOut)
                        default:
                            completion(.failed)
                        }
                    } else {
                        completion(.failed)
                    }
                }
            }
        } else {
            // Cannot use biometric authentication
            if let error = authError {
                switch error.code {
                case LAError.biometryNotAvailable.rawValue:
                    completion(.notAvailable)
                case LAError.biometryNotEnrolled.rawValue:
                    completion(.notEnrolled)
                case LAError.biometryLockout.rawValue:
                    completion(.lockedOut)
                default:
                    completion(.notConfigured)
                }
            } else {
                completion(.notConfigured)
            }
        }
    }
    
    /// Authenticate using biometrics with async/await pattern
    /// - Parameters:
    ///   - reason: Reason for the authentication to display to the user
    ///   - fallbackTitle: Title for the fallback button (or nil to not show it)
    /// - Returns: The result of the authentication
    public static func authenticate(
        reason: String,
        fallbackTitle: String? = nil
    ) async -> BiometricResult {
        return await withCheckedContinuation { continuation in
            authenticate(reason: reason, fallbackTitle: fallbackTitle) { result in
                continuation.resume(returning: result)
            }
        }
    }
}

// Extension to integrate biometric authentication with SecurityService
extension SecurityService {
    /// Authenticate user with biometrics before allowing a critical operation
    /// - Parameters:
    ///   - reason: Reason for the authentication to display to the user
    ///   - operation: The operation to perform if authentication succeeds
    /// - Returns: The result of the operation
    /// - Throws: SecurityError.authenticationFailed if biometric authentication fails
    public func authenticateAndPerform<T>(_ reason: String, operation: () throws -> T) async throws -> T {
        let authResult = await BiometricAuthentication.authenticate(reason: reason)
        
        switch authResult {
        case .success:
            return try operation()
        case .canceled:
            throw SecurityError.authenticationCanceled
        case .fallback:
            throw SecurityError.authenticationFallback
        case .failed, .notAvailable, .notEnrolled, .lockedOut, .notConfigured:
            throw SecurityError.authenticationFailed
        }
    }
    
    /// Authenticate user with biometrics before allowing a critical async operation
    /// - Parameters:
    ///   - reason: Reason for the authentication to display to the user
    ///   - operation: The async operation to perform if authentication succeeds
    /// - Returns: The result of the operation
    /// - Throws: SecurityError.authenticationFailed if biometric authentication fails
    public func authenticateAndPerform<T>(_ reason: String, operation: () async throws -> T) async throws -> T {
        let authResult = await BiometricAuthentication.authenticate(reason: reason)
        
        switch authResult {
        case .success:
            return try await operation()
        case .canceled:
            throw SecurityError.authenticationCanceled
        case .fallback:
            throw SecurityError.authenticationFallback
        case .failed, .notAvailable, .notEnrolled, .lockedOut, .notConfigured:
            throw SecurityError.authenticationFailed
        }
    }
}

// Additional security errors for biometric authentication
extension SecurityError {
    static let authenticationFailed = SecurityError.custom("Biometric authentication failed")
    static let authenticationCanceled = SecurityError.custom("Authentication was canceled")
    static let authenticationFallback = SecurityError.custom("Authentication fallback requested")
    
    static func custom(_ message: String) -> SecurityError {
        struct CustomSecurityError: Error, LocalizedError {
            let message: String
            var errorDescription: String? { message }
        }
        return .customError(CustomSecurityError(message: message))
    }
    
    case customError(Error)
} 