import Foundation

// Protocol for analytics providers
protocol AnalyticsProvider {
    func trackEvent(_ name: String, parameters: [String: Any]?)
    func trackScreen(_ name: String, parameters: [String: Any]?)
    func trackError(_ error: Error, parameters: [String: Any]?)
    func setUserProperty(_ value: Any, forName name: String)
    func setUserID(_ userID: String)
}

// Main analytics service that can use multiple providers
class AnalyticsService {
    private var providers: [AnalyticsProvider] = []
    
    // Add a provider to the service
    func addProvider(_ provider: AnalyticsProvider) {
        providers.append(provider)
    }
    
    // Log an event across all providers
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        for provider in providers {
            provider.trackEvent(name, parameters: parameters)
        }
        
        // Log to console in debug mode
        #if DEBUG
        if let params = parameters {
            print("📊 ANALYTICS EVENT: \(name) - \(params)")
        } else {
            print("📊 ANALYTICS EVENT: \(name)")
        }
        #endif
    }
    
    // Track screen views
    func trackScreen(_ name: String, parameters: [String: Any]? = nil) {
        for provider in providers {
            provider.trackScreen(name, parameters: parameters)
        }
        
        // Log to console in debug mode
        #if DEBUG
        print("📱 SCREEN VIEW: \(name)")
        #endif
    }
    
    // Track errors
    func logError(_ error: Error, parameters: [String: Any]? = nil) {
        var mutableParams = parameters ?? [:]
        mutableParams["error_description"] = error.localizedDescription
        
        if let nsError = error as NSError? {
            mutableParams["error_code"] = nsError.code
            mutableParams["error_domain"] = nsError.domain
        }
        
        for provider in providers {
            provider.trackError(error, parameters: mutableParams)
        }
        
        // Log to console in debug mode
        #if DEBUG
        print("❌ ERROR: \(error.localizedDescription) - \(mutableParams)")
        #endif
    }
    
    // Set user properties
    func setUserProperty(_ value: Any, forName name: String) {
        for provider in providers {
            provider.setUserProperty(value, forName: name)
        }
    }
    
    // Set user ID
    func setUserID(_ userID: String) {
        for provider in providers {
            provider.setUserID(userID)
        }
    }
}

// Firebase Analytics provider implementation
class FirebaseAnalyticsProvider: AnalyticsProvider {
    func trackEvent(_ name: String, parameters: [String: Any]?) {
        // In a real implementation, this would use Firebase SDK
        // FirebaseAnalytics.logEvent(name, parameters: parameters)
    }
    
    func trackScreen(_ name: String, parameters: [String: Any]?) {
        // In a real implementation, this would use Firebase SDK
        // FirebaseAnalytics.logEvent(AnalyticsEventScreenView, parameters: ["screen_name": name])
    }
    
    func trackError(_ error: Error, parameters: [String: Any]?) {
        // In a real implementation, this would use Firebase SDK
        // FirebaseAnalytics.logEvent("error", parameters: parameters)
    }
    
    func setUserProperty(_ value: Any, forName name: String) {
        // In a real implementation, this would use Firebase SDK
        // FirebaseAnalytics.setUserProperty(String(describing: value), forName: name)
    }
    
    func setUserID(_ userID: String) {
        // In a real implementation, this would use Firebase SDK
        // FirebaseAnalytics.setUserID(userID)
    }
}

// Shared instance for easy access
extension AnalyticsService {
    static let shared: AnalyticsService = {
        let service = AnalyticsService()
        
        // Add providers
        #if !DEBUG
        service.addProvider(FirebaseAnalyticsProvider())
        #endif
        
        return service
    }()
} 