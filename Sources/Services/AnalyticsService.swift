import Foundation

// Protocol for different analytics providers (Firebase, Segment, etc.)
public protocol AnalyticsProvider {
    func logEvent(_ name: String, parameters: [String: Any]?)
    func setUserProperty(_ name: String, value: String?)
    func setUserID(_ id: String?)
}

// Main analytics service that can use multiple providers
public class AnalyticsService {
    private var providers: [AnalyticsProvider] = []
    
    // Singleton for easy access (consider dependency injection for testability)
    public static let shared = AnalyticsService()
    
    public init() {}
    
    public func register(provider: AnalyticsProvider) {
        providers.append(provider)
    }
    
    public func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        // Sanitize event name (replace spaces, invalid chars)
        let sanitizedName = sanitizeEventName(name)
        
        // Sanitize parameters (check types, lengths)
        let sanitizedParams = sanitizeParameters(parameters)
        
        // Print to console in debug
        #if DEBUG
        print("📊 ANALYTICS: Event '\(sanitizedName)' - Params: \(sanitizedParams ?? [:])")
        #endif
        
        // Forward to all registered providers
        for provider in providers {
            provider.logEvent(sanitizedName, parameters: sanitizedParams)
        }
    }
    
    public func setUserProperty(_ name: String, value: String?) {
        // Sanitize property name and value
        let sanitizedName = sanitizePropertyName(name)
        let sanitizedValue = sanitizePropertyValue(value)
        
        // Print to console in debug
        #if DEBUG
        print("📊 ANALYTICS: Set User Property '\(sanitizedName)' = \(sanitizedValue ?? "nil")")
        #endif
        
        // Forward to all registered providers
        for provider in providers {
            provider.setUserProperty(sanitizedName, value: sanitizedValue)
        }
    }
    
    public func setUserID(_ id: String?) {
        // Print to console in debug
        #if DEBUG
        print("📊 ANALYTICS: Set User ID = \(id ?? "nil")")
        #endif
        
        // Forward to all registered providers
        for provider in providers {
            provider.setUserID(id)
        }
    }
    
    // MARK: - Sanitization Helpers (Private)
    
    private func sanitizeEventName(_ name: String) -> String {
        // Replace spaces with underscores, remove special characters
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return name.components(separatedBy: allowedChars.inverted).joined(separator: "_").lowercased()
    }
    
    private func sanitizePropertyName(_ name: String) -> String {
        // Similar sanitization as event names
        return sanitizeEventName(name)
    }
    
    private func sanitizePropertyValue(_ value: String?) -> String? {
        // Trim whitespace, limit length if necessary
        return value?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100).description
    }
    
    private func sanitizeParameters(_ parameters: [String: Any]?) -> [String: Any]? {
        guard let params = parameters else { return nil }
        var sanitized: [String: Any] = [:]
        
        for (key, value) in params {
            let sanitizedKey = sanitizePropertyName(key)
            
            // Convert values to supported types (String, Number, Bool)
            if let stringValue = value as? String {
                sanitized[sanitizedKey] = sanitizePropertyValue(stringValue)
            } else if let numberValue = value as? NSNumber { // Handles Int, Double, Bool
                sanitized[sanitizedKey] = numberValue
            } else if let dateValue = value as? Date {
                 sanitized[sanitizedKey] = ISO8601DateFormatter().string(from: dateValue) // Convert dates
            } else {
                // Skip or convert other types to string
                 sanitized[sanitizedKey] = sanitizePropertyValue("\(value)")
            }
            
            // Truncate long strings within parameters
            if let strVal = sanitized[sanitizedKey] as? String, strVal.count > 100 {
                sanitized[sanitizedKey] = strVal.prefix(100).description
            }
        }
        return sanitized
    }
}

// Example Mock provider for testing
class MockAnalyticsProvider: AnalyticsProvider {
    var loggedEvents: [(name: String, parameters: [String: Any]?)] = []
    var userProperties: [String: String?] = [:]
    var userID: String?
    
    func logEvent(_ name: String, parameters: [String : Any]?) {
        loggedEvents.append((name, parameters))
    }
    
    func setUserProperty(_ name: String, value: String?) {
        userProperties[name] = value
    }
    
    func setUserID(_ id: String?) {
        self.userID = id
    }
} 