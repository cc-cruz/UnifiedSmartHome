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
    
    /// Login with email and password
    /// Returns an AuthResponse containing the user with full tenancy context and auth token
    public func login(with credentials: LoginCredentials) -> AnyPublisher<AuthResponse, SmartThingsError> {
        let endpoint = "/api/auth/login"
        return makePostRequest(to: endpoint, with: credentials)
    }
    
    /// Get current user profile with full tenancy context
    public func getCurrentUser() -> AnyPublisher<User, SmartThingsError> {
        let endpoint = "/api/v1/users/me"
        return makeGetRequest(to: endpoint)
    }
    
    // MARK: - Device Methods
    
    /// Fetch devices with multi-tenancy context (portfolioId/propertyId/unitId)
    public func getDevices(
        portfolioId: String? = nil,
        propertyId: String? = nil,
        unitId: String? = nil
    ) -> AnyPublisher<[Device], SmartThingsError> {
        var endpoint = "/api/v1/devices"
        var queryItems: [String] = []
        if let pid = portfolioId { queryItems.append("portfolioId=\(pid)") }
        if let propId = propertyId { queryItems.append("propertyId=\(propId)") }
        if let unit = unitId { queryItems.append("unitId=\(unit)") }
        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }
        return makeGetRequest(to: endpoint)
    }
    
    /// Control a device with specified command
    public func controlDevice(deviceId: String, command: [String: AnyCodable]) -> AnyPublisher<Device, SmartThingsError> {
        let endpoint = "/api/v1/devices/\(deviceId)/control"
        return makePostRequest(to: endpoint, with: command)
    }
    
    // MARK: - Portfolio Methods
    
    /// Fetch portfolios with pagination support
    public func getPortfolios(
        page: Int? = nil,
        limit: Int? = nil,
        sortBy: String? = nil
    ) -> AnyPublisher<PaginatedResponse<Portfolio>, SmartThingsError> {
        var endpoint = "/api/v1/portfolios"
        var queryItems: [String] = []
        if let p = page { queryItems.append("page=\(p)") }
        if let l = limit { queryItems.append("limit=\(l)") }
        if let s = sortBy { queryItems.append("sortBy=\(s)") }
        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }
        return makeGetRequest(to: endpoint)
    }
    
    /// Get portfolio details by ID
    public func getPortfolioDetails(portfolioId: String) -> AnyPublisher<Portfolio, SmartThingsError> {
        let endpoint = "/api/v1/portfolios/\(portfolioId)"
        return makeGetRequest(to: endpoint)
    }
    
    /// Create a new portfolio
    public func createPortfolio(
        name: String,
        administratorUserIds: [String]? = nil
    ) -> AnyPublisher<Portfolio, SmartThingsError> {
        let endpoint = "/api/v1/portfolios"
        struct CreatePortfolioRequest: Codable {
            let name: String
            let administratorUserIds: [String]?
        }
        let body = CreatePortfolioRequest(name: name, administratorUserIds: administratorUserIds)
        return makePostRequest(to: endpoint, with: body)
    }
    
    // MARK: - Property Methods
    
    /// Fetch properties with optional portfolio filtering and pagination
    public func getProperties(
        portfolioId: String? = nil,
        page: Int? = nil,
        limit: Int? = nil,
        sortBy: String? = nil
    ) -> AnyPublisher<PaginatedResponse<Property>, SmartThingsError> {
        var endpoint = "/api/v1/properties"
        var queryItems: [String] = []
        if let pid = portfolioId { queryItems.append("portfolioId=\(pid)") }
        if let p = page { queryItems.append("page=\(p)") }
        if let l = limit { queryItems.append("limit=\(l)") }
        if let s = sortBy { queryItems.append("sortBy=\(s)") }
        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }
        return makeGetRequest(to: endpoint)
    }
    
    /// Get property details by ID
    public func getPropertyDetails(propertyId: String) -> AnyPublisher<Property, SmartThingsError> {
        let endpoint = "/api/v1/properties/\(propertyId)"
        return makeGetRequest(to: endpoint)
    }
    
    /// Create a new property
    public func createProperty(
        name: String,
        portfolioId: String,
        address: PropertyAddress? = nil,
        managerUserIds: [String]? = nil
    ) -> AnyPublisher<Property, SmartThingsError> {
        let endpoint = "/api/v1/properties"
        struct CreatePropertyRequest: Codable {
            let name: String
            let portfolioId: String
            let address: PropertyAddress?
            let managerUserIds: [String]?
        }
        let body = CreatePropertyRequest(
            name: name,
            portfolioId: portfolioId,
            address: address,
            managerUserIds: managerUserIds
        )
        return makePostRequest(to: endpoint, with: body)
    }
    
    // MARK: - Unit Methods
    
    /// Fetch units with optional property filtering and pagination
    public func getUnits(
        propertyId: String? = nil,
        page: Int? = nil,
        limit: Int? = nil,
        sortBy: String? = nil
    ) -> AnyPublisher<PaginatedResponse<Unit>, SmartThingsError> {
        var endpoint = "/api/v1/units"
        var queryItems: [String] = []
        if let pid = propertyId { queryItems.append("propertyId=\(pid)") }
        if let p = page { queryItems.append("page=\(p)") }
        if let l = limit { queryItems.append("limit=\(l)") }
        if let s = sortBy { queryItems.append("sortBy=\(s)") }
        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }
        return makeGetRequest(to: endpoint)
    }
    
    /// Get unit details by ID
    public func getUnitDetails(unitId: String) -> AnyPublisher<Unit, SmartThingsError> {
        let endpoint = "/api/v1/units/\(unitId)"
        return makeGetRequest(to: endpoint)
    }
    
    /// Get tenants for a specific unit
    public func getUnitTenants(unitId: String) -> AnyPublisher<[User], SmartThingsError> {
        let endpoint = "/api/v1/units/\(unitId)/tenants"
        return makeGetRequest(to: endpoint)
            .map { (response: UnitTenantsResponse) in response.data.users }
            .eraseToAnyPublisher()
    }
    
    /// Add a tenant to a unit
    public func addTenantToUnit(unitId: String, userId: String) -> AnyPublisher<UserRoleAssociation, SmartThingsError> {
        let endpoint = "/api/v1/units/\(unitId)/tenants"
        struct AddTenantRequest: Codable {
            let userId: String
        }
        let body = AddTenantRequest(userId: userId)
        return makePostRequest(to: endpoint, with: body)
            .map { (response: AddTenantResponse) in response.data.userRoleAssociation }
            .eraseToAnyPublisher()
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
                    // Try to decode error response
                    do {
                        let errorResponse = try self.jsonDecoder.decode(ErrorResponse.self, from: data)
                        return Fail(error: SmartThingsError.apiError(errorResponse)).eraseToAnyPublisher()
                    } catch {
                        return Fail(error: SmartThingsError.serverError(httpResponse.statusCode)).eraseToAnyPublisher()
                    }
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
                    // Try to decode error response
                    do {
                        let errorResponse = try self.jsonDecoder.decode(ErrorResponse.self, from: data)
                        return Fail(error: SmartThingsError.apiError(errorResponse)).eraseToAnyPublisher()
                    } catch {
                        return Fail(error: SmartThingsError.serverError(httpResponse.statusCode)).eraseToAnyPublisher()
                    }
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Types
    
    /// Generic paginated response wrapper
    public struct PaginatedResponse<T: Codable>: Codable {
        public let data: DataWrapper<[T]>
        public let pagination: PaginationInfo
        
        public struct DataWrapper<U: Codable>: Codable {
            public let items: U
        }
    }
    
    public struct PaginationInfo: Codable {
        public let totalItems: Int
        public let totalPages: Int
        public let currentPage: Int
        public let pageSize: Int
    }
    
    /// Response type for unit tenants endpoint
    private struct UnitTenantsResponse: Codable {
        let status: String
        let data: DataWrapper
        
        struct DataWrapper: Codable {
            let users: [User]
        }
    }
    
    /// Response type for adding tenant to unit
    private struct AddTenantResponse: Codable {
        let status: String
        let data: DataWrapper
        
        struct DataWrapper: Codable {
            let userRoleAssociation: UserRoleAssociation
        }
    }
    
    /// Error response from API
    private struct ErrorResponse: Codable {
        let status: String
        let message: String
        let details: String?
    }
} 