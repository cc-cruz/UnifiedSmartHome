import Foundation
import Combine
import Models

// Network service implementation conforming to public protocol
public class NetworkService: Models.NetworkServiceProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    public init(session: URLSession = .shared) {
        self.session = session
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
        
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Standard HTTP Methods (Now Removed - Handled by Authenticated Methods)
    /* 
    func get<T: Decodable>(endpoint: String, headers: [String: String]? = nil) async throws -> T {
        guard let url = URL(string: endpoint) else { throw NetworkError.invalidURL(endpoint) } // Convert String to URL
        return try await request(url: url, method: "GET", headers: headers)
    }
    
    func post<T: Encodable, U: Decodable>(endpoint: String, body: T, headers: [String: String]? = nil) async throws -> U {
        guard let url = URL(string: endpoint) else { throw NetworkError.invalidURL(endpoint) } // Convert String to URL
        return try await request(url: url, method: "POST", body: body, headers: headers)
    }
    
    func put<T: Encodable, U: Decodable>(endpoint: String, body: T, headers: [String: String]? = nil) async throws -> U {
        guard let url = URL(string: endpoint) else { throw NetworkError.invalidURL(endpoint) } // Convert String to URL
        return try await request(url: url, method: "PUT", body: body, headers: headers)
    }
    
    func delete<T: Decodable>(endpoint: String, headers: [String: String]? = nil) async throws -> T {
        guard let url = URL(string: endpoint) else { throw NetworkError.invalidURL(endpoint) } // Convert String to URL
        return try await request(url: url, method: "DELETE", headers: headers)
    }
    */

    // MARK: - Authenticated HTTP Methods (Conforming to public protocol)
    
    public func authenticatedGet<T: Decodable>(
        url: URL,
        headers: [String: String]? = nil
    ) async throws -> T {
        return try await request(url: url, method: "GET", headers: addAuthHeader(to: headers))
    }
    
    public func authenticatedPost<T: Decodable, U: Encodable>(
        url: URL,
        body: U,
        headers: [String: String]? = nil
    ) async throws -> T {
        return try await request(url: url, method: "POST", body: body, headers: addAuthHeader(to: headers))
    }
    
    public func authenticatedPut<T: Decodable, U: Encodable>(
        url: URL,
        body: U,
        headers: [String: String]? = nil
    ) async throws -> T {
        return try await request(url: url, method: "PUT", body: body, headers: addAuthHeader(to: headers))
    }
    
    public func authenticatedDelete(
        url: URL,
        headers: [String: String]? = nil
    ) async throws {
        _ = try await request(url: url, method: "DELETE", headers: addAuthHeader(to: headers)) as EmptyResponse
    }

    // Helper to add Authorization header (assumes token is managed internally)
    private func addAuthHeader(to headers: [String: String]?) -> [String: String] {
        var newHeaders = headers ?? [:]
        // TODO: Replace with actual token retrieval logic
        let token = "DUMMY_TOKEN" // Placeholder
        newHeaders["Authorization"] = "Bearer \(token)"
        return newHeaders
    }

    // MARK: - Secure Request (Keep as is for now, assuming it's needed internally or by another protocol)
    
    public func performSecureRequest(
        url: URL,
        method: String,
        body: Data?,
        headers: [String: String]?
    ) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        headers?.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await session.data(for: request)
        return (data, response)
    }

    // MARK: - Certificate Validation (Keep as is for now)
    
    public func validateCertificates(_ serverTrust: Any) -> Bool {
        return true
    }
    
    // MARK: - Private Helper Methods (Updated to use URL)
    
    private func request<T: Decodable>(url: URL, method: String, headers: [String: String]? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        headers?.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        return try await performRequest(request)
    }
    
    private func request<T: Encodable, U: Decodable>(url: URL, method: String, body: T, headers: [String: String]? = nil) async throws -> U {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        headers?.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Encode body
        request.httpBody = try encoder.encode(body)
        
        return try await performRequest(request)
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Check status code
            switch httpResponse.statusCode {
            case 200...299:
                if T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                }
                return try decoder.decode(T.self, from: data)
            case 401:
                throw NetworkError.unauthorized
            case 403:
                throw NetworkError.forbidden
            case 404:
                throw NetworkError.notFound
            case 429:
                throw NetworkError.rateLimited
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }
}

// Define EmptyResponse for methods that return Void
struct EmptyResponse: Codable, ExpressibleByNilLiteral {
    init(nilLiteral: ()) {}
    init() {}
}

// Network-related errors
enum NetworkError: Error, LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)
    case unexpectedStatusCode(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Rate limited by server"
        case .serverError(let code):
            return "Server error with code \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unexpectedStatusCode(let code):
            return "Unexpected status code: \(code)"
        }
    }
} 