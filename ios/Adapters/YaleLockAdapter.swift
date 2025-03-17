import Foundation
import Combine

// Configuration for Yale API
struct YaleConfiguration {
    static let apiKey = "YOUR_YALE_API_KEY" // Replace with actual API key
    static let baseURL = "https://api.yale.com/v1"
    static let clientId = "YOUR_YALE_CLIENT_ID" // Replace with actual client ID
    static let clientSecret = "YOUR_YALE_CLIENT_SECRET" // Replace with actual client secret
}

// Yale-specific adapter
class YaleLockAdapter: LockAdapter {
    private var authToken: String?
    private let baseURL = YaleConfiguration.baseURL
    private let networkService: NetworkServiceProtocol
    private let tokenManager: YaleTokenManager
    
    // Rate limiting properties
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 0.5 // 500ms between requests
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelayBase: TimeInterval = 2.0
    
    init(networkService: NetworkServiceProtocol, tokenManager: YaleTokenManager) {
        self.networkService = networkService
        self.tokenManager = tokenManager
    }
    
    func initialize(with authToken: String) throws {
        self.authToken = authToken
    }
    
    func fetchLocks() async throws -> [LockDevice] {
        return try await withRetry { [weak self] in
            guard let self = self else { throw LockOperationError.operationFailed("Adapter deallocated") }
            
            let token = try await self.getValidToken()
            
            // Define Yale-specific response type
            struct YaleLockResponse: Decodable {
                let deviceId: String
                let deviceName: String
                let deviceStatus: String
                let batteryLevel: Int
                let deviceMetadata: YaleLockMetadata
                
                struct YaleLockMetadata: Decodable {
                    let lastUpdated: String
                    let remoteOperationEnabled: Bool
                    let model: String
                    let firmwareVersion: String
                }
            }
            
            // Fetch from API
            let locks: [YaleLockResponse] = try await self.networkService.authenticatedGet(
                endpoint: "\(self.baseURL)/devices",
                token: token,
                headers: ["x-api-key": YaleConfiguration.apiKey]
            )
            
            // Convert to our model
            return locks.compactMap { lockData in
                // Only include locks, not other Yale devices
                guard lockData.deviceMetadata.model.contains("Lock") else { return nil }
                
                let dateFormatter = ISO8601DateFormatter()
                let lastChangeDate = dateFormatter.date(from: lockData.deviceMetadata.lastUpdated)
                
                // Map Yale states to our internal states
                let lockState: LockDevice.LockState
                switch lockData.deviceStatus.lowercased() {
                case "locked":
                    lockState = .locked
                case "unlocked":
                    lockState = .unlocked
                case "jammed":
                    lockState = .jammed
                default:
                    lockState = .unknown
                }
                
                return LockDevice(
                    id: lockData.deviceId,
                    name: lockData.deviceName,
                    room: "Unknown", // Yale API doesn't provide room information
                    manufacturer: "Yale",
                    model: lockData.deviceMetadata.model,
                    firmwareVersion: lockData.deviceMetadata.firmwareVersion,
                    isOnline: true, // Assuming it's online if we got data
                    lastSeen: Date(),
                    dateAdded: Date(),
                    metadata: ["propertyId": ""], // Will need to be populated from our database
                    currentState: lockState,
                    batteryLevel: lockData.batteryLevel,
                    lastStateChange: lastChangeDate,
                    isRemoteOperationEnabled: lockData.deviceMetadata.remoteOperationEnabled,
                    accessHistory: [] // Would need a separate API call to fetch this
                )
            }
        }
    }
    
