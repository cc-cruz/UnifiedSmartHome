import Foundation

/// Represents errors specific to SmartThings operations
public enum SmartThingsError: LocalizedError {
    // Authentication Errors
    case invalidCredentials
    case tokenExpired
    case tokenRefreshFailed
    case unauthorized
    
    // Device Operation Errors
    case deviceNotFound(String)
    case deviceOffline(String)
    case deviceBusy(String)
    case invalidCommand(String)
    case commandFailed(String)
    case deviceNotSupported(String)
    
    // Rate Limiting Errors
    case rateLimitExceeded
    case tooManyRequests
    
    // Network Errors
    case networkError(Error)
    case timeout
    case invalidResponse
    
    // Webhook Errors
    case webhookRegistrationFailed
    case webhookNotFound
    case webhookValidationFailed
    
    // Scene Errors
    case sceneNotFound
    case sceneExecutionFailed
    case invalidSceneConfiguration
    
    // Group Errors
    case groupNotFound
    case groupOperationFailed
    case invalidGroupConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid SmartThings credentials"
        case .tokenExpired:
            return "Authentication token has expired"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        case .unauthorized:
            return "Unauthorized access to SmartThings API"
        case .deviceNotFound(let id):
            return "Device not found: \(id)"
        case .deviceOffline(let id):
            return "Device is offline: \(id)"
        case .deviceBusy(let id):
            return "Device is busy: \(id)"
        case .invalidCommand(let command):
            return "Invalid command: \(command)"
        case .commandFailed(let reason):
            return "Command failed: \(reason)"
        case .deviceNotSupported(let capability):
            return "Device does not support: \(capability)"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .tooManyRequests:
            return "Too many requests"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        case .invalidResponse:
            return "Invalid response from SmartThings API"
        case .webhookRegistrationFailed:
            return "Failed to register webhook"
        case .webhookNotFound:
            return "Webhook not found"
        case .webhookValidationFailed:
            return "Webhook validation failed"
        case .sceneNotFound:
            return "Scene not found"
        case .sceneExecutionFailed:
            return "Failed to execute scene"
        case .invalidSceneConfiguration:
            return "Invalid scene configuration"
        case .groupNotFound:
            return "Group not found"
        case .groupOperationFailed:
            return "Failed to perform group operation"
        case .invalidGroupConfiguration:
            return "Invalid group configuration"
        }
    }
    
    /// Provides recovery suggestions for each error type
    public var recoverySuggestion: String? {
        switch self {
        case .invalidCredentials:
            return "Please check your SmartThings credentials and try again"
        case .tokenExpired, .tokenRefreshFailed:
            return "Please log in again to refresh your authentication"
        case .unauthorized:
            return "Please verify your SmartThings account permissions"
        case .deviceNotFound:
            return "Please verify the device ID and try again"
        case .deviceOffline:
            return "Please check the device's connection and try again"
        case .deviceBusy:
            return "Please wait a moment and try again"
        case .invalidCommand:
            return "Please verify the command syntax and try again"
        case .commandFailed:
            return "Please check the device status and try again"
        case .deviceNotSupported:
            return "This operation is not supported by the device"
        case .rateLimitExceeded, .tooManyRequests:
            return "Please wait a few minutes before trying again"
        case .networkError:
            return "Please check your internet connection and try again"
        case .timeout:
            return "Please try again in a moment"
        case .invalidResponse:
            return "Please try again or contact support if the issue persists"
        case .webhookRegistrationFailed:
            return "Please verify your webhook URL and try again"
        case .webhookNotFound:
            return "Please verify the webhook ID and try again"
        case .webhookValidationFailed:
            return "Please verify your webhook configuration"
        case .sceneNotFound:
            return "Please verify the scene ID and try again"
        case .sceneExecutionFailed:
            return "Please check scene configuration and try again"
        case .invalidSceneConfiguration:
            return "Please verify scene settings and try again"
        case .groupNotFound:
            return "Please verify the group ID and try again"
        case .groupOperationFailed:
            return "Please check group configuration and try again"
        case .invalidGroupConfiguration:
            return "Please verify group settings and try again"
        }
    }
    
    /// Determines if the error is recoverable
    public var isRecoverable: Bool {
        switch self {
        case .tokenExpired, .rateLimitExceeded, .tooManyRequests, .deviceBusy, .timeout:
            return true
        case .invalidCredentials, .unauthorized, .deviceNotFound, .invalidCommand, .deviceNotSupported:
            return false
        case .networkError(let error):
            return (error as NSError).domain == NSURLErrorDomain
        case .invalidResponse, .webhookRegistrationFailed, .webhookNotFound, .webhookValidationFailed,
             .sceneNotFound, .sceneExecutionFailed, .invalidSceneConfiguration,
             .groupNotFound, .groupOperationFailed, .invalidGroupConfiguration:
            return false
        }
    }
    
    /// Returns the recommended retry delay in seconds
    public var retryDelay: TimeInterval {
        switch self {
        case .rateLimitExceeded, .tooManyRequests:
            return 60 // 1 minute
        case .deviceBusy:
            return 5 // 5 seconds
        case .timeout:
            return 2 // 2 seconds
        case .tokenExpired:
            return 1 // 1 second
        default:
            return 0 // No retry
        }
    }
} 