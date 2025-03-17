import Foundation
import Combine

// Protocol for network services
protocol NetworkServiceProtocol {
    func get<T: Decodable>(endpoint: String, headers: [String: String]?) async throws -> T
    func post<T: Encodable, U: Decodable>(endpoint: String, body: T, headers: [String: String]?) async throws -> U
    func put<T: Encodable, U: Decodable>(endpoint: String, body: T, headers: [String: String]?) async throws -> U
    func delete<T: Decodable>(endpoint: String, headers: [String: String]?) async throws -> T
    
    func authenticatedGet<T: Decodable>(endpoint: String, token: String, headers: [String: String]?) async throws -> T
    func authenticatedPost<T: Encodable, U: Decodable>(endpoint: String, token: String, body: T, headers: [String: String]?) async throws -> U
    func authenticatedPut<T: Encodable, U: Decodable>(endpoint: String, token: String, body: T, headers: [String: String]?) async throws -> U
    func authenticatedDelete<T: Decodable>(endpoint: String, token: String, headers: [String: String]?) async throws -> T
}

// Network service implementation
class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(session: URLSession = .shared) {
        self.session = session
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
        
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Standard HTTP Methods
    
    func get<T: Decodable>(endpoint: String, headers: [String: String]? = nil) async throws -> T {
        return try await request(endpoint: endpoint, method: "GET", headers: headers)
    }
    
    func post<T: Encodable, U: Decodable>(endpoint: String, body: T, headers: [String: String]? = nil) async throws -> U {
        return try await request(endpoint: endpoint, method: "POST", body: body, headers: headers)
    }
    
    func put<T: Encodable, U: Decodable>(endpoint: String, body: T, headers: [String: String]? = nil) async throws -> U {
        return try await request(endpoint: endpoint, method: "PUT", body: body, headers: headers)
    }
    
    func delete<T: Decodable>(endpoint: String, headers: [String: String]? = nil) async throws -> T {
        return try await request(endpoint: endpoint, method: "DELETE", headers: headers)
    }
    
    // MARK: - Authenticated HTTP Methods
    
    func authenticatedGet<T: Decodable>(endpoint: String, token: String, headers: [String: String]? = nil) async throws -> T {
        var authHeaders = headers ?? [:]
        authHeaders["Authorization"] = "Bearer \(token)"
        return try await get(endpoint: endpoint, headers: authHeaders)
    }
    
    func authenticatedPost<T: Encodable, U: Decodable>(endpoint: String, token: String, body: T, headers: [String: String]? = nil) async throws -> U {
        var authHeaders = headers ?? [:]
        authHeaders["Authorization"] = "Bearer \(token)"
        return try await post(endpoint: endpoint, body: body, headers: authHeaders)
    }
    
    func authenticatedPut<T: Encodable, U: Decodable>(endpoint: String, token: String, body: T, headers: [String: String]? = nil) async throws -> U {
        var authHeaders = headers ?? [:]
        authHeaders["Authorization"] = "Bearer \(token)"
        return try await put(endpoint: endpoint, body: body, headers: authHeaders)
    }
    
    func authenticatedDelete<T: Decodable>(endpoint: String, token: String, headers: [String: String]? = nil) async throws -> T {
        var authHeaders = headers ?? [:]
        authHeaders["Authorization"] = "Bearer \(token)"
        return try await delete(endpoint: endpoint, headers: authHeaders)
    }
    
    // MARK: - Private Helper Methods
    
    private func request<T: Decodable>(endpoint: String, method: String, headers: [String: String]? = nil) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL(endpoint)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        headers?.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        return try await performRequest(request)
    }
    
    private func request<T: Encodable, U: Decodable>(endpoint: String, method: String, body: T, headers: [String: String]? = nil) async throws -> U {
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL(endpoint)
        }
        
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
                // Success
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw NetworkError.decodingError(error)
                }
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