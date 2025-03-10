import Foundation
import Combine

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int)
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

class APIService {
    private let baseURL = "http://localhost:3000/api"
    private let session = URLSession.shared
    private let jsonDecoder = JSONDecoder()
    
    // MARK: - Authentication
    func login(with credentials: LoginCredentials) -> AnyPublisher<AuthResponse, APIError> {
        let endpoint = "/auth/login"
        
        return makePostRequest(to: endpoint, with: credentials)
    }
    
    func register(firstName: String, lastName: String, email: String, password: String) -> AnyPublisher<AuthResponse, APIError> {
        let endpoint = "/auth/register"
        let body = [
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "password": password
        ]
        
        return makePostRequest(to: endpoint, with: body)
    }
    
    // MARK: - Properties
    func getProperties() -> AnyPublisher<[Property], APIError> {
        let endpoint = "/properties"
        
        return makeGetRequest(to: endpoint)
    }
    
    // MARK: - Devices
    func getDevices(forProperty propertyId: String) -> AnyPublisher<[Device], APIError> {
        let endpoint = "/properties/\(propertyId)/devices"
        
        return makeGetRequest(to: endpoint)
    }
    
    func controlDevice(deviceId: String, command: [String: Any]) -> AnyPublisher<Device, APIError> {
        let endpoint = "/devices/\(deviceId)/control"
        
        return makePostRequest(to: endpoint, with: command)
    }
    
    // MARK: - Generic Network Methods
    private func makeGetRequest<T: Decodable>(to endpoint: String) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<T, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                }
                
                if (200..<300).contains(httpResponse.statusCode) {
                    return Just(data)
                        .decode(type: T.self, decoder: self.jsonDecoder)
                        .mapError { APIError.decodingError($0) }
                        .eraseToAnyPublisher()
                } else {
                    return Fail(error: APIError.serverError(httpResponse.statusCode)).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func makePostRequest<T: Encodable, U: Decodable>(to endpoint: String, with body: T) -> AnyPublisher<U, APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let encodedBody = try JSONEncoder().encode(body)
            request.httpBody = encodedBody
        } catch {
            return Fail(error: APIError.decodingError(error)).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<U, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                }
                
                if (200..<300).contains(httpResponse.statusCode) {
                    return Just(data)
                        .decode(type: U.self, decoder: self.jsonDecoder)
                        .mapError { APIError.decodingError($0) }
                        .eraseToAnyPublisher()
                } else {
                    return Fail(error: APIError.serverError(httpResponse.statusCode)).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
} 