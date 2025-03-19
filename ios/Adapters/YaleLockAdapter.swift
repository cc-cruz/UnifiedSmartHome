import Foundation
import Combine

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

// Yale-specific adapter
class YaleLockAdapter: LockAdapter {
    private var authToken: String?
    private let baseURL = YaleConfiguration.shared.baseURL
    private let networkService: NetworkServiceProtocol
    private let tokenManager: YaleTokenManager
    private let securityService: SecurityServiceProtocol
    private let auditLogger: AuditLoggerProtocol
    
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
    
    init(networkService: NetworkServiceProtocol = NetworkService(),
         securityService: SecurityServiceProtocol = SecurityService(),
         auditLogger: AuditLoggerProtocol = AuditLogger()) {
        self.networkService = networkService
        self.tokenManager = YaleTokenManager(networkService: networkService)
        self.securityService = securityService
        self.auditLogger = auditLogger
    }
    
    func initialize(with authToken: String) throws {
        self.authToken = authToken
    }
    
    func fetchLocks() async throws -> [LockDevice] {
        do {
            let token = try await tokenManager.getValidToken()
            
            // Log the operation attempt
            auditLogger.logEvent(
                type: .lockOperation,
                action: "fetch_locks",
                status: .started,
                details: ["adapter": "yale"]
            )
            
            let response: YaleLocksResponse = try await networkService.request(
                endpoint: "\(self.baseURL)/devices",
                token: token,
                headers: ["x-api-key": YaleConfiguration.shared.apiKey],
                certificateValidation: { [weak self] serverTrust in
                    self?.validateCertificate(serverTrust) ?? false
                }
            )
            
            // Log successful operation
            auditLogger.logEvent(
                type: .lockOperation,
                action: "fetch_locks",
                status: .success,
                details: ["adapter": "yale", "count": response.locks.count]
            )
            
            return response.locks.map { self.mapYaleLockToDevice($0) }
        } catch {
            // Log failed operation
            auditLogger.logEvent(
                type: .lockOperation,
                action: "fetch_locks",
                status: .failed,
                details: [
                    "adapter": "yale",
                    "error": sanitizeError(error)
                ]
            )
            
            throw handleNetworkError(error)
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
                headers: ["x-api-key": YaleConfiguration.shared.apiKey]
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
                headers: ["x-api-key": YaleConfiguration.shared.apiKey]
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
    
    func controlLock(id: String, operation: LockOperation) async throws {
        do {
            // Input validation
            try validateLockId(id)
            try validateOperation(operation)
            
            // For unlock operations, require biometric authentication
            if case .unlock = operation {
                try await securityService.authenticateAndPerform("Authenticate to unlock your door") {
                    // Continue with the operation after successful authentication
                }
            }
            
            // Check for jailbroken device
            try await securityService.secureCriticalOperation {
                // Log operation attempt
                auditLogger.logEvent(
                    type: .lockOperation,
                    action: "control_lock",
                    status: .started,
                    details: [
                        "adapter": "yale",
                        "lock_id": id,
                        "operation": String(describing: operation)
                    ]
                )
                
                // Continue with normal operation flow
            }
            
            let token = try await tokenManager.getValidToken()
            
            // Map operation to Yale API command
            let command: String
            switch operation {
            case .lock:
                command = "lock"
            case .unlock:
                command = "unlock"
            case .updateSettings(let settings):
                command = "update_settings"
            }
            
            // Prepare request body
            let requestBody: [String: Any] = [
                "command": command,
                "parameters": operation.parameters
            ]
            
            // Send command
            let _: EmptyResponse = try await networkService.request(
                endpoint: "\(self.baseURL)/devices/\(id)/control",
                method: .post,
                token: token,
                body: requestBody,
                headers: ["x-api-key": YaleConfiguration.shared.apiKey],
                certificateValidation: { [weak self] serverTrust in
                    self?.validateCertificate(serverTrust) ?? false
                }
            )
            
            // Verify state change for lock/unlock operations
            if case .lock = operation {
                try await verifyLockState(id, expectedState: .locked)
            } else if case .unlock = operation {
                try await verifyLockState(id, expectedState: .unlocked)
            }
            
            // Log successful operation
            auditLogger.logEvent(
                type: .lockOperation,
                action: "control_lock",
                status: .success,
                details: [
                    "adapter": "yale",
                    "lock_id": id,
                    "operation": String(describing: operation)
                ]
            )
        } catch let error as SecurityError {
            // Log security failure
            auditLogger.logEvent(
                type: .securityEvent,
                action: "control_lock",
                status: .failed,
                details: [
                    "adapter": "yale",
                    "lock_id": id,
                    "operation": String(describing: operation),
                    "error": "security_error",
                    "reason": error.localizedDescription
                ]
            )
            throw error
        } catch {
            // Log failed operation
            auditLogger.logEvent(
                type: .lockOperation,
                action: "control_lock",
                status: .failed,
                details: [
                    "adapter": "yale",
                    "lock_id": id,
                    "operation": String(describing: operation),
                    "error": sanitizeError(error)
                ]
            )
            
            throw handleNetworkError(error)
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
    
    private func validateCertificate(_ serverTrust: SecTrust) -> Bool {
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            return false
        }
        
        guard let serverCertificateData = SecCertificateCopyData(serverCertificate) as Data? else {
            return false
        }
        
        return pinnedCertificates.contains(serverCertificateData)
    }
    
    private func handleNetworkError(_ error: Error) -> LockError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError
            case .serverCertificateUntrusted, .clientCertificateRejected:
                return .securityError
            case .timedOut:
                return .timeout
            default:
                return .unknown
            }
        }
        return .unknown
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
    
    private func validateOperation(_ operation: LockOperation) throws {
        // Validate operation parameters
        switch operation {
        case .lock, .unlock:
            // These operations don't require additional parameters
            break
        case .updateSettings(let settings):
            // Validate settings
            if let batteryThreshold = settings.batteryThreshold {
                guard batteryThreshold >= 0 && batteryThreshold <= 100 else {
                    throw LockOperationError.invalidBatteryThreshold
                }
            }
            if let autoLockDelay = settings.autoLockDelay {
                guard autoLockDelay >= 0 && autoLockDelay <= 3600 else {
                    throw LockOperationError.invalidAutoLockDelay
                }
            }
        }
    }
    
    private func verifyLockState(_ id: String, expectedState: LockDevice.LockState) async throws {
        // Add a small delay to allow the lock to complete its operation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Get current state
        let currentState = try await getLockStatus(id)
        
        // Verify state matches expected
        guard currentState == expectedState else {
            throw LockOperationError.stateVerificationFailed
        }
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
    private let baseURL = YaleConfiguration.shared.baseURL
    
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
            throw AuthenticationError.credentialStorageFailed
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
            throw AuthenticationError.credentialStorageFailed
        }
        return accessControl
    }
}

// Authentication error types
enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case tokenExpired
    case networkError
    case credentialStorageFailed
    case certificateValidationFailed
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid Yale credentials"
        case .tokenExpired:
            return "Yale authentication token has expired"
        case .networkError:
            return "Network error during Yale authentication"
        case .credentialStorageFailed:
            return "Failed to store or retrieve credentials"
        case .certificateValidationFailed:
            return "Certificate validation failed"
        case .timeout:
            return "Authentication request timed out"
        }
    }
}

// Add new error cases
extension LockOperationError {
    static let invalidLockId = LockOperationError.operationFailed("Invalid lock ID format")
    static let invalidBatteryThreshold = LockOperationError.operationFailed("Invalid battery threshold value")
    static let invalidAutoLockDelay = LockOperationError.operationFailed("Invalid auto-lock delay value")
    static let stateVerificationFailed = LockOperationError.operationFailed("Lock state verification failed")
} 