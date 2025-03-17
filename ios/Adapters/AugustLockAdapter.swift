import Foundation
import Combine

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
            
            let token = try await self.getValidToken()
            
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
            let locks: [AugustLockResponse] = try await self.networkService.authenticatedGet(
                endpoint: "\(self.baseURL)/locks",
                token: token,
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
                    manufacturer: .august,
                    roomId: nil, // We'll need to fetch this separately or through a mapping service
                    propertyId: "", // Will need to be populated from our database
                    status: .online, // Assuming it's online if we got data
                    capabilities: [
                        Device.DeviceCapability(
                            type: "lock_control",
                            attributes: [
                                "supports_remote": AnyCodable(lockData.properties.supportsRemoteOperation)
                            ]
                        )
                    ],
                    currentState: lockState,
                    batteryLevel: lockData.batteryPercentage,
                    lastStateChange: lastChangeDate,
                    isRemoteOperationEnabled: lockData.properties.supportsRemoteOperation,
                    accessHistory: [] // Would need a separate API call to fetch this
                )
            }
        }
    }
    
    func getLockStatus(id: String) async throws -> LockDevice {
        return try await withRetry { [weak self] in
            guard let self = self else { throw LockOperationError.operationFailed("Adapter deallocated") }
            
            let token = try await self.getValidToken()
            
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
            let lockDetail: AugustLockDetailResponse = try await self.networkService.authenticatedGet(
                endpoint: "\(self.baseURL)/locks/\(id)",
                token: token,
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
                manufacturer: .august,
                roomId: nil,
                propertyId: "",
                status: .online,
                capabilities: [
                    Device.DeviceCapability(
                        type: "lock_control",
                        attributes: [
                            "supports_remote": AnyCodable(lockDetail.properties.supportsRemoteOperation)
                        ]
                    )
                ],
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
            
            let token = try await self.getValidToken()
            
            // Create request body
            let commandString = command == .lock ? "lock" : "unlock"
            let requestBody = ["command": commandString]
            
            // Define response type
            struct AugustLockResponse: Decodable {
                let status: String
                let dateTime: String
                let result: String
            }
            
            // Send command to API
            let response: AugustLockResponse = try await self.networkService.authenticatedPut(
                endpoint: "\(self.baseURL)/locks/\(id)/status",
                token: token,
                body: requestBody,
                headers: ["x-august-api-key": AugustConfiguration.apiKey]
            )
            
            // Check for success
            guard response.result.lowercased() == "success" else {
                throw LockOperationError.operationFailed("Operation failed with result: \(response.result)")
            }
            
            // Map response status to our lock state
            let lockState: LockDevice.LockState
            switch response.status.lowercased() {
            case "locked":
                lockState = .locked
            case "unlocked":
                lockState = .unlocked
            case "jammed":
                throw LockOperationError.lockJammed
            default:
                lockState = .unknown
            }
            
            return lockState
        }
    }
    
    // MARK: - Helper Methods
    
    private func getValidToken() async throws -> String {
        if let token = self.authToken {
            return token
        }
        
        return try await tokenManager.getValidToken()
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