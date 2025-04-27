import Foundation
import Combine
import Models
import Helpers
import Services

// Configuration for August API
struct AugustConfiguration {
    static let apiKey = "YOUR_AUGUST_API_KEY" // Replace with actual API key
    static let baseURL = "https://api.august.com"
}

// August-specific adapter
class AugustLockAdapter: LockAdapter {
    private var authToken: String?
    private let baseURL = AugustConfiguration.baseURL
    private let networkService: NetworkServiceProtocol
    private let tokenManager: AugustTokenManager
    
    // Rate limiting properties
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 0.5 // 500ms between requests
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelayBase: TimeInterval = 2.0
    
    init(networkService: NetworkServiceProtocol, tokenManager: AugustTokenManager) {
        self.networkService = networkService
        self.tokenManager = tokenManager
    }
    
    func initialize(with authToken: String) throws {
        self.authToken = authToken
    }
    
    func fetchLocks() async throws -> [LockDevice] {
        return try await withRetry { [weak self] in
            guard let self = self else { throw LockOperationError.operationFailed("Adapter deallocated") }
            
            _ = try await self.ensureValidToken()
            
            // Define August-specific response type
            struct AugustLockResponse: Decodable {
                let lockID: String
                let LockName: String
                let currentState: String
                let batteryPercentage: Int
                let properties: AugustLockProperties
                
                struct AugustLockProperties: Decodable {
                    let lastStateChange: String
                    let supportsRemoteOperation: Bool
                }
            }
            
            // Fetch from API
            guard let url = URL(string: "\(self.baseURL)/locks") else { 
                throw LockOperationError.operationFailed("Invalid URL") 
            }
            let locks: [AugustLockResponse] = try await self.networkService.authenticatedGet(
                url: url,
                headers: ["x-august-api-key": AugustConfiguration.apiKey]
            )
            
            // Convert to our model
            return locks.map { lockData in
                let dateFormatter = ISO8601DateFormatter()
                let lastChangeDate = dateFormatter.date(from: lockData.properties.lastStateChange)
                
                // Map August states to our internal states
                let lockState: LockDevice.LockState
                switch lockData.currentState.lowercased() {
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
                    id: lockData.lockID,
                    name: lockData.LockName,
                    room: "Unknown Room", // Use houseName or default
                    manufacturer: "August", // Pass as String
                    model: "Smart Lock", // Placeholder - get actual model if available
                    firmwareVersion: "Unknown", // Use firmware or default
                    isOnline: lockData.currentState.lowercased() != "offline", // Check online status
                    currentState: lockState,
                    batteryLevel: lockData.batteryPercentage,
                    lastStateChange: lastChangeDate,
                    isRemoteOperationEnabled: lockData.properties.supportsRemoteOperation
                )
            }
        }
    }
    
