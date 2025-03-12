import Foundation

/// Manages Nest API configuration retrieved from Info.plist
struct NestConfiguration {
    // Required configuration values
    let clientID: String
    let clientSecret: String
    let redirectURI: String
    let projectID: String
    
    // Base URLs for the Nest API
    static let authBaseURL = "https://accounts.google.com/o/oauth2"
    static let apiBaseURL = "https://smartdevicemanagement.googleapis.com/v1"
    
    // Scopes required for the Nest API
    static let requiredScopes = [
        "https://www.googleapis.com/auth/sdm.service",
        "https://www.googleapis.com/auth/sdm.thermostat.control"
    ]
    
    // Default initializer loads from Info.plist
    init() {
        // Retrieve values from Info.plist
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "NestClientID") as? String,
              let clientSecret = Bundle.main.object(forInfoDictionaryKey: "NestClientSecret") as? String,
              let redirectURI = Bundle.main.object(forInfoDictionaryKey: "NestRedirectURI") as? String,
              let projectID = Bundle.main.object(forInfoDictionaryKey: "NestProjectID") as? String else {
            
            // Log warning for missing configuration in debug mode
            #if DEBUG
            print("⚠️ WARNING: Missing Nest API configuration in Info.plist")
            print("Please add NestClientID, NestClientSecret, NestRedirectURI, and NestProjectID to Info.plist")
            #endif
            
            // Use empty placeholder values that will trigger appropriate errors when used
            self.clientID = "[YOUR_NEST_CLIENT_ID]"
            self.clientSecret = "[YOUR_NEST_CLIENT_SECRET]"
            self.redirectURI = "unifiedsmarthome://oauth-callback"
            self.projectID = "[YOUR_NEST_PROJECT_ID]"
            return
        }
        
        // Validate that values have been replaced in the Info.plist
        if clientID.contains("[YOUR_") || clientSecret.contains("[YOUR_") || projectID.contains("[YOUR_") {
            #if DEBUG
            print("⚠️ WARNING: Default placeholder values found in Nest API configuration")
            print("Please replace the placeholder values in Info.plist with your actual Nest API credentials")
            #endif
        }
        
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.projectID = projectID
    }
    
    // Optional initializer with explicit values (useful for testing)
    init(clientID: String, clientSecret: String, redirectURI: String, projectID: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.projectID = projectID
    }
    
    // Build the authorization URL for the OAuth2 flow
    func buildAuthorizationURL() -> URL? {
        let queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: NestConfiguration.requiredScopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline")
        ]
        
        var components = URLComponents(string: "\(NestConfiguration.authBaseURL)/auth")
        components?.queryItems = queryItems
        
        return components?.url
    }
    
    // Build the token exchange URL
    func buildTokenURL() -> URL? {
        return URL(string: "\(NestConfiguration.authBaseURL)/token")
    }
    
    // Build a URL for a specific device
    func buildDeviceURL(deviceID: String) -> URL? {
        return URL(string: "\(NestConfiguration.apiBaseURL)/enterprises/\(projectID)/devices/\(deviceID)")
    }
    
    // Build the URL for listing all devices
    func buildListDevicesURL() -> URL? {
        return URL(string: "\(NestConfiguration.apiBaseURL)/enterprises/\(projectID)/devices")
    }
} 