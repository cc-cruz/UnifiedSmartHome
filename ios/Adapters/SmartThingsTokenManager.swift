import Foundation

/// Manages the OAuth2 lifecycle for SmartThings tokens.
class SmartThingsTokenManager {
    
    // MARK: - Properties
    
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiration: Date?
    
    private let clientId = ProcessInfo.processInfo.environment["SMARTTHINGS_CLIENT_ID"] ?? ""
    private let clientSecret = ProcessInfo.processInfo.environment["SMARTTHINGS_CLIENT_SECRET"] ?? ""
    private let redirectUri = ProcessInfo.processInfo.environment["SMARTTHINGS_REDIRECT_URI"] ?? ""
    
    private let baseURL: String
    
    private let networkService: NetworkServiceProtocol
    private let keychainHelper: KeychainHelper
    
    // MARK: - Initializer
    
    init(networkService: NetworkServiceProtocol, baseURL: String, keychainHelper: KeychainHelper = KeychainHelper.shared) {
        self.networkService = networkService
        self.baseURL = baseURL
        self.keychainHelper = keychainHelper
        
        // Attempt to load existing tokens from the keychain
        loadTokensFromKeychain()
    }
    
    // MARK: - Public Methods
    
    func getValidToken() async throws -> String {
        // If we have a valid token, use it
        if let token = accessToken, let expiration = tokenExpiration, expiration > Date() {
            return token
        }
        
        // If there's a refresh token, try to refresh
        if let refreshToken = refreshToken {
            do {
                try await refreshAccessToken(refreshToken)
                if let validToken = accessToken {
                    return validToken
                }
            } catch {
                // Refresh failed, clear and rethrow
                clearTokens()
                throw AuthenticationError.tokenExpired
            }
        }
        
        throw AuthenticationError.notAuthenticated
    }
    
    func refreshAccessToken(_ refreshToken: String) async throws {
        // Create the request body for token refresh
        let parameters: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
            "client_secret": clientSecret
        ]
        
        // Convert parameters to HTTPBody data
        guard let bodyData = try? JSONSerialization.data(withJSONObject: parameters) else {
            throw AuthenticationError.invalidParameters
        }
        
        // Create URL request
        let tokenEndpoint = "\(baseURL)/oauth/token"
        guard let url = URL(string: tokenEndpoint) else {
            throw AuthenticationError.invalidEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Make the request
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Parse the response
            let decoder = JSONDecoder()
            let response = try decoder.decode(OAuthTokenResponse.self, from: data)
            
            // Store the new tokens
            storeTokensInKeychain(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresIn: response.expiresIn
            )
        } catch {
            throw AuthenticationError.refreshFailed(error)
        }
    }
    
    // MARK: - Keychain
    
    private func storeTokensInKeychain(accessToken: String, refreshToken: String, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpiration = Date().addingTimeInterval(TimeInterval(expiresIn))
        
        let tokenData = SmartThingsTokenData(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expirationDate: self.tokenExpiration!
        )
        
        do {
            let data = try JSONEncoder().encode(tokenData)
            try keychainHelper.save(data, service: "com.unifiedsmarthome.smartthings", account: "tokens")
        } catch {
            print("Failed to store tokens in keychain: \(error)")
        }
    }
    
    private func loadTokensFromKeychain() {
        do {
            if let data = try keychainHelper.get(service: "com.unifiedsmarthome.smartthings", account: "tokens") {
                let tokenData = try JSONDecoder().decode(SmartThingsTokenData.self, from: data)
                self.accessToken = tokenData.accessToken
                self.refreshToken = tokenData.refreshToken
                self.tokenExpiration = tokenData.expirationDate
            }
        } catch {
            print("Failed to load tokens from keychain: \(error)")
        }
    }
    
    private func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        self.tokenExpiration = nil
        do {
            try keychainHelper.delete(service: "com.unifiedsmarthome.smartthings", account: "tokens")
        } catch {
            print("Failed to delete tokens from keychain: \(error)")
        }
    }
}

/// Model for persisted token data.
struct SmartThingsTokenData: Codable {
    let accessToken: String
    let refreshToken: String
    let expirationDate: Date
}

/// OAuth token response format
struct OAuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

/// Example custom errors for authentication flows.
enum AuthenticationError: Error, LocalizedError {
    case notAuthenticated
    case tokenExpired
    case refreshFailed(Error)
    case invalidParameters
    case invalidEndpoint
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with SmartThings"
        case .tokenExpired:
            return "SmartThings token expired and refresh failed"
        case .refreshFailed(let error):
            return "Failed to refresh token: \(error.localizedDescription)"
        case .invalidParameters:
            return "Invalid parameters for authentication request"
        case .invalidEndpoint:
            return "Invalid authentication endpoint"
        }
    }
} 