import Foundation

/// Protocol for network service interactions with device APIs
public protocol NetworkServiceProtocol {
    /// Perform an authenticated GET request
    /// - Parameters:
    ///   - url: The URL to request
    ///   - headers: Any additional headers
    /// - Returns: Decoded object of requested type
    func authenticatedGet<T: Decodable>(
        url: URL,
        headers: [String: String]?
    ) async throws -> T
    
    /// Perform an authenticated POST request
    /// - Parameters:
    ///   - url: The URL to request
    ///   - body: The request body
    ///   - headers: Any additional headers
    /// - Returns: Decoded object of requested type
    func authenticatedPost<T: Decodable, U: Encodable>(
        url: URL,
        body: U,
        headers: [String: String]?
    ) async throws -> T
    
    /// Perform an authenticated PUT request
    /// - Parameters:
    ///   - url: The URL to request
    ///   - body: The request body
    ///   - headers: Any additional headers
    /// - Returns: Decoded object of requested type
    func authenticatedPut<T: Decodable, U: Encodable>(
        url: URL,
        body: U,
        headers: [String: String]?
    ) async throws -> T
    
    /// Perform an authenticated DELETE request
    /// - Parameters:
    ///   - url: The URL to request
    ///   - headers: Any additional headers
    func authenticatedDelete(
        url: URL,
        headers: [String: String]?
    ) async throws
    
    /// Perform a request with certificate pinning
    /// - Parameters:
    ///   - url: The URL to request
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - body: The request body
    ///   - headers: Any additional headers
    /// - Returns: Response data and HTTP response
    func performSecureRequest(
        url: URL,
        method: String,
        body: Data?,
        headers: [String: String]?
    ) async throws -> (Data, URLResponse)
    
    /// Validate certificates for secure connections
    /// - Parameter serverTrust: The server trust to validate
    /// - Returns: Whether certificates are valid
    func validateCertificates(_ serverTrust: Any) -> Bool
} 