import Foundation

// Represents the commands that can be sent to a Yale lock.
public enum YaleLockCommand: String, Codable {
    case lock
    case unlock
    // Add other Yale-specific commands if necessary
}

// Represents the payload required for the Yale lock command endpoint.
public struct YaleLockCommandPayload: Encodable {
    public let operation: String // Should match YaleLockCommand rawValue

    public init(operation: String) {
        self.operation = operation
    }
}

// Represents the expected response structure after executing a Yale lock command.
// This is a placeholder and may need adjustment based on the actual API response.
public struct YaleLockCommandResponse: Decodable {
    public let status: String // Example property, adjust as needed
    // Add other relevant fields from the actual API response.
}

// Represents the expected response structure when fetching Yale lock status.
// This is a placeholder and may need adjustment based on the actual API response.
public struct YaleLockStatusResponse: Decodable {
    public let lockState: String // e.g., "locked", "unlocked"
    public let batteryLevel: Int? // Example property
    // Add other relevant status fields.

    // Example coding keys if needed
    enum CodingKeys: String, CodingKey {
        case lockState = "deviceStatus" // Map to actual API field name if different
        case batteryLevel
    }
}

// Represents the response structure when fetching a list of Yale locks.
// Used in YaleLockAdapter's fetchLocks method (internally).
public struct YaleLocksResponse: Decodable {
    public let locks: [YaleLockResponse]

    public init(locks: [YaleLockResponse]) {
        self.locks = locks
    }
}

// Represents a single Yale lock as returned by their API list endpoint.
// Used in YaleLockAdapter's fetchLocks method (internally).
public struct YaleLockResponse: Decodable {
    public let deviceId: String
    public let deviceName: String
    public let deviceStatus: String
    public let batteryLevel: Int
    public let deviceMetadata: YaleLockMetadata

    public init(deviceId: String, deviceName: String, deviceStatus: String, batteryLevel: Int, deviceMetadata: YaleLockMetadata) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.deviceStatus = deviceStatus
        self.batteryLevel = batteryLevel
        self.deviceMetadata = deviceMetadata
    }

    public struct YaleLockMetadata: Decodable {
        public let lastUpdated: String // Consider decoding as Date if format is consistent
        public let remoteOperationEnabled: Bool
        public let model: String
        public let firmwareVersion: String

        public init(lastUpdated: String, remoteOperationEnabled: Bool, model: String, firmwareVersion: String) {
            self.lastUpdated = lastUpdated
            self.remoteOperationEnabled = remoteOperationEnabled
            self.model = model
            self.firmwareVersion = firmwareVersion
        }
    }
}

// Represents potential authentication errors specific to Yale integration.
public enum YaleAuthError: Error {
    case invalidCredentials
    case tokenRefreshFailed
    case credentialStorageFailed
    case invalidEndpoint
} 