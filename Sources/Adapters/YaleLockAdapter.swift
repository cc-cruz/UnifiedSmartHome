import Foundation
import Combine
import Models
import Services
import Helpers

// Configuration for Yale API
struct YaleConfiguration {
    static let shared = YaleConfiguration()
    
    let apiKey: String
    let baseURL: String
    let clientId: String
    let clientSecret: String
    
    private init() {
        // Load from environment variables or secure configuration
        self.apiKey = ProcessInfo.processInfo.environment["YALE_API_KEY"] ?? ""
        self.baseURL = ProcessInfo.processInfo.environment["YALE_BASE_URL"] ?? "https://api.yalehome.com/v1"
        self.clientId = ProcessInfo.processInfo.environment["YALE_CLIENT_ID"] ?? ""
        self.clientSecret = ProcessInfo.processInfo.environment["YALE_CLIENT_SECRET"] ?? ""
        
        // Validate configuration
        guard !apiKey.isEmpty, !clientId.isEmpty, !clientSecret.isEmpty else {
            fatalError("Yale configuration is incomplete. Please set all required environment variables.")
        }
    }
}

// Define Yale specific types if they don't exist elsewhere
struct YaleCredentials: Codable {
    let apiKey: String
    // Add other needed fields like username, password, etc.
}

// Assuming LockError might be generic or we need a Yale specific one
enum YaleLockError: Error {
    case authenticationFailed
    case commandFailed
    case deviceNotFound
    // Add other specific errors
}

// Define request body struct for controlLock
struct YaleControlLockBody: Encodable {
    let command: String // e.g., "lock" or "unlock"
}

// Yale-specific adapter
class YaleLockAdapter: LockAdapter {
    private var authToken: String?
    private let baseURL = YaleConfiguration.shared.baseURL
    private let networkService: NetworkServiceProtocol
    private let tokenManager: YaleTokenManager
    private let securityService: OperationalSecurityProtocol
    private let auditLogger: AuditLoggerProtocol
    private var credentials: YaleCredentials?
    private let keychainHelper = Helpers.KeychainHelper() // Use instance
    
    // Rate limiting properties
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 0.5 // 500ms between requests
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelayBase: TimeInterval = 2.0
    
