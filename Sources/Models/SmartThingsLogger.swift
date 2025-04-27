import Foundation
import OSLog

/// Structured logging system for SmartThings operations
public class SmartThingsLogger {
    private let logger: Logger
    private let subsystem: String
    
    public static let shared = SmartThingsLogger()
    
    private init() {
        self.subsystem = "com.unifiedsmarthome.smartthings"
        self.logger = Logger(subsystem: subsystem, category: "SmartThings")
    }
    
    // MARK: - Logging Methods
    
    public func logError(_ error: SmartThingsError, context: [String: Any] = [:]) {
        let message = """
        Error: \(error.localizedDescription)
        Recovery: \(error.recoverySuggestion ?? "No recovery suggestion available")
        Context: \(context)
        """
        
        logger.error("\(message)")
        SmartThingsMetrics.shared.recordError(error)
    }
    
    public func logWarning(_ message: String, context: [String: Any] = [:]) {
        let formattedMessage = """
        Warning: \(message)
        Context: \(context)
        """
        
        logger.warning("\(formattedMessage)")
    }
    
    public func logInfo(_ message: String, context: [String: Any] = [:]) {
        let formattedMessage = """
        Info: \(message)
        Context: \(context)
        """
        
        logger.info("\(formattedMessage)")
    }
    
    public func logDebug(_ message: String, context: [String: Any] = [:]) {
        let formattedMessage = """
        Debug: \(message)
        Context: \(context)
        """
        
        logger.debug("\(formattedMessage)")
    }
    
    // MARK: - Device-Specific Logging
    
    public func logDeviceOperation(deviceId: String, operation: String, status: String, context: [String: Any] = [:]) {
        var operationContext = context
        operationContext["deviceId"] = deviceId
        operationContext["operation"] = operation
        operationContext["status"] = status
        
        logInfo("Device Operation", context: operationContext)
        SmartThingsMetrics.shared.recordDeviceOperation(deviceId: deviceId, operation: operation, status: status)
    }
    
    func logDeviceError(deviceId: String, error: SmartThingsError, context: [String: Any] = [:]) {
        var errorContext = context
        errorContext["deviceId"] = deviceId
        logError(error, context: errorContext)
    }
    
    // MARK: - Scene and Group Logging
    
    public func logSceneOperation(sceneId: String, operation: String, status: String, context: [String: Any] = [:]) {
        var operationContext = context
        operationContext["sceneId"] = sceneId
        operationContext["operation"] = operation
        operationContext["status"] = status
        
        logInfo("Scene Operation", context: operationContext)
        SmartThingsMetrics.shared.recordSceneOperation(sceneId: sceneId, operation: operation, status: status)
    }
    
    public func logGroupOperation(groupId: String, operation: String, status: String, context: [String: Any] = [:]) {
        var operationContext = context
        operationContext["groupId"] = groupId
        operationContext["operation"] = operation
        operationContext["status"] = status
        
        logInfo("Group Operation", context: operationContext)
        SmartThingsMetrics.shared.recordGroupOperation(groupId: groupId, operation: operation, status: status)
    }
} 