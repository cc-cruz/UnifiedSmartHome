import Foundation
import Combine
import Models

// API service for handling network requests
public class APIService {
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
    
    // Added public initializer
    public init() {}
    
    // MARK: - Authentication Methods
    
    // Login with email and password
    public func login(with credentials: LoginCredentials) -> AnyPublisher<AuthResponse, Error> {
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
    public func validateToken(token: String) -> AnyPublisher<User, Error> {
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
    public func getUser(id: String) async throws -> User {
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
    public func updateUserRole(userId: String, role: String) async throws {
        // In a real implementation, this would update the user's role via the API
        // For now, we'll just simulate a delay
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // If we get here, the operation was successful
    }
    
    // MARK: - Properties
    public func getProperties() -> AnyPublisher<[Property], SmartThingsError> {
        let endpoint = "/properties"
        
        return makeGetRequest(to: endpoint)
    }
    
    // MARK: - Devices
    public func getDevices(forProperty propertyId: String) -> AnyPublisher<[Device], SmartThingsError> {
        let endpoint = "/properties/\(propertyId)/devices"
        
        return makeGetRequest(to: endpoint)
    }
    
    public func controlDevice(deviceId: String, command: [String: AnyCodable]) -> AnyPublisher<Device, SmartThingsError> {
        let endpoint = "/devices/\(deviceId)/control"
        
        return makePostRequest(to: endpoint, with: command)
    }
    
    // MARK: - Generic Network Methods
    private func makeGetRequest<T: Decodable>(to endpoint: String) -> AnyPublisher<T, SmartThingsError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: SmartThingsError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { SmartThingsError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<T, SmartThingsError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: SmartThingsError.invalidResponse).eraseToAnyPublisher()
                }
                
                if (200..<300).contains(httpResponse.statusCode) {
                    return Just(data)
                        .decode(type: T.self, decoder: self.jsonDecoder)
                        .mapError { SmartThingsError.decodingError($0) }
                        .eraseToAnyPublisher()
                } else {
                    return Fail(error: SmartThingsError.serverError(httpResponse.statusCode)).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func makePostRequest<T: Encodable, U: Decodable>(to endpoint: String, with body: T) -> AnyPublisher<U, SmartThingsError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: SmartThingsError.invalidURL).eraseToAnyPublisher()
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
            return Fail(error: SmartThingsError.encodingError(error)).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { SmartThingsError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<U, SmartThingsError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: SmartThingsError.invalidResponse).eraseToAnyPublisher()
                }
                
                if (200..<300).contains(httpResponse.statusCode) {
                    return Just(data)
                        .decode(type: U.self, decoder: self.jsonDecoder)
                        .mapError { SmartThingsError.decodingError($0) }
                        .eraseToAnyPublisher()
                } else {
                    return Fail(error: SmartThingsError.serverError(httpResponse.statusCode)).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
} 