    // Certificate pinning configuration
    private let pinnedCertificates: Set<Data> = {
        // Load pinned certificates from the app bundle
        let bundle = Bundle.main
        let certificateNames = ["yale-home-cert-1", "yale-home-cert-2"]
        return Set(certificateNames.compactMap { name in
            guard let path = bundle.path(forResource: name, ofType: "cer"),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                return nil
            }
            return data
        })
    }()
    
    init(networkService: NetworkServiceProtocol,
         securityService: OperationalSecurityProtocol,
         auditLogger: AuditLoggerProtocol) {
        self.networkService = networkService
        self.tokenManager = YaleTokenManager(networkService: networkService, keychainHelper: self.keychainHelper)
        self.securityService = securityService
        self.auditLogger = auditLogger
        loadCredentials()
    }
    
    private func loadCredentials() {
        // Use getData and decode YaleCredentials
        guard let data = keychainHelper.getData(for: "yale_credentials") else { return }
        self.credentials = try? JSONDecoder().decode(YaleCredentials.self, from: data)
    }
    
    func saveCredentials(_ creds: YaleCredentials) {
        // Encode and use saveData
        do {
            let data = try JSONEncoder().encode(creds)
            _ = keychainHelper.saveData(data, for: "yale_credentials")
            self.credentials = creds
        } catch {
            print("Error saving Yale credentials: \(error)")
        }
    }
    
    func initialize(with authToken: String) throws {
        self.authToken = authToken
    }
    
    func fetchLocks() async throws -> [LockDevice] {
        let _ = try await tokenManager.getToken()
        auditLogger.logEvent(type: .deviceOperation, action: "fetch_locks", status: .started, details: ["adapter": "yale"])
        
        guard let url = URL(string: "\(self.baseURL)/devices") else { 
            auditLogger.logEvent(type: .systemEvent, action: "url_construction", status: .failed, details: ["context": "fetchLocks"])
            throw LockOperationError.operationFailed("Invalid URL for fetchLocks")
        }
        
        do {
            let response: YaleLocksResponse = try await networkService.authenticatedGet(
                url: url,
                headers: ["x-api-key": YaleConfiguration.shared.apiKey]
            )
            auditLogger.logEvent(type: .deviceOperation, action: "fetch_locks", status: .success, details: ["adapter": "yale", "count": response.locks.count])
            return response.locks.compactMap { mapYaleLockToDevice($0) } // Ensure mapping
        } catch {
             auditLogger.logEvent(type: .deviceOperation, action: "fetch_locks", status: .failed, details: ["adapter": "yale", "error": sanitizeError(error)])
             throw handleNetworkError(error)
        }
    }
    
    // Conforms to LockAdapter protocol
    func getLockStatus(id: String) async throws -> LockDevice { // Renamed parameter, changed return type
        let token = try await tokenManager.getToken()
        let lockStatusEndpoint = "\(tokenManager.baseURL)/locks/\(id)/status" // Use id
        
        guard let url = URL(string: lockStatusEndpoint) else {
            auditLogger.logEvent(type: .systemEvent, action: "url_construction", status: .failed, details: ["url": lockStatusEndpoint])
            throw LockOperationError.operationFailed("Invalid URL for getLockStatus")
        }
        
        let headers = ["Authorization": "Bearer \(token)"]
        
        do {
            // Fetch the specific Yale status response
            let statusResponse: YaleLockStatusResponse = try await networkService.authenticatedGet(url: url, headers: headers)
            auditLogger.logEvent(type: .deviceOperation, action: "statusCheck", status: .success, details: ["lockId": id, "status": "Fetched"])
            
            // Map the Yale response to the required LockDevice model
            // This mapping might need more details than YaleLockStatusResponse provides alone.
            // For now, create a basic LockDevice based on the response.
            let lockState: LockDevice.LockState
            switch statusResponse.lockState.lowercased() {
                case "locked": lockState = .locked
                case "unlocked": lockState = .unlocked
                case "jammed": lockState = .jammed
                default: lockState = .unknown
            }
            
            // We only have partial info here. Fetch full device info if needed, 
            // or return a partially populated LockDevice.
            // Using placeholders for missing info.
            return LockDevice(
                id: id,
                name: "Yale Lock (Status)", // Placeholder name
                room: "Unknown",
                manufacturer: "Yale",
                model: "Unknown", // Placeholder model
                firmwareVersion: "N/A",
                isOnline: true, // Assume online if status fetched
                currentState: lockState,
                batteryLevel: statusResponse.batteryLevel ?? 50, // Use optional battery level
                lastStateChange: nil, // Not available in status response
                isRemoteOperationEnabled: true // Assume true
            )
            
        } catch {
            auditLogger.logEvent(type: .deviceOperation, action: "statusCheck", status: .failed, details: ["lockId": id, "error": sanitizeError(error)])
            throw handleNetworkError(error)
        }
    }

    // Conforms to LockAdapter protocol
    func controlLock(id: String, command genericCommand: LockCommand) async throws -> LockDevice.LockState { // Renamed method, changed command type, changed return type
        let token = try await tokenManager.getToken()
        let commandEndpoint = "\(tokenManager.baseURL)/locks/\(id)/operate"

        // Map generic LockCommand to Yale-specific command string
        let yaleCommandString: String
        switch genericCommand {
            case .lock: yaleCommandString = "lock"
            case .unlock: yaleCommandString = "unlock"
        }

        let payload = YaleControlLockBody(command: yaleCommandString) // Use specific Encodable struct

        guard let url = URL(string: commandEndpoint) else {
            auditLogger.logEvent(type: .systemEvent, action: "url_construction", status: .failed, details: ["lockId": id, "command": yaleCommandString, "error": "Invalid URL"])
            throw LockOperationError.operationFailed("Invalid URL for controlLock")
        }

        let headers = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]

        do {
            // Execute command
            let response: YaleLockCommandResponse = try await networkService.authenticatedPost(url: url, body: payload, headers: headers)

            // Map response status to LockDevice.LockState
            let finalState: LockDevice.LockState
            switch response.status.lowercased() { // Assuming response has a 'status' field
                case "success", "pending", "locked", "unlocked": // Handle various success/intermediate states
                    // Optimistically return the intended state, or fetch status again if needed
                    finalState = (genericCommand == .lock) ? .locked : .unlocked 
                default: // Assume failure
                    finalState = .unknown // Or fetch actual status? Throw error?
                    // Log the failure based on response
                    auditLogger.logEvent(type: .deviceOperation, action: "commandSent", status: .failed, details: ["lockId": id, "command": yaleCommandString, "responseStatus": response.status])
                    throw LockOperationError.operationFailed("Yale command failed with status: \(response.status)")
            }
            
            auditLogger.logEvent(type: .deviceOperation, action: "commandSent", status: .success, details: ["lockId": id, "command": yaleCommandString, "responseStatus": response.status])
            return finalState

        } catch {
            auditLogger.logEvent(type: .deviceOperation, action: "commandSent", status: .failed, details: ["lockId": id, "command": yaleCommandString, "error": sanitizeError(error)])
            throw handleNetworkError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getToken() async throws -> String {
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
    
    private func validateCertificate(_ serverTrust: SecTrust) -> Bool {
        // Use SecTrustCopyCertificateChain (modern API)
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate], 
              !certificateChain.isEmpty else {
            return false
        }
        let serverCertificate = certificateChain[0] // Get the leaf certificate
        
        guard let serverCertificateData = SecCertificateCopyData(serverCertificate) as Data? else {
            return false
        }
        
        return pinnedCertificates.contains(serverCertificateData)
    }
    
    private func handleNetworkError(_ error: Error) -> LockOperationError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError
            case .serverCertificateUntrusted, .clientCertificateRejected:
                return .permissionDenied
            case .timedOut:
                return .operationFailed("Request timed out")
            default:
                return .operationFailed("Network error: \(urlError.localizedDescription)")
            }
        }
        return .operationFailed(error.localizedDescription)
    }
    
    private func sanitizeError(_ error: Error) -> String {
        // Remove sensitive information from error messages
        let errorString = error.localizedDescription
        return errorString.replacingOccurrences(of: #"([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})"#, with: "[REDACTED]", options: .regularExpression)
    }
    
    private func validateLockId(_ id: String) throws {
        // Yale lock IDs should be alphanumeric and between 8-32 characters
        guard id.range(of: "^[a-zA-Z0-9]{8,32}$", options: .regularExpression) != nil else {
            throw LockOperationError.invalidLockId
        }
    }
    
    private func validateOperation(_ operation: LockDevice.LockOperation) throws {
        switch operation {
        case .lock, .unlock:
            break // These are valid
        default:
            break // Other operations are not directly handled/validated here
        }
    }
    
    private func verifyLockState(_ id: String, expectedState: LockDevice.LockState) async throws {
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        let currentDevice = try await getLockStatus(id: id)
        guard currentDevice.currentState == expectedState else {
            throw LockOperationError.stateVerificationFailed
        }
    }
    
    // MARK: - Helper Methods - Added mapping function
    
    private func mapYaleLockToDevice(_ yaleLock: YaleLockResponse) -> LockDevice {
        // Map Yale states to our internal states
        let lockState: LockDevice.LockState
        switch yaleLock.deviceStatus.lowercased() {
        case "locked":
            lockState = .locked
        case "unlocked":
            lockState = .unlocked
        case "jammed":
            lockState = .jammed
        default:
            lockState = .unknown
        }

        // Attempt to parse the last updated date
        let dateFormatter = ISO8601DateFormatter()
        let lastChangeDate = dateFormatter.date(from: yaleLock.deviceMetadata.lastUpdated)

        return LockDevice(
            id: yaleLock.deviceId,
            name: yaleLock.deviceName,
            room: "Unknown", // Yale API doesn't typically provide room info here
            manufacturer: "Yale",
            model: yaleLock.deviceMetadata.model,
            firmwareVersion: yaleLock.deviceMetadata.firmwareVersion,
            isOnline: true, // Assuming online if fetched successfully, adjust if needed
            lastSeen: Date(), // Use current date as last seen
            dateAdded: Date(), // Placeholder - actual date added should come from DB
            metadata: [:], // Placeholder - add relevant metadata if available
            currentState: lockState,
            batteryLevel: yaleLock.batteryLevel,
            lastStateChange: lastChangeDate, // Use parsed date, nil if parsing failed
            isRemoteOperationEnabled: yaleLock.deviceMetadata.remoteOperationEnabled,
            accessHistory: [] // Placeholder - Access history fetched separately if needed
        )
    }
}