    func getLockStatus(id: String) async throws -> LockDevice {
        return try await withRetry { [weak self] in
            guard let self = self else { throw LockOperationError.operationFailed("Adapter deallocated") }
            
            let token = try await self.getValidToken()
            
            // Define Yale-specific response type
            struct YaleLockDetailResponse: Decodable {
                let deviceId: String
                let deviceName: String
                let deviceStatus: String
                let batteryLevel: Int
                let deviceMetadata: YaleLockMetadata
                
                struct YaleLockMetadata: Decodable {
                    let lastUpdated: String
                    let remoteOperationEnabled: Bool
                    let model: String
                    let firmwareVersion: String
                }
            }
            
            // Fetch lock details from API
            let lockDetail: YaleLockDetailResponse = try await self.networkService.authenticatedGet(
                endpoint: "\(self.baseURL)/devices/\(id)",
                token: token,
                headers: ["x-api-key": YaleConfiguration.apiKey]
            )
            
            // Fetch access history in a separate call
            struct YaleHistoryEntry: Decodable {
                let timestamp: String
                let action: String
                let userId: String
                let success: Bool
                let errorMessage: String?
            }
            
            let historyEntries: [YaleHistoryEntry] = try await self.networkService.authenticatedGet(
                endpoint: "\(self.baseURL)/devices/\(id)/history",
                token: token,
                headers: ["x-api-key": YaleConfiguration.apiKey]
            )
            
            // Convert to our model
            let dateFormatter = ISO8601DateFormatter()
            let lastChangeDate = dateFormatter.date(from: lockDetail.deviceMetadata.lastUpdated)
            
            // Map Yale states to our internal states
            let lockState: LockDevice.LockState
            switch lockDetail.deviceStatus.lowercased() {
            case "locked":
                lockState = .locked
            case "unlocked":
                lockState = .unlocked
            case "jammed":
                lockState = .jammed
            default:
                lockState = .unknown
            }
            
            // Convert history entries
            let accessHistory = historyEntries.compactMap { entry in
                guard let timestamp = dateFormatter.date(from: entry.timestamp) else { return nil }
                
                let operation: LockDevice.LockOperation
                switch entry.action.lowercased() {
                case "lock":
                    operation = .lock
                case "unlock":
                    operation = .unlock
                case "auto_lock":
                    operation = .autoLock
                case "auto_unlock":
                    operation = .autoUnlock
                default:
                    return nil // Skip unknown operations
                }
                
                return LockDevice.LockAccessRecord(
                    timestamp: timestamp,
                    operation: operation,
                    userId: entry.userId,
                    success: entry.success,
                    failureReason: entry.errorMessage
                )
            }
            
            return LockDevice(
                id: lockDetail.deviceId,
                name: lockDetail.deviceName,
                room: "Unknown", // Yale API doesn't provide room information
                manufacturer: "Yale",
                model: lockDetail.deviceMetadata.model,
                firmwareVersion: lockDetail.deviceMetadata.firmwareVersion,
                isOnline: true,
                lastSeen: Date(),
                dateAdded: Date(),
                metadata: ["propertyId": ""], // Will need to be populated from our database
                currentState: lockState,
                batteryLevel: lockDetail.batteryLevel,
                lastStateChange: lastChangeDate,
                isRemoteOperationEnabled: lockDetail.deviceMetadata.remoteOperationEnabled,
                accessHistory: accessHistory
            )
        }
    }
    
    func controlLock(id: String, command: LockCommand) async throws -> LockDevice.LockState {
        return try await withRetry { [weak self] in
            guard let self = self else { throw LockOperationError.operationFailed("Adapter deallocated") }
            
            let token = try await self.getValidToken()
            
            // Create request body
            let commandString = command == .lock ? "lock" : "unlock"
            let requestBody = ["action": commandString]
            
            // Define response type
            struct YaleCommandResponse: Decodable {
                let status: String
                let message: String
                let timestamp: String
            }
            
            // Send command to API
            let response: YaleCommandResponse = try await self.networkService.authenticatedPost(
                endpoint: "\(self.baseURL)/devices/\(id)/actions",
                token: token,
                body: requestBody,
                headers: ["x-api-key": YaleConfiguration.apiKey]
            )
            
            // Check for success
            guard response.status.lowercased() == "success" else {
                throw LockOperationError.operationFailed("Operation failed: \(response.message)")
            }
            
            // Map response status to our lock state
            let lockState: LockDevice.LockState = command == .lock ? .locked : .unlocked
            
            return lockState
        }
    }
    
    // MARK: - Helper Methods
    
    private func getValidToken() async throws -> String {
        if let token = self.authToken {
            return token
        }
        
        // If no token, try to get one from the token manager
        let token = try await tokenManager.getToken()
        self.authToken = token
        return token
    }
    
