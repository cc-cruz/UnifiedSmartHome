import Foundation

/// Protocol for audit logging services
public protocol AuditLoggerProtocol {
    /// Log an event with type, status, and details
    func logEvent(type: AuditEventType, action: String, status: AuditEventStatus, details: [String: Any])
}

/// Audit event types
public enum AuditEventType: String {
    case authentication = "auth"
    case deviceOperation = "device_op"
    case adminAction = "admin"
    case security = "security"
    case systemEvent = "system"
}

/// Audit event statuses
public enum AuditEventStatus: String {
    case started = "started"
    case success = "success"
    case failed = "failed"
    case warning = "warning"
    case cancelled = "cancelled"
}

/// Default implementation to comply with SmartThings adapter
extension AuditLogger: AuditLoggerProtocol {
    public func logEvent(type: AuditEventType, action: String, status: AuditEventStatus, details: [String: Any]) {
        var eventDetails = details
        eventDetails["action"] = action
        eventDetails["status"] = status.rawValue
        
        switch type {
        case .authentication:
            logSecurityEvent(type: "auth_\(action)", details: eventDetails)
        case .deviceOperation:
            logSensitiveOperation(type: action, details: eventDetails)
        case .security:
            logSecurityEvent(type: action, details: eventDetails)
        case .adminAction:
            logSecurityEvent(type: "admin_\(action)", details: eventDetails)
        case .systemEvent:
            logSensitiveOperation(type: "system_\(action)", details: eventDetails)
        }
    }
} 