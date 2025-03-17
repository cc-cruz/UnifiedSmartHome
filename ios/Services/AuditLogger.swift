import Foundation

class AuditLogger {
    private let analyticsService: AnalyticsService
    private let persistentStorage: AuditLogStorage
    
    init(analyticsService: AnalyticsService, persistentStorage: AuditLogStorage) {
        self.analyticsService = analyticsService
        self.persistentStorage = persistentStorage
    }
    
    // Log security events (access attempts, permission checks, etc.)
    func logSecurityEvent(type: String, details: [String: Any]) {
        let logEntry = createLogEntry(type: type, details: details, category: "security")
        
        // Store locally for audit trail
        persistentStorage.storeLog(logEntry)
        
        // Send to analytics for monitoring
        analyticsService.logEvent("security_\(type)", parameters: details)
        
        // Print to console in debug mode
        #if DEBUG
        print("🔒 SECURITY: \(type) - \(details)")
        #endif
    }
    
    // Log sensitive operations (lock/unlock, etc.)
    func logSensitiveOperation(type: String, details: [String: Any]) {
        let logEntry = createLogEntry(type: type, details: details, category: "operation")
        
        // Store locally for audit trail
        persistentStorage.storeLog(logEntry)
        
        // Send to analytics for monitoring
        analyticsService.logEvent("operation_\(type)", parameters: details)
        
        // Print to console in debug mode
        #if DEBUG
        print("⚙️ OPERATION: \(type) - \(details)")
        #endif
    }
    
    // Log operation results
    func logOperationResult(type: String, success: Bool, details: [String: Any]) {
        var mutableDetails = details
        mutableDetails["success"] = success
        
        let logEntry = createLogEntry(
            type: "\(type)_result",
            details: mutableDetails,
            category: "result"
        )
        
        // Store locally for audit trail
        persistentStorage.storeLog(logEntry)
        
        // Send to analytics for monitoring
        analyticsService.logEvent("result_\(type)", parameters: mutableDetails)
        
        // Print to console in debug mode
        #if DEBUG
        print("📊 RESULT: \(type) - \(success ? "SUCCESS" : "FAILURE") - \(details)")
        #endif
    }
    
    // Helper to create a standardized log entry
    private func createLogEntry(type: String, details: [String: Any], category: String) -> AuditLogEntry {
        return AuditLogEntry(
            timestamp: Date(),
            type: type,
            category: category,
            details: details,
            userId: UserManager.shared.currentUser?.id ?? "unknown"
        )
    }
}

// Protocol for audit log storage
protocol AuditLogStorage {
    func storeLog(_ logEntry: AuditLogEntry)
    func getLogs(startDate: Date?, endDate: Date?, type: String?, limit: Int) -> [AuditLogEntry]
    func clearLogs(olderThan: Date)
}

// Audit log entry model
struct AuditLogEntry: Codable {
    let id: UUID
    let timestamp: Date
    let type: String
    let category: String
    let details: [String: String] // Simplified for Codable
    let userId: String
    
    init(timestamp: Date, type: String, category: String, details: [String: Any], userId: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.type = type
        self.category = category
        
        // Convert Any values to String for storage
        var stringDetails: [String: String] = [:]
        for (key, value) in details {
            stringDetails[key] = "\(value)"
        }
        self.details = stringDetails
        
        self.userId = userId
    }
}

// Concrete implementation of audit log storage using Core Data
class CoreDataAuditLogStorage: AuditLogStorage {
    // In a real implementation, this would use Core Data
    // For now, we'll use a simple in-memory array
    private var logs: [AuditLogEntry] = []
    
    func storeLog(_ logEntry: AuditLogEntry) {
        logs.append(logEntry)
        
        // In a real implementation, we would save to Core Data
        // and potentially sync with a backend for centralized audit logs
    }
    
    func getLogs(startDate: Date? = nil, endDate: Date? = nil, type: String? = nil, limit: Int = 100) -> [AuditLogEntry] {
        var filteredLogs = logs
        
        if let startDate = startDate {
            filteredLogs = filteredLogs.filter { $0.timestamp >= startDate }
        }
        
        if let endDate = endDate {
            filteredLogs = filteredLogs.filter { $0.timestamp <= endDate }
        }
        
        if let type = type {
            filteredLogs = filteredLogs.filter { $0.type == type }
        }
        
        // Sort by timestamp (newest first)
        filteredLogs.sort { $0.timestamp > $1.timestamp }
        
        // Apply limit
        if filteredLogs.count > limit {
            filteredLogs = Array(filteredLogs.prefix(limit))
        }
        
        return filteredLogs
    }
    
    func clearLogs(olderThan: Date) {
        logs.removeAll { $0.timestamp < olderThan }
        
        // In a real implementation, we would delete from Core Data
    }
} 