    private func withRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                // Rate limiting check
                if let lastRequest = lastRequestTime, 
                   Date().timeIntervalSince(lastRequest) < minRequestInterval {
                    let waitTime = minRequestInterval - Date().timeIntervalSince(lastRequest)
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
                
                lastRequestTime = Date()
                return try await operation()
            } catch let error as LockOperationError {
                lastError = error
                
                // Don't retry certain errors
                switch error {
                case .notAuthenticated, .permissionDenied:
                    throw error
                default:
                    break
                }
                
                // Exponential backoff
                if attempt < maxRetries {
                    let delay = retryDelayBase * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                lastError = error
                
                // Exponential backoff for other errors
                if attempt < maxRetries {
                    let delay = retryDelayBase * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? LockOperationError.operationFailed("Unknown error after \(maxRetries) retries")
    }
}

// Yale Token Manager
class YaleTokenManager {
    private let networkService: NetworkServiceProtocol
    private let keychainHelper: KeychainHelper
    private var currentToken: String?
    private var tokenExpiration: Date?
    
    private let clientId = YaleConfiguration.clientId
    private let clientSecret = YaleConfiguration.clientSecret
    private let baseURL = YaleConfiguration.baseURL
    
    init(networkService: NetworkServiceProtocol, keychainHelper: KeychainHelper) {
        self.networkService = networkService
        self.keychainHelper = keychainHelper
    }
    
    func getToken() async throws -> String {
        // Check if we have a valid token
        if let token = currentToken, let expiration = tokenExpiration, expiration > Date() {
            return token
        }
        
        // Try to get token from keychain
        if let savedToken = try? keychainHelper.get(service: "com.unifiedsmarthome.yale", account: "authToken"),
           let expirationData = try? keychainHelper.get(service: "com.unifiedsmarthome.yale", account: "tokenExpiration"),
           let expirationDate = Date(timeIntervalSince1970: Double(String(data: expirationData, encoding: .utf8) ?? "0") ?? 0),
           expirationDate > Date() {
            
            currentToken = String(data: savedToken, encoding: .utf8)
            tokenExpiration = expirationDate
            return currentToken!
        }
        
        // Need to get a new token
        return try await refreshToken()
    }
    
    func refreshToken() async throws -> String {
        // Get user credentials
        guard let username = try? keychainHelper.get(service: "com.unifiedsmarthome.yale", account: "username"),
              let password = try? keychainHelper.get(service: "com.unifiedsmarthome.yale", account: "password") else {
            throw AuthenticationError.credentialsNotFound
        }
        
        let usernameString = String(data: username, encoding: .utf8)!
        let passwordString = String(data: password, encoding: .utf8)!
        
        // Prepare request body
        let requestBody: [String: String] = [
            "grant_type": "password",
            "client_id": clientId,
            "client_secret": clientSecret,
            "username": usernameString,
            "password": passwordString
        ]
        
        // Define response type
        struct TokenResponse: Decodable {
            let access_token: String
            let token_type: String
            let expires_in: Int
        }
        
        // Make token request
        let tokenResponse: TokenResponse = try await networkService.post(
            endpoint: "\(baseURL)/oauth/token",
            body: requestBody,
            headers: ["Content-Type": "application/json"]
        )
        
        // Save the token
        currentToken = tokenResponse.access_token
        tokenExpiration = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        
        // Save to keychain
        try keychainHelper.save(tokenResponse.access_token.data(using: .utf8)!,
                               service: "com.unifiedsmarthome.yale",
                               account: "authToken")
        
        let expirationString = String(tokenExpiration!.timeIntervalSince1970)
        try keychainHelper.save(expirationString.data(using: .utf8)!,
                               service: "com.unifiedsmarthome.yale",
                               account: "tokenExpiration")
        
        return tokenResponse.access_token
    }
    
    func saveCredentials(username: String, password: String) throws {
        try keychainHelper.save(username.data(using: .utf8)!,
                               service: "com.unifiedsmarthome.yale",
                               account: "username")
        
        try keychainHelper.save(password.data(using: .utf8)!,
                               service: "com.unifiedsmarthome.yale",
                               account: "password")
    }
    
    func clearCredentials() throws {
        try keychainHelper.delete(service: "com.unifiedsmarthome.yale", account: "username")
        try keychainHelper.delete(service: "com.unifiedsmarthome.yale", account: "password")
        try keychainHelper.delete(service: "com.unifiedsmarthome.yale", account: "authToken")
        try keychainHelper.delete(service: "com.unifiedsmarthome.yale", account: "tokenExpiration")
        
        currentToken = nil
        tokenExpiration = nil
    }
}

// Authentication error types
enum AuthenticationError: Error, LocalizedError {
    case credentialsNotFound
    case invalidCredentials
    case tokenExpired
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            return "No Yale credentials found"
        case .invalidCredentials:
            return "Invalid Yale credentials"
        case .tokenExpired:
            return "Yale authentication token expired"
        case .networkError:
            return "Network error during Yale authentication"
        }
    }
} 