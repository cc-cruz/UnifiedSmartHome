import Foundation

/// Categories for log events to group related activities
public enum LogEventCategory: String, Codable {
    /// Authentication and user identity events
    case authentication = "authentication"
    
    /// Device control and state changes
    case deviceControl = "device_control"
    
    /// User management activities
    case userManagement = "user_management"
    
    /// Security related events
    case security = "security"
    
    /// Configuration and settings changes
    case configuration = "configuration"
    
    /// System operations and errors
    case system = "system"
}

/// Specific actions that can be logged
public enum LogEventAction: String, Codable {
    // Authentication actions
    case login = "login"
    case logout = "logout"
    case tokenRefresh = "token_refresh"
    case tokenRevoked = "token_revoked"
    
    // Device control actions
    case getDevices = "get_devices"
    case getDeviceState = "get_device_state"
    case executeCommand = "execute_command"
    
    // Security actions
    case biometricAuthRequest = "biometric_auth_request"
    case rateLimitExceeded = "rate_limit_exceeded"
    case securityPolicyCheck = "security_policy_check"
}

/// Status of logged events
public enum LogEventStatus: String, Codable {
    /// Event completed successfully
    case success = "success"
    
    /// Event failed
    case failed = "failed"
    
    /// Event is in progress
    case started = "started"
    
    /// Event completed with warning
    case warning = "warning"
}

/// Types of log entries
public enum LogEventType: String, Codable {
    /// User authentication events
    case authentication = "authentication"
    
    /// Device operations
    case deviceOperation = "device_operation"
    
    /// Security-related events
    case securityEvent = "security_event"
    
    /// Error events
    case error = "error"
    
    /// Debug information
    case debug = "debug"
    
    /// General info
    case info = "info"
    
    /// Performance metrics
    case performance = "performance"
} 