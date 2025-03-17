import Foundation

class AugustTokenManager {
    private let keychainHelper: KeychainHelper
    private let networkService: NetworkServiceProtocol
    private let apiKey: String
    
    private let tokenKey = "august_token"
    
    init(keychainHelper: KeychainHelper, networkService: NetworkServiceProtocol, apiKey: String = AugustConfiguration.apiKey) {
        self.keychainHelper = keychainHelper
        self.networkService = networkService
        self.apiKey = apiKey
    }
    
    func getValidToken() async throws -> String {
        // Try to retrieve cached token
        if let tokenData = try? keychainHelper.get(
            service: "com.smarthome.august",
            account: tokenKey
        ) {
            let decoder = JSONDecoder()
            if let token = try? decoder.decode(TokenData.self, from: tokenData),
               token.isValid {
                return token.accessToken
            }
        }
        
        // Token not found or expired, need to login again
        return try await refreshAccessToken()
    }
    
    private func refreshAccessToken() async throws -> String {
        // August API typically uses a session-based authentication approach
        // rather than standard OAuth2
        
        struct AugustAuthRequest: Encodable {
            let apiKey: String
            let email: String
            let password: String
        }
        
        struct AugustAuthResponse: Decodable {
            let accessToken: String
            let expiresIn: Int
        }
        
        // Retrieve user credentials from secure storage
        guard let credentials = try? getAugustCredentials() else {
            throw AuthError.noCredentials
        }
        
        let request = AugustAuthRequest(
            apiKey: apiKey,
            email: credentials.email,
            password: credentials.password
        )
        
        // Make authentication request
        let response: AugustAuthResponse = try await networkService.post(
            endpoint: "\(AugustConfiguration.baseURL)/session",
            body: request
        )
        
        // Cache the new token
        let tokenData = TokenData(
            accessToken: response.accessToken,
            refreshToken: "", // August may not use refresh tokens
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(tokenData)
        try keychainHelper.save(
            data,
            service: "com.smarthome.august",
            account: tokenKey
        )
        
        return response.accessToken
    }
    
    // Get credentials from secure storage
    private func getAugustCredentials() throws -> (email: String, password: String) {
        guard let data = try? keychainHelper.get(
            service: "com.smarthome.august",
            account: "credentials"
        ) else {
            throw AuthError.noCredentials
        }
        
        struct Credentials: Codable {
            let email: String
            let password: String
        }
        
        let decoder = JSONDecoder()
        let credentials = try decoder.decode(Credentials.self, from: data)
        return (credentials.email, credentials.password)
    }
    
    // Save user credentials securely
    func saveCredentials(email: String, password: String) throws {
        struct Credentials: Codable {
            let email: String
            let password: String
        }
        
        let credentials = Credentials(email: email, password: password)
        let encoder = JSONEncoder()
        let data = try encoder.encode(credentials)
        
        try keychainHelper.save(
            data,
            service: "com.smarthome.august",
            account: "credentials"
        )
    }
    
    // Token data structure
    struct TokenData: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
        
        var isValid: Bool {
            return Date() < expiresAt
        }
    }
}

// Auth-related errors
enum AuthError: Error, LocalizedError {
    case noCredentials
    case invalidCredentials
    case tokenExpired
    case networkError
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No stored credentials found"
        case .invalidCredentials:
            return "Invalid username or password"
        case .tokenExpired:
            return "Authentication token has expired"
        case .networkError:
            return "Network error during authentication"
        case .serverError:
            return "Server error during authentication"
        }
    }
} 