    func getLockStatus(id: String) async throws -> LockDevice {
        return try await withRetry { [weak self] in
            guard let self = self else { throw LockOperationError.operationFailed("Adapter deallocated") }
            
            _ = try await self.ensureValidToken()
            
            // Define August-specific response type
            struct AugustLockDetailResponse: Decodable {
                let lockID: String
                let LockName: String
                let currentState: String
                let batteryPercentage: Int
                let properties: AugustLockProperties
                let history: [AugustHistoryEntry]?
                
                struct AugustLockProperties: Decodable {
                    let lastStateChange: String
                    let supportsRemoteOperation: Bool
                }
                
                struct AugustHistoryEntry: Decodable {
                    let timestamp: String
                    let action: String
                    let userId: String
                    let result: String
                    let error: String?
                }
            }
            
            // Fetch from API
            guard let url = URL(string: "\(self.baseURL)/locks/\(id)") else { 
                throw LockOperationError.operationFailed("Invalid URL") 
            }
            let lockDetail: AugustLockDetailResponse = try await self.networkService.authenticatedGet(
                url: url,
                headers: ["x-august-api-key": AugustConfiguration.apiKey]
            )
            
            // Convert to our model
            let dateFormatter = ISO8601DateFormatter()
            let lastChangeDate = dateFormatter.date(from: lockDetail.properties.lastStateChange)
            
            // Map August states to our internal states
            let lockState: LockDevice.LockState
            switch lockDetail.currentState.lowercased() {
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
            var accessHistory: [LockDevice.LockAccessRecord] = []
            if let historyEntries = lockDetail.history {
                accessHistory = historyEntries.compactMap { entry in
                    guard let timestamp = dateFormatter.date(from: entry.timestamp) else { return nil }
                    
                    let operation: LockDevice.LockOperation
                    switch entry.action.lowercased() {
                    case "lock":
                        operation = .lock
                    case "unlock":
                        operation = .unlock
                    default:
                        return nil // Skip unknown operations
                    }
                    
                    return LockDevice.LockAccessRecord(
                        timestamp: timestamp,
                        operation: operation,
                        userId: entry.userId,
                        success: entry.result.lowercased() == "success",
                        failureReason: entry.error
                    )
                }
            }
            
            return LockDevice(
                id: lockDetail.lockID,
                name: lockDetail.LockName,
                room: "Unknown Room", // Use houseName or default
                manufacturer: "August", // Pass as String
                model: "Smart Lock", // Placeholder - get actual model if available
                firmwareVersion: "Unknown", // Use firmware or default
                isOnline: lockDetail.currentState.lowercased() != "offline", // Check online status
                currentState: lockState,
                batteryLevel: lockDetail.batteryPercentage,
                lastStateChange: lastChangeDate,
                isRemoteOperationEnabled: lockDetail.properties.supportsRemoteOperation,
                accessHistory: accessHistory
            )
        }
    }
    
    func controlLock(id: String, command: LockCommand) async throws -> LockDevice.LockState {
        return try await withRetry { [weak self] in
            guard let self = self else { throw LockOperationError.operationFailed("Adapter deallocated") }
            
            _ = try await self.ensureValidToken()
            
            let action = command == .lock ? "lock" : "unlock"
            
            // Updated call to use URL and remove explicit token
            guard let url = URL(string: "\(self.baseURL)/locks/\(id)/\(action)") else { 
                throw LockOperationError.operationFailed("Invalid URL") 
            }
            
            // Assuming authenticatedPut returns the updated state or confirmation
            // Define expected response type (e.g., AugustLockStateResponse)
            struct AugustLockStateResponse: Decodable {
                let status: String // e.g., "locked", "unlocked"
                // Add other relevant fields if needed
            }
            
            let response: AugustLockStateResponse = try await self.networkService.authenticatedPut(
                url: url,
                body: Optional<String>.none, // Empty body for lock/unlock
                headers: ["x-august-api-key": AugustConfiguration.apiKey]
            )
            
            // Convert response status to our LockState
            switch response.status.lowercased() {
            case "locked": return .locked
            case "unlocked": return .unlocked
            case "jammed": return .jammed
            default: return .unknown
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func ensureValidToken() async throws -> String {
        if let token = self.authToken {
            return token
        }
        
        return try await tokenManager.ensureValidToken()
    }
    
    // Generic retry function with exponential backoff
    private func withRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var retries = 0
        var lastError: Error? = nil
        
        while retries <= maxRetries {
            do {
                // Respect rate limiting
                try await respectRateLimit()
                
                // Execute operation
                return try await operation()
            } catch let error as LockOperationError where error.isRetryable {
                lastError = error
                retries += 1
                
                if retries <= maxRetries {
                    // Log retry attempt
                    print("Retrying August API request (attempt \(retries)/\(maxRetries)): \(error.localizedDescription)")
                    
                    // Exponential backoff
                    let delay = retryDelayBase * pow(2.0, Double(retries - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                throw error
            }
        }
        
        throw lastError ?? LockOperationError.operationFailed("Max retries exceeded")
    }
    
    // Ensure we don't exceed rate limits
    private func respectRateLimit() async throws {
        guard let lastRequest = lastRequestTime else {
            lastRequestTime = Date()
            return
        }
        
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
        if timeSinceLastRequest < minRequestInterval {
            let waitTime = minRequestInterval - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
}

// Extension to determine if an error is retryable
extension LockOperationError {
    var isRetryable: Bool {
        switch self {
        case .networkError, .rateLimited:
            return true
        default:
            return false
        }
    }
}

// MARK: - August API Response Structures (Simplified)

struct AugustLock: Codable {
    let lockID: String
    let LockName: String
    let houseName: String?
    let firmwareVersion: String?
    let lockStatus: String? // Example: "locked", "unlocked"
    let battery: Double // Example: 0.9 (90%)
    let status: AugustLockStatus? // Assuming status contains detailed state
}

struct AugustLockStatus: Codable { 
    let status: String? // e.g., "loaded", might indicate online/offline or other state
    let lockStatus: String? // "locked", "unlocked"
    // Add other relevant status fields based on API
}

struct AugustLockDetail: Codable { // Assumed structure
    let lockID: String
    let LockName: String
    let houseName: String?
    let firmwareVersion: String?
    let model: String?
    let lockStatus: String?
    let battery: Double
    let status: AugustLockStatus? // Contains detailed state
    // Add other fields as needed
}

// MARK: - Error Enum

enum AugustLockError: Error, LocalizedError {
    case authenticationFailed(String)
    case fetchFailed(String)
    case commandFailed(String)
    case decodingFailed(Error)
    case invalidURL
    case unsupportedCommand(String)
    case tokenError(AugustTokenManager.TokenError)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let reason): return "August authentication failed: \(reason)"
        case .fetchFailed(let reason): return "Failed to fetch August locks: \(reason)"
        case .commandFailed(let reason): return "Failed to execute command on August lock: \(reason)"
        case .decodingFailed(let error): return "Failed to decode August API response: \(error.localizedDescription)"
        case .invalidURL: return "Invalid URL constructed for August API call."
        case .unsupportedCommand(let cmd): return "Command not supported by August adapter: \(cmd)"
        case .tokenError(let tokenError): return "August token error: \(tokenError.localizedDescription)"
        }
    }
} 