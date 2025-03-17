import Foundation
import Combine

// API service for handling network requests
class APIService {
    // Base URL for API requests
    private let baseURL = "https://api.unifiedsmarthome.com"
    
    // Shared URLSession
    private let session = URLSession.shared
    
    // JSON decoder with configuration
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    // MARK: - Authentication Methods
    
    // Login with email and password
    func login(with credentials: LoginCredentials) -> AnyPublisher<AuthResponse, Error> {
        // In a real implementation, this would make an API call
        // For now, we'll simulate a successful login
        
        return Future<AuthResponse, Error> { promise in
            // Simulate network delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Create a mock user
                let user = User(
                    id: "user1",
                    email: credentials.email,
                    firstName: "Demo",
                    lastName: "User",
                    role: .owner,
                    properties: [],
                    assignedRooms: []
                )
                
                // Create a mock token
                let token = "mock_token_\(UUID().uuidString)"
                
                // Return the response
                promise(.success(AuthResponse(user: user, token: token)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // Validate token
    func validateToken(token: String) -> AnyPublisher<User, Error> {
        // In a real implementation, this would validate the token with the API
        // For now, we'll simulate a valid token
        
        return Future<User, Error> { promise in
            // Simulate network delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Create a mock user
                let user = User(
                    id: "user1",
                    email: "demo@example.com",
                    firstName: "Demo",
                    lastName: "User",
                    role: .owner,
                    properties: [],
                    assignedRooms: []
                )
                
                // Return the user
                promise(.success(user))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - User Methods
    
    // Get user by ID
    func getUser(id: String) async throws -> User {
        // In a real implementation, this would fetch the user from the API
        // For now, we'll return a mock user
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Return a mock user
        return User(
            id: id,
            email: "user\(id)@example.com",
            firstName: "User",
            lastName: "\(id)",
            role: .owner,
            properties: [],
            assignedRooms: []
        )
    }
    
    // Update user role
    func updateUserRole(userId: String, role: String) async throws {
        // In a real implementation, this would update the user's role via the API
        // For now, we'll just simulate a delay
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // If we get here, the operation was successful
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