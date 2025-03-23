import Foundation

/// Class for managing authentication tokens for August Lock API
class AugustTokenManager {
    private let keychain: KeychainWrapper
    private let tokenEndpoint = URL(string: "https://api.august.com/session")!
    
    // Token storage keys
    private let accessTokenKey = "com.unifiedsmarthome.august.accessToken"
    private let refreshTokenKey = "com.unifiedsmarthome.august.refreshToken"
    private let expiryDateKey = "com.unifiedsmarthome.august.expiryDate"
    
    init(keychain: KeychainWrapper = KeychainWrapper.standard) {
        self.keychain = keychain
    }
    
    /// Authenticate with username and password
    /// - Parameters:
    ///   - username: August account username (email)
    ///   - password: August account password
    /// - Returns: Access token
    func authenticate(username: String, password: String) async throws -> String {
        // Build request body for August API
        let requestBody: [String: Any] = [
            "identifier": username,
            "password": password,
            "installId": UUID().uuidString
        ]
        
        // Convert body to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw TokenError.invalidRequestData
        }
        
        // Create request
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200:
            // Parse response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["accessToken"] as? String,
                  let refreshToken = json["refreshToken"] as? String,
                  let expiresIn = json["expiresIn"] as? TimeInterval else {
                throw TokenError.invalidResponseFormat
            }
            
            // Calculate expiry date
            let expiryDate = Date().addingTimeInterval(expiresIn)
            
            // Store tokens
            saveTokens(accessToken: accessToken, refreshToken: refreshToken, expiryDate: expiryDate)
            
            return accessToken
            
        case 401:
            throw TokenError.invalidCredentials
        default:
            throw TokenError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Refresh access token using the stored refresh token
    /// - Returns: New access token
    func refreshToken() async throws -> String {
        guard let refreshToken = getRefreshToken() else {
            throw TokenError.noRefreshToken
        }
        
        // Build request body
        let requestBody: [String: Any] = [
            "refreshToken": refreshToken
        ]
        
        // Convert body to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw TokenError.invalidRequestData
        }
        
        // Create request
        var request = URLRequest(url: tokenEndpoint.appendingPathComponent("refresh"))
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200:
            // Parse response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["accessToken"] as? String,
                  let newRefreshToken = json["refreshToken"] as? String,
                  let expiresIn = json["expiresIn"] as? TimeInterval else {
                throw TokenError.invalidResponseFormat
            }
            
            // Calculate expiry date
            let expiryDate = Date().addingTimeInterval(expiresIn)
            
            // Store tokens
            saveTokens(accessToken: accessToken, refreshToken: newRefreshToken, expiryDate: expiryDate)
            
            return accessToken
            
        case 401:
            // Clear invalid tokens
            clearTokens()
            throw TokenError.invalidRefreshToken
        default:
            throw TokenError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Get the stored access token if valid
    /// - Returns: Access token if available and valid
    func getAccessToken() -> String? {
        // Check if we have a token
        guard let token = keychain.string(forKey: accessTokenKey),
              let expiryDateString = keychain.string(forKey: expiryDateKey),
              let expiryDate = ISO8601DateFormatter().date(from: expiryDateString) else {
            return nil
        }
        
        // Check if token is still valid (with 5 minute buffer)
        if expiryDate.timeIntervalSinceNow > 300 {
            return token
        }
        
        return nil
    }
    
    /// Get the stored refresh token
    /// - Returns: Refresh token if available
    func getRefreshToken() -> String? {
        return keychain.string(forKey: refreshTokenKey)
    }
    
    /// Check if token needs refresh and refresh if necessary
    /// - Returns: Valid access token
    func ensureValidToken() async throws -> String {
        // Check if we have a valid token
        if let token = getAccessToken() {
            return token
        }
        
        // Try to refresh
        return try await refreshToken()
    }
    
    /// Clear all stored tokens
    func clearTokens() {
        keychain.removeObject(forKey: accessTokenKey)
        keychain.removeObject(forKey: refreshTokenKey)
        keychain.removeObject(forKey: expiryDateKey)
    }
    
    /// Save tokens to secure storage
    /// - Parameters:
    ///   - accessToken: The access token
    ///   - refreshToken: The refresh token
    ///   - expiryDate: When the access token expires
    private func saveTokens(accessToken: String, refreshToken: String, expiryDate: Date) {
        keychain.set(accessToken, forKey: accessTokenKey)
        keychain.set(refreshToken, forKey: refreshTokenKey)
        keychain.set(ISO8601DateFormatter().string(from: expiryDate), forKey: expiryDateKey)
    }
    
    /// Errors related to token operations
    enum TokenError: Error {
        case invalidCredentials
        case invalidRefreshToken
        case noRefreshToken
        case networkError
        case invalidRequestData
        case invalidResponseFormat
        case serverError(statusCode: Int)
    }
}

/// Simple wrapper for keychain operations
class KeychainWrapper {
    static let standard = KeychainWrapper()
    
    func string(forKey key: String) -> String? {
        // In a real implementation, this would access the keychain
        // For this example, we'll use UserDefaults as a placeholder
        return UserDefaults.standard.string(forKey: key)
    }
    
    func set(_ value: String, forKey key: String) {
        // In a real implementation, this would store in the keychain
        // For this example, we'll use UserDefaults as a placeholder
        UserDefaults.standard.set(value, forKey: key)
    }
    
    func removeObject(forKey key: String) {
        // In a real implementation, this would remove from the keychain
        // For this example, we'll use UserDefaults as a placeholder
        UserDefaults.standard.removeObject(forKey: key)
    }
} 