import Foundation

/// Protocol defining the interface for smart device adapters
public protocol SmartDeviceAdapter {
    /// Initialize the adapter with an authentication token
    /// - Parameter authToken: The authentication token
    func initialize(with authToken: String) throws
    
    /// Refresh authentication if needed
    /// - Returns: True if authentication was refreshed
    func refreshAuthentication() async throws -> Bool
    
    /// Fetch all devices available to the currently authenticated user
    /// - Returns: Array of devices
    func fetchDevices() async throws -> [AbstractDevice]
    
    /// Get the current state of a specific device
    /// - Parameter deviceId: The device ID
    /// - Returns: The device with its current state
    func getDeviceState(deviceId: String) async throws -> AbstractDevice
    
    /// Update a device's state by executing a command
    /// - Parameters:
    ///   - deviceId: The device ID
    ///   - command: The command to execute
    /// - Returns: The updated device state
    func executeCommand(deviceId: String, command: DeviceCommand) async throws -> AbstractDevice
    
    /// Revoke authentication tokens
    func revokeAuthentication() async throws
}

/// Protocol for rate limiting API requests
public protocol RateLimiterProtocol {
    /// Check if an action can be performed for a resource
    /// - Parameter resourceId: The resource identifier
    /// - Returns: True if the action is allowed
    func canPerformAction(for resourceId: String) -> Bool
    
    /// Record that an action was performed for a resource
    /// - Parameter resourceId: The resource identifier
    func recordAction(for resourceId: String)
    
    /// Clear all rate limiting data
    func reset()
}

/// Protocol for security services (biometric auth, encryption, etc.)
public protocol SecurityServiceProtocol {
    /// Get the ID of the currently authenticated user
    /// - Returns: User ID if authenticated
    func getCurrentUserId() -> String?
    
    /// Verify biometric authentication for sensitive operations
    /// - Parameter reason: Reason for authentication
    func verifyBiometricAuthentication(reason: String) async throws
    
    /// Authenticate and execute a secured operation
    /// - Parameters:
    ///   - reason: Reason for authentication
    ///   - operation: The operation to perform if authentication succeeds
    func authenticateAndPerform(_ reason: String, operation: @escaping () async throws -> Void) async throws
}

/// Protocol for audit logging
public protocol AuditLoggerProtocol {
    /// Log type for audit events
    var logType: [String: String] { get }
    
    /// Log an event
    /// - Parameters:
    ///   - category: Event category
    ///   - action: Action performed
    ///   - metadata: Additional context
    func logEvent(category: String, action: String, metadata: [String: String])
}

/// Log event categories
public enum LogEventCategory: String {
    case authentication = "AUTHENTICATION"
    case deviceControl = "DEVICE_CONTROL"
    case userManagement = "USER_MANAGEMENT"
    case security = "SECURITY"
    case configuration = "CONFIGURATION"
    case system = "SYSTEM"
}

/// Log event actions
public enum LogEventAction: String {
    // Authentication actions
    case login = "LOGIN"
    case logout = "LOGOUT"
    case refreshToken = "REFRESH_TOKEN"
    
    // Device control actions
    case executeCommand = "EXECUTE_COMMAND"
    case fetchDevices = "FETCH_DEVICES"
    case getDeviceState = "GET_DEVICE_STATE"
    
    // Security actions
    case rateLimitExceeded = "RATE_LIMIT_EXCEEDED"
    case biometricAuth = "BIOMETRIC_AUTH"
    case permissionDenied = "PERMISSION_DENIED"
}

/// Log event status
public enum LogEventStatus: String {
    case success = "SUCCESS"
    case failed = "FAILED"
    case pending = "PENDING"
    case warning = "WARNING"
} 