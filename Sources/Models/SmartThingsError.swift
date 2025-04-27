import Foundation

/// Represents errors specific to SmartThings operations
public enum SmartThingsError: LocalizedError, Hashable {
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
    
    // New errors
    case commandExecutionFailed(deviceId: String, command: String, reason: String)
    
    // Add cases used by APIService
    case invalidURL
    case decodingError(Error)
    case encodingError(Error)
    case serverError(Int) // Assuming Int for status code
    
    // Implement Hashable
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .invalidCredentials: hasher.combine(0)
        case .tokenExpired: hasher.combine(1)
        case .tokenRefreshFailed: hasher.combine(2)
        case .unauthorized: hasher.combine(3)
        case .deviceNotFound(let deviceId):
            hasher.combine(4)
            hasher.combine(deviceId)
        case .deviceOffline(let deviceId):
            hasher.combine(5)
            hasher.combine(deviceId)
        case .deviceBusy(let deviceId):
            hasher.combine(6)
            hasher.combine(deviceId)
        case .invalidCommand(let command):
            hasher.combine(7)
            hasher.combine(command)
        case .commandFailed(let reason):
            hasher.combine(8)
            hasher.combine(reason)
        case .deviceNotSupported(let capability):
            hasher.combine(9)
            hasher.combine(capability)
        case .rateLimitExceeded: hasher.combine(10)
        case .tooManyRequests: hasher.combine(11)
        case .networkError(let error):
            hasher.combine(12)
            hasher.combine(error.localizedDescription)
        case .timeout: hasher.combine(13)
        case .invalidResponse: hasher.combine(14)
        case .webhookRegistrationFailed: hasher.combine(15)
        case .webhookNotFound: hasher.combine(16)
        case .webhookValidationFailed: hasher.combine(17)
        case .sceneNotFound: hasher.combine(18)
        case .sceneExecutionFailed: hasher.combine(19)
        case .invalidSceneConfiguration: hasher.combine(20)
        case .groupNotFound: hasher.combine(21)
        case .groupOperationFailed: hasher.combine(22)
        case .invalidGroupConfiguration: hasher.combine(23)
        case .commandExecutionFailed(let deviceId, let command, let reason):
            hasher.combine(24)
            hasher.combine(deviceId)
            hasher.combine(command)
            hasher.combine(reason)
        case .invalidURL: hasher.combine(25)
        case .decodingError(let error):
            hasher.combine(26)
            hasher.combine(error.localizedDescription)
        case .encodingError(let error):
            hasher.combine(27)
            hasher.combine(error.localizedDescription)
        case .serverError(let statusCode):
            hasher.combine(28)
            hasher.combine(statusCode)
        }
    }

    // Equatable is also needed for Hashable
    public static func == (lhs: SmartThingsError, rhs: SmartThingsError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCredentials, .invalidCredentials): return true
        case (.tokenExpired, .tokenExpired): return true
        case (.tokenRefreshFailed, .tokenRefreshFailed): return true
        case (.unauthorized, .unauthorized): return true
        case (.deviceNotFound(let l), .deviceNotFound(let r)): return l == r
        case (.deviceOffline(let l), .deviceOffline(let r)): return l == r
        case (.deviceBusy(let l), .deviceBusy(let r)): return l == r
        case (.invalidCommand(let l), .invalidCommand(let r)): return l == r
        case (.commandFailed(let l), .commandFailed(let r)): return l == r
        case (.deviceNotSupported(let l), .deviceNotSupported(let r)): return l == r
        case (.rateLimitExceeded, .rateLimitExceeded): return true
        case (.tooManyRequests, .tooManyRequests): return true
        case (.networkError(let l), .networkError(let r)): return l.localizedDescription == r.localizedDescription
        case (.timeout, .timeout): return true
        case (.invalidResponse, .invalidResponse): return true
        case (.webhookRegistrationFailed, .webhookRegistrationFailed): return true
        case (.webhookNotFound, .webhookNotFound): return true
        case (.webhookValidationFailed, .webhookValidationFailed): return true
        case (.sceneNotFound, .sceneNotFound): return true
        case (.sceneExecutionFailed, .sceneExecutionFailed): return true
        case (.invalidSceneConfiguration, .invalidSceneConfiguration): return true
        case (.groupNotFound, .groupNotFound): return true
        case (.groupOperationFailed, .groupOperationFailed): return true
        case (.invalidGroupConfiguration, .invalidGroupConfiguration): return true
        case (.commandExecutionFailed(let ld, let lc, let lr), .commandExecutionFailed(let rd, let rc, let rr)):
            return ld == rd && lc == rc && lr == rr
        case (.invalidURL, .invalidURL): return true
        case (.decodingError(let l), .decodingError(let r)): return l.localizedDescription == r.localizedDescription
        case (.encodingError(let l), .encodingError(let r)): return l.localizedDescription == r.localizedDescription
        case (.serverError(let l), .serverError(let r)): return l == r
        default: return false
        }
    }
    
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
        case .commandExecutionFailed(let deviceId, let command, let reason):
            return "Command execution failed: \(reason) (Device: \(deviceId), Command: \(command))"
        case .invalidURL:
            return "The API endpoint URL was invalid."
        case .decodingError(let error):
            return "Failed to decode API response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request body: \(error.localizedDescription)"
        case .serverError(let statusCode):
            return "API server returned an error: Status Code \(statusCode)"
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
        case .commandExecutionFailed:
            return "Command execution failed. Check device status and command details."
        case .invalidURL:
            return "Please contact support - invalid URL configured."
        case .decodingError, .encodingError, .serverError:
            return "An unexpected error occurred. Please try again or contact support."
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
        case .tokenRefreshFailed:
            return false // Typically requires re-login
        case .deviceOffline:
            return false // Needs user intervention
        case .commandFailed:
            return false // Likely needs investigation
        case .commandExecutionFailed: 
            return false // Likely needs investigation
        case .invalidURL, .decodingError, .encodingError, .serverError:
            return false // Likely needs investigation
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