import Foundation
import Combine
import Helpers
import Models
import Services

/// Manages the OAuth2 lifecycle for SmartThings tokens.
class SmartThingsTokenManager {
    
    // MARK: - Keychain Keys (Define constants)
    private static let accessTokenKey = "smartthings_access_token"
    private static let refreshTokenKey = "smartthings_refresh_token"
    private static let tokenExpiryKey = "smartthings_token_expiry"
    
    // MARK: - Properties
    
    private var accessToken: String? {
        get {
            // Use correct key constant
            return keychainHelper.getString(for: SmartThingsTokenManager.accessTokenKey)
        }
        set {
            if let newValue = newValue {
                 // Use correct key constant
                _ = keychainHelper.saveString(newValue, for: SmartThingsTokenManager.accessTokenKey)
            } else {
                 // Use correct key constant
                _ = keychainHelper.deleteItem(for: SmartThingsTokenManager.accessTokenKey)
            }
        }
    }
    
    private var refreshToken: String? {
        get {
            // Use correct key constant
            return keychainHelper.getString(for: SmartThingsTokenManager.refreshTokenKey)
        }
        set {
            if let newValue = newValue {
                 // Use correct key constant
                _ = keychainHelper.saveString(newValue, for: SmartThingsTokenManager.refreshTokenKey)
            } else {
                 // Use correct key constant
                _ = keychainHelper.deleteItem(for: SmartThingsTokenManager.refreshTokenKey)
            }
        }
    }
    
    private var tokenExpiry: Date? {
        get {
            // Use correct key constant and getData
            guard let data = keychainHelper.getData(for: SmartThingsTokenManager.tokenExpiryKey) else { return nil }
            return try? JSONDecoder().decode(Date.self, from: data)
        }
        set {
            if let newValue = newValue {
                do {
                    let data = try JSONEncoder().encode(newValue)
                    // Use correct key constant and saveData
                    _ = keychainHelper.saveData(data, for: SmartThingsTokenManager.tokenExpiryKey)
                } catch {
                    print("Error encoding tokenExpiry: \(error)")
                }
            } else {
                // Use correct key constant
                _ = keychainHelper.deleteItem(for: SmartThingsTokenManager.tokenExpiryKey)
            }
        }
    }
    
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
        if let token = accessToken, let expiration = tokenExpiry, expiration > Date() {
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
                throw SmartThingsAuthError.tokenExpired
            }
        }
        
        throw SmartThingsAuthError.notAuthenticated
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
            throw SmartThingsAuthError.invalidParameters
        }
        
        // Create URL request
        let tokenEndpoint = "\(baseURL)/oauth/token"
        guard let url = URL(string: tokenEndpoint) else {
            throw SmartThingsAuthError.invalidEndpoint
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
            throw SmartThingsAuthError.refreshFailed(error)
        }
    }
    
    // MARK: - Keychain
    
    private func storeTokensInKeychain(accessToken: String, refreshToken: String, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
        
        let tokenData = SmartThingsTokenData(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expirationDate: self.tokenExpiry!
        )
        
        do {
            let data = try JSONEncoder().encode(tokenData)
            // Construct a single key for KeychainHelper
            let keychainKey = "com.unifiedsmarthome.smartthings.tokens"
            _ = keychainHelper.saveData(data, for: keychainKey)
        } catch {
            print("Failed to store tokens in keychain: \(error)")
        }
    }
    
    private func loadTokensFromKeychain() {
        guard let data = keychainHelper.getData(for: "smartthings_combined_tokens") else {
            print("Original loadTokens: No combined token data found in keychain.")
            return
        }
        do {
            let tokenData = try JSONDecoder().decode([String: AnyCodable].self, from: data)
            self.accessToken = tokenData["accessToken"]?.value as? String
            self.refreshToken = tokenData["refreshToken"]?.value as? String
            self.tokenExpiry = tokenData["expiry"]?.value as? Date
            print("Original loadTokens: Successfully loaded tokens from keychain.")
        } catch {
            print("Original loadTokens: Failed to decode tokens from keychain: \(error)")
            _ = keychainHelper.deleteItem(for: "smartthings_combined_tokens")
        }
    }

    func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        self.tokenExpiry = nil
        _ = keychainHelper.deleteItem(for: "smartthings_combined_tokens")
        _ = keychainHelper.deleteItem(for: SmartThingsTokenManager.accessTokenKey)
        _ = keychainHelper.deleteItem(for: SmartThingsTokenManager.refreshTokenKey)
        _ = keychainHelper.deleteItem(for: SmartThingsTokenManager.tokenExpiryKey)
        print("Original clearTokens: Cleared SmartThings tokens from keychain.")
    }

    /// Saves the current token data to the keychain (internal helper)
    private func storeTokensInKeychain() {
        guard let currentAccessToken = self.accessToken,
              let currentRefreshToken = self.refreshToken,
              let currentExpiry = self.tokenExpiry else {
            print("Missing token components, cannot save to keychain.")
            return
        }
        let tokenData: [String: AnyCodable] = [
            "accessToken": AnyCodable(currentAccessToken),
            "refreshToken": AnyCodable(currentRefreshToken),
            "expiry": AnyCodable(currentExpiry)
        ]
        do {
            let data = try JSONEncoder().encode(tokenData)
            // Use saveData with the combined key
            if !keychainHelper.saveData(data, for: "smartthings_combined_tokens") {
                print("Failed to save combined tokens to keychain.")
            }
        } catch {
            print("Failed to encode tokens for keychain: \(error)")
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
enum SmartThingsAuthError: Error, LocalizedError {
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