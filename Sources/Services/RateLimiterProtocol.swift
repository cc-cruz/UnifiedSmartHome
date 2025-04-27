import Foundation

/// Protocol for rate limiting service to prevent abuse
protocol RateLimiterProtocol {
    /// Checks if an action can be performed for a given identifier
    /// - Parameter identifier: Unique identifier for the action (e.g., device ID)
    /// - Returns: True if the action is allowed, false if it exceeds the rate limit
    func canPerformAction(for identifier: String) -> Bool
    
    /// Records that an action was performed for rate limiting purposes
    /// - Parameter identifier: Unique identifier for the action (e.g., device ID)
    func recordAction(for identifier: String)
} 