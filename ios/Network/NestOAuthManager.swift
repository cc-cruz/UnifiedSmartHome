import Foundation
import SwiftUI
import AuthenticationServices

class NestOAuthManager: NSObject, ObservableObject {
    // Authentication state
    @Published var isAuthenticated = false
    @Published var error: String?
    
    // Configuration for the Nest API
    private let configuration: NestConfiguration
    
    // WebAuth session
    private var webAuthSession: ASWebAuthenticationSession?
    
    // Keys for Keychain storage
    private enum KeychainKeys {
        static let accessToken = "nest_access_token"
        static let refreshToken = "nest_refresh_token"
        static let tokenExpiry = "nest_token_expiry"
    }
    
    init(configuration: NestConfiguration = NestConfiguration()) {
        self.configuration = configuration
        super.init()
        
        // Check if we have a valid token on initialization
        if let expiryString = KeychainHelper.shared.get(for: KeychainKeys.tokenExpiry),
           let expiry = Double(expiryString),
           expiry > Date().timeIntervalSince1970,
           KeychainHelper.shared.get(for: KeychainKeys.accessToken) != nil {
            isAuthenticated = true
        }
    }
    
    func startOAuthFlow() {
        // Clear any existing errors
        error = nil
        
        // Construct the authorization URL
        guard let authURL = configuration.buildAuthorizationURL() else {
            error = "Failed to create authorization URL"
            return
        }
        
        // Start the web authentication session
        webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "unifiedsmarthome"
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.error = "Authentication failed: \(error.localizedDescription)"
                }
                return
            }
            
            guard let callbackURL = callbackURL,
                  let code = self.extractAuthorizationCode(from: callbackURL) else {
                DispatchQueue.main.async {
                    self.error = "Failed to extract authorization code"
                }
                return
            }
            
            self.exchangeCodeForToken(code: code)
        }
        
        webAuthSession?.presentationContextProvider = self
        webAuthSession?.prefersEphemeralWebBrowserSession = true
        webAuthSession?.start()
    }
    
    private func extractAuthorizationCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            return nil
        }
        
        return queryItems.first(where: { $0.name == "code" })?.value
    }
    
    private func exchangeCodeForToken(code: String) {
        guard let tokenURL = configuration.buildTokenURL() else {
            DispatchQueue.main.async {
                self.error = "Failed to create token URL"
            }
            return
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": configuration.clientID,
            "client_secret": configuration.clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": configuration.redirectURI
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.error = "Token exchange failed: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.error = "No data received from token exchange"
                }
                return
            }
            
            self.handleTokenResponse(data: data)
        }
        
        task.resume()
    }
    
    func refreshAccessToken() {
        guard let refreshToken = KeychainHelper.shared.get(for: KeychainKeys.refreshToken) else {
            DispatchQueue.main.async {
                self.error = "No refresh token available"
                self.isAuthenticated = false
            }
            return
        }
        
        guard let tokenURL = configuration.buildTokenURL() else {
            DispatchQueue.main.async {
                self.error = "Failed to create token URL"
            }
            return
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": configuration.clientID,
            "client_secret": configuration.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.error = "Token refresh failed: \(error.localizedDescription)"
                    self.isAuthenticated = false
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.error = "No data received from token refresh"
                    self.isAuthenticated = false
                }
                return
            }
            
            self.handleTokenResponse(data: data, isRefresh: true)
        }
        
        task.resume()
    }
    
    private func handleTokenResponse(data: Data, isRefresh: Bool = false) {
        do {
            // Parse the token response
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            
            // Calculate token expiry (current time + expires_in seconds - 5 min buffer)
            let expiryDate = Date().timeIntervalSince1970 + Double(tokenResponse.expiresIn) - 300
            
            // Store tokens in the keychain
            KeychainHelper.shared.save(tokenResponse.accessToken, for: KeychainKeys.accessToken)
            KeychainHelper.shared.save(String(expiryDate), for: KeychainKeys.tokenExpiry)
            
            // Save refresh token if this is not a refresh and one was provided
            if !isRefresh, let refreshToken = tokenResponse.refreshToken {
                KeychainHelper.shared.save(refreshToken, for: KeychainKeys.refreshToken)
            }
            
            // Update authentication state
            DispatchQueue.main.async {
                self.isAuthenticated = true
                self.error = nil
            }
        } catch {
            // Log the parsing error and the raw data for debugging
            #if DEBUG
            print("Token response parsing error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw response: \(jsonString)")
            }
            #endif
            
            DispatchQueue.main.async {
                self.error = "Failed to parse token response: \(error.localizedDescription)"
                self.isAuthenticated = false
            }
        }
    }
    
    func getAccessToken() -> String? {
        // Check if the token is expired
        if let expiryString = KeychainHelper.shared.get(for: KeychainKeys.tokenExpiry),
           let expiry = Double(expiryString),
           expiry <= Date().timeIntervalSince1970 {
            // Token is expired, attempt to refresh
            refreshAccessToken()
            return nil
        }
        
        return KeychainHelper.shared.get(for: KeychainKeys.accessToken)
    }
    
    func signOut() {
        // Remove tokens from keychain
        KeychainHelper.shared.delete(for: KeychainKeys.accessToken)
        KeychainHelper.shared.delete(for: KeychainKeys.refreshToken)
        KeychainHelper.shared.delete(for: KeychainKeys.tokenExpiry)
        
        // Update authentication state
        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension NestOAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first ?? UIWindow()
        return window
    }
}

// MARK: - Token Response Model
private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
} 