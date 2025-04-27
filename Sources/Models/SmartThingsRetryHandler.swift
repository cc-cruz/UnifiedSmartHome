import Foundation

/// Handles retry logic for SmartThings operations
public class SmartThingsRetryHandler {
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let jitter: Double
    
    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        jitter: Double = 0.1
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitter = jitter
    }
    
    /// Executes an operation with retry logic
    /// - Parameters:
    ///   - operation: The async operation to execute
    ///   - errorHandler: Optional handler for specific error cases
    /// - Returns: The result of the operation
    /// - Throws: The final error if all retries fail
    public func execute<T>(
        _ operation: () async throws -> T,
        errorHandler: ((SmartThingsError) -> Void)? = nil
    ) async throws -> T {
        var currentRetry = 0
        var lastError: Error?
        
        while currentRetry <= maxRetries {
            do {
                return try await operation()
            } catch let error as SmartThingsError {
                lastError = error
                
                // Handle specific error cases
                errorHandler?(error)
                
                // Check if error is recoverable
                guard error.isRecoverable else {
                    throw error
                }
                
                // Calculate delay with exponential backoff and jitter
                let delay = calculateDelay(for: error, attempt: currentRetry)
                
                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                currentRetry += 1
            } catch {
                // For non-SmartThings errors, throw immediately
                throw error
            }
        }
        
        // If we've exhausted all retries, throw the last error
        throw lastError ?? SmartThingsError.networkError(NSError(domain: "SmartThings", code: -1))
    }
    
    /// Calculates the delay for the next retry attempt
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - attempt: The current retry attempt number
    /// - Returns: The delay in seconds
    private func calculateDelay(for error: SmartThingsError, attempt: Int) -> TimeInterval {
        // Use error-specific delay if available
        let errorDelay = error.retryDelay
        if errorDelay > 0 {
            return errorDelay
        }
        
        // Calculate exponential backoff
        let exponentialDelay = min(
            baseDelay * pow(2.0, Double(attempt)),
            maxDelay
        )
        
        // Add jitter to prevent thundering herd
        let jitterAmount = exponentialDelay * jitter
        let jitteredDelay = exponentialDelay + Double.random(in: -jitterAmount...jitterAmount)
        
        return max(0.1, jitteredDelay)
    }
}

// MARK: - Convenience Methods

extension SmartThingsRetryHandler {
    /// Executes a network request with retry logic
    /// - Parameters:
    ///   - request: The URL request to execute
    ///   - session: The URL session to use
    ///   - errorHandler: Optional handler for specific error cases
    /// - Returns: The response data
    /// - Throws: The final error if all retries fail
    public func executeRequest(
        _ request: URLRequest,
        session: URLSession,
        errorHandler: ((SmartThingsError) -> Void)? = nil
    ) async throws -> Data {
        try await execute(
            {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SmartThingsError.invalidResponse
                }
                
                // Handle HTTP status codes
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw SmartThingsError.tokenExpired
                case 403:
                    throw SmartThingsError.unauthorized
                case 404:
                    throw SmartThingsError.deviceNotFound(request.url?.lastPathComponent ?? "")
                case 429:
                    throw SmartThingsError.rateLimitExceeded
                case 500...599:
                    throw SmartThingsError.networkError(NSError(domain: "SmartThings", code: httpResponse.statusCode))
                default:
                    throw SmartThingsError.invalidResponse
                }
            },
            errorHandler: errorHandler
        )
    }
} 