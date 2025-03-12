import Foundation
import Combine
import AuthenticationServices

// Nest configuration struct to store settings
struct NestConfiguration {
    let clientID: String
    let clientSecret: String
    let redirectURI: String
    let projectID: String
    
    // Load from configuration source
    static func loadFromConfiguration() -> NestConfiguration {
        // For development, we'll read from Info.plist
        // In production, these could come from an encrypted config or secure backend
        guard let infoDictionary = Bundle.main.infoDictionary else {
            fatalError("Cannot load Info.plist")
        }
        
        // Read values with fallbacks for development
        let clientID = (infoDictionary["NEST_CLIENT_ID"] as? String) ?? ""
        let clientSecret = (infoDictionary["NEST_CLIENT_SECRET"] as? String) ?? ""
        let projectID = (infoDictionary["NEST_PROJECT_ID"] as? String) ?? ""
        
        // Use a hard-coded redirect URI since this needs to match app configuration
        let redirectURI = "com.unifiedsmarthome:/oauth2callback"
        
        // Validate required credentials in debug mode
        #if DEBUG
        if clientID.isEmpty || clientSecret.isEmpty || projectID.isEmpty {
            print("⚠️ WARNING: Missing Nest API credentials in Info.plist. The app will not be able to connect to Nest.")
            print("Add NEST_CLIENT_ID, NEST_CLIENT_SECRET, and NEST_PROJECT_ID to Info.plist")
        }
        #endif
        
        return NestConfiguration(
            clientID: clientID,
            clientSecret: clientSecret,
            redirectURI: redirectURI,
            projectID: projectID
        )
    }
}

class NestOAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    // Published properties to track authentication state
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var error: String?
    
    // OAuth configuration
    private let configuration: NestConfiguration
    private let authorizationEndpoint = "https://accounts.google.com/o/oauth2/auth"
    private let tokenEndpoint = "https://accounts.google.com/o/oauth2/token"
    private let scope = "https://www.googleapis.com/auth/sdm.service"
    
    // Token storage keys
    private let accessTokenKey = "nest_access_token"
    private let refreshTokenKey = "nest_refresh_token"
    private let tokenExpiryKey = "nest_token_expiry"
    
    private var cancellables = Set<AnyCancellable>()
    
    // Current tokens
    private var accessToken: String? {
        get { KeychainHelper.standard.read(service: "NestService", account: accessTokenKey, type: String.self) }
        set { 
            if let newValue = newValue {
                KeychainHelper.standard.save(newValue, service: "NestService", account: accessTokenKey) 
            } else {
                KeychainHelper.standard.delete(service: "NestService", account: accessTokenKey)
            }
        }
    }
    
    private var refreshToken: String? {
        get { KeychainHelper.standard.read(service: "NestService", account: refreshTokenKey, type: String.self) }
        set { 
            if let newValue = newValue {
                KeychainHelper.standard.save(newValue, service: "NestService", account: refreshTokenKey) 
            } else {
                KeychainHelper.standard.delete(service: "NestService", account: refreshTokenKey)
            }
        }
    }
    
    private var tokenExpiry: Date? {
        get { KeychainHelper.standard.read(service: "NestService", account: tokenExpiryKey, type: Date.self) }
        set { 
            if let newValue = newValue {
                KeychainHelper.standard.save(newValue, service: "NestService", account: tokenExpiryKey) 
            } else {
                KeychainHelper.standard.delete(service: "NestService", account: tokenExpiryKey)
            }
        }
    }
    
    init(configuration: NestConfiguration = NestConfiguration.loadFromConfiguration()) {
        self.configuration = configuration
        super.init()
        checkAuthentication()
    }
    
    // Check if user is authenticated based on token validity
    private func checkAuthentication() {
        if let expiry = tokenExpiry, let _ = accessToken, let _ = refreshToken {
            if expiry > Date() {
                self.isAuthenticated = true
            } else {
                refreshAccessToken()
            }
        } else {
            self.isAuthenticated = false
        }
    }
    
    // Start OAuth flow
    func startOAuthFlow() {
        // Verify we have a client ID before starting
        guard !configuration.clientID.isEmpty else {
            self.error = "Missing Nest API credentials. Please configure the app with valid credentials."
            return
        }
        
        isAuthenticating = true
        error = nil
        
        let state = UUID().uuidString
        
        var components = URLComponents(string: authorizationEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        guard let authURL = components?.url else {
            self.error = "Failed to create authorization URL"
            isAuthenticating = false
            return
        }
        
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "com.unifiedsmarthome",
            completionHandler: { [weak self] callbackURL, error in
                guard let self = self else { return }
                
                self.isAuthenticating = false
                
                if let error = error {
                    self.error = "Authentication failed: \(error.localizedDescription)"
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    self.error = "No callback URL returned"
                    return
                }
                
                // Parse the authorization code from the callback URL
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let queryItems = components.queryItems,
                      let code = queryItems.first(where: { $0.name == "code" })?.value,
                      let returnedState = queryItems.first(where: { $0.name == "state" })?.value,
                      returnedState == state else {
                    self.error = "Invalid callback URL or state"
                    return
                }
                
                // Exchange the authorization code for access and refresh tokens
                self.exchangeCodeForToken(code: code)
            }
        )
        
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        
        if !session.start() {
            self.error = "Failed to start authentication session"
            isAuthenticating = false
        }
    }
    
    // Exchange authorization code for tokens
    private func exchangeCodeForToken(code: String) {
        let parameters = [
            "client_id": configuration.clientID,
            "client_secret": configuration.clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": configuration.redirectURI
        ]
        
        guard let url = URL(string: tokenEndpoint) else {
            self.error = "Invalid token endpoint URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: TokenResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = "Failed to exchange code for token: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                self.saveTokens(
                    accessToken: response.access_token,
                    refreshToken: response.refresh_token,
                    expiresIn: response.expires_in
                )
                
                self.isAuthenticated = true
            }
            .store(in: &cancellables)
    }
    
    // Refresh access token using refresh token
    func refreshAccessToken() {
        guard let refreshToken = self.refreshToken else {
            self.error = "No refresh token available"
            self.isAuthenticated = false
            return
        }
        
        let parameters = [
            "client_id": configuration.clientID,
            "client_secret": configuration.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        guard let url = URL(string: tokenEndpoint) else {
            self.error = "Invalid token endpoint URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: RefreshTokenResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = "Failed to refresh token: \(error.localizedDescription)"
                    self?.isAuthenticated = false
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                self.saveTokens(
                    accessToken: response.access_token,
                    refreshToken: self.refreshToken, // Keep the existing refresh token
                    expiresIn: response.expires_in
                )
                
                self.isAuthenticated = true
            }
            .store(in: &cancellables)
    }
    
    // Save tokens to keychain
    private func saveTokens(accessToken: String, refreshToken: String?, expiresIn: Int) {
        self.accessToken = accessToken
        
        if let refreshToken = refreshToken {
            self.refreshToken = refreshToken
        }
        
        let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        self.tokenExpiry = expiryDate
    }
    
    // Sign out and clear tokens
    func signOut() {
        self.accessToken = nil
        self.refreshToken = nil
        self.tokenExpiry = nil
        self.isAuthenticated = false
    }
    
    // Get current access token for API calls
    func getAccessToken() -> String? {
        if let expiry = tokenExpiry, let token = accessToken {
            // If token expires in less than 5 minutes, proactively refresh it
            if expiry.timeIntervalSinceNow < 300 {
                refreshAccessToken()
                // Return current token for now, the refresh will happen in background
                return token
            } else if expiry > Date() {
                return token
            } else {
                refreshAccessToken()
                return nil // Will need to wait for refresh to complete
            }
        }
        return nil
    }
    
    // Get project ID for device API access
    func getProjectID() -> String {
        return configuration.projectID
    }
    
    // ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// Response models for token endpoints
struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let token_type: String
}

struct RefreshTokenResponse: Decodable {
    let access_token: String
    let expires_in: Int
    let token_type: String
} 