// Yale Token Manager
class YaleTokenManager {
    private let networkService: NetworkServiceProtocol
    private let keychainHelper: KeychainHelper
    private var currentToken: String?
    private var tokenExpiration: Date?
    
    private let clientId = YaleConfiguration.shared.clientId
    private let clientSecret = YaleConfiguration.shared.clientSecret
    let baseURL = YaleConfiguration.shared.baseURL
    
    init(networkService: NetworkServiceProtocol, keychainHelper: KeychainHelper) {
        self.networkService = networkService
        self.keychainHelper = keychainHelper
    }
    
    func getToken() async throws -> String {
        // Check if we have a valid token
        if let token = currentToken, let expiration = tokenExpiration, expiration > Date() {
            return token
        }
        
        // Try to get token from keychain - USE CORRECT METHODS
        if let savedTokenData = keychainHelper.getData(for: "yale_authToken"),
           let expirationData = keychainHelper.getData(for: "yale_tokenExpiration"),
           let expirationString = String(data: expirationData, encoding: .utf8),
           let expirationInterval = Double(expirationString) {
            
            let expirationDate = Date(timeIntervalSince1970: expirationInterval)
            if expirationDate > Date() {
                currentToken = String(data: savedTokenData, encoding: .utf8)
                tokenExpiration = expirationDate
                if let token = currentToken {
                    return token
                }
            }
        }
        
        // Need to get a new token
        return try await refreshToken()
    }
    
    func refreshToken() async throws -> String {
        // Get user credentials - USE CORRECT METHODS
        guard let usernameData = keychainHelper.getData(for: "yale_username"), // Use getData
              let passwordData = keychainHelper.getData(for: "yale_password") else { // Use getData
            throw YaleAuthError.invalidCredentials
        }
        
        let usernameString = String(data: usernameData, encoding: .utf8)!
        let passwordString = String(data: passwordData, encoding: .utf8)!
        
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
        
        // Make token request - USE CORRECT METHOD (authenticatedPost)
        // Assuming TokenResponse is Decodable and requestBody is Encodable
        guard let url = URL(string: "\(baseURL)/oauth/token") else { 
            throw YaleAuthError.invalidEndpoint // Or a more specific error
        }
        let tokenResponse: TokenResponse = try await networkService.authenticatedPost(
            url: url,
            body: requestBody,
            headers: ["Content-Type": "application/json"]
        )
        
        // Save the token
        currentToken = tokenResponse.access_token
        tokenExpiration = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        
        // Save to keychain - USE CORRECT METHODS
        guard let tokenData = tokenResponse.access_token.data(using: .utf8),
              let expirationStringData = String(tokenExpiration!.timeIntervalSince1970).data(using: .utf8) else {
            // Handle data conversion error
            print("Error converting token data for keychain saving.")
            throw YaleAuthError.credentialStorageFailed 
        }
        _ = keychainHelper.saveData(tokenData, for: "yale_authToken") // Use saveData
        _ = keychainHelper.saveData(expirationStringData, for: "yale_tokenExpiration") // Use saveData
        
        return tokenResponse.access_token
    }
    
    func saveCredentials(username: String, password: String) throws {
        // USE CORRECT METHODS
        guard let usernameData = username.data(using: .utf8),
              let passwordData = password.data(using: .utf8) else {
            print("Error converting credentials to data.")
            throw YaleAuthError.credentialStorageFailed
        }
        if !keychainHelper.saveData(usernameData, for: "yale_username") { // Use saveData
            print("Failed to save username to keychain.")
        }
        if !keychainHelper.saveData(passwordData, for: "yale_password") { // Use saveData
            print("Failed to save password to keychain.")
        }
    }
    
    func clearCredentials() throws {
        // USE CORRECT METHODS
        _ = keychainHelper.deleteItem(for: "yale_username") // Use deleteItem
        _ = keychainHelper.deleteItem(for: "yale_password") // Use deleteItem
        _ = keychainHelper.deleteItem(for: "yale_authToken") // Use deleteItem
        _ = keychainHelper.deleteItem(for: "yale_tokenExpiration") // Use deleteItem
        
        currentToken = nil
        tokenExpiration = nil
    }
    
    private func storeCredentials(_ credentials: YaleCredentials) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "YaleCredentials",
            kSecValueData as String: try JSONEncoder().encode(credentials),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrAccessControl as String: try createAccessControl()
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw YaleAuthError.credentialStorageFailed
        }
    }
    
    private func createAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleAfterFirstUnlock,
            .userPresence,
            &error
        ) else {
            throw YaleAuthError.credentialStorageFailed
        }
        return accessControl
    }
}

// Add new error cases
extension LockOperationError {
    static let invalidLockId = LockOperationError.operationFailed("Invalid lock ID format")
    static let invalidBatteryThreshold = LockOperationError.operationFailed("Invalid battery threshold value")
    static let invalidAutoLockDelay = LockOperationError.operationFailed("Invalid auto-lock delay value")
    static let stateVerificationFailed = LockOperationError.operationFailed("Lock state verification failed")
} 