import Foundation

/// Defines common errors that can occur when interacting with smart device adapters.
public enum SmartDeviceError: Error, Equatable {
    case deviceNotFound(String) // Associated value for device ID
    case commandNotSupported(String) // Associated value for command description
    case commandFailed(String?) // Optional associated value for reason
    case authenticationRequired(String?) // Optional reason
    case authenticationFailed(String?) // Optional reason
    case apiError(String?) // Optional reason from the vendor API
    case networkError(String?) // Optional description of the network issue
    case mappingError(String?) // Optional description of data mapping issue
    case resourceNotFound(String?) // Optional description
    case unsupportedOperation // General unsupported operation

    // Add other cases as needed based on adapter implementations
}

// Optional: Provide localized descriptions if desired
extension SmartDeviceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .deviceNotFound(let id):
            return "Device not found with ID: \(id)"
        case .commandNotSupported(let command):
            return "Command not supported: \(command)"
        case .commandFailed(let reason):
            return "Command failed" + (reason.map { ": \($0)" } ?? "")
        case .authenticationRequired(let reason):
            return "Authentication required" + (reason.map { ": \($0)" } ?? "")
        case .authenticationFailed(let reason):
            return "Authentication failed" + (reason.map { ": \($0)" } ?? "")
        case .apiError(let reason):
            return "API error" + (reason.map { ": \($0)" } ?? "")
        case .networkError(let reason):
            return "Network error" + (reason.map { ": \($0)" } ?? "")
        case .mappingError(let reason):
            return "Data mapping error" + (reason.map { ": \($0)" } ?? "")
        case .resourceNotFound(let reason):
            return "Resource not found" + (reason.map { ": \($0)" } ?? "")
        case .unsupportedOperation:
            return "The operation is not supported."
        }
    }
} 