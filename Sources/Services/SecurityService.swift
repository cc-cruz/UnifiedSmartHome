import Foundation
import Models
// The protocol OperationalSecurityProtocol is defined in SecurityServiceProtocol.swift

public class SecurityService: OperationalSecurityProtocol {
    private let userManager: UserManager
    private let auditLogger: AuditLogger
    private let deviceManager: DeviceManagerProtocol
    private let portfolioService: PortfolioServiceProtocol

    public init(userManager: UserManager, auditLogger: AuditLogger, deviceManager: DeviceManagerProtocol, portfolioService: PortfolioServiceProtocol) {
        self.userManager = userManager
        self.auditLogger = auditLogger
        self.deviceManager = deviceManager
        self.portfolioService = portfolioService
    }

    public func canUser(_ user: User, performOperation operation: LockDevice.LockOperation, onDevice device: LockDevice, portfolioResolver: (String) async -> Portfolio?) async -> Bool {
        guard device.isOnline else {
            auditLogger.logSecurityEvent(type: "permission_denied_device_offline", details: [
                "userId": user.id, "deviceId": device.id, "operation": operation.rawValue,
                "reason": "Device is offline"
            ])
            return false
        }

        if let associations = user.roleAssociations {
            for association in associations {
                switch association.associatedEntityType {
                case .unit:
                    if association.associatedEntityId == device.unitId {
                        if checkUnitLevelPermissions(forRole: association.roleWithinEntity, operation: operation, device: device) {
                            return true
                        }
                    }
                case .property:
                    if association.associatedEntityId == device.propertyId {
                        if checkPropertyLevelPermissions(forRole: association.roleWithinEntity, operation: operation, device: device) {
                            return true
                        }
                    }
                case .portfolio:
                    if let propertyId = device.propertyId,
                       let portfolio = await portfolioResolver(propertyId) {
                        if portfolio.id == association.associatedEntityId {
                           if checkPortfolioLevelPermissions(forRole: association.roleWithinEntity, operation: operation, device: device) {
                                return true
                            }
                        }
                    }
                }
            }
        }

        auditLogger.logSecurityEvent(type: "permission_denied_no_matching_role", details: [
            "userId": user.id, "deviceId": device.id, "operation": operation.rawValue,
            "deviceUnitId": device.unitId ?? "N/A", "devicePropertyId": device.propertyId ?? "N/A"
        ])
        return false
    }

    private func checkUnitLevelPermissions(forRole role: User.Role, operation: LockDevice.LockOperation, device: LockDevice) -> Bool {
        switch role {
        case .tenant:
            switch operation {
            case .lock, .unlock, .viewStatus:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }

    private func checkPropertyLevelPermissions(forRole role: User.Role, operation: LockDevice.LockOperation, device: LockDevice) -> Bool {
        switch role {
        case .propertyManager:
            switch operation {
            case .lock, .unlock, .viewStatus, .changeSettings, .viewAccessHistory:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }

    private func checkPortfolioLevelPermissions(forRole role: User.Role, operation: LockDevice.LockOperation, device: LockDevice) -> Bool {
        switch role {
        case .portfolioAdmin, .owner:
            return true
        default:
            return false
        }
    }

    public func validateLockOperation(user: User, device: LockDevice, operation: LockDevice.LockOperation) async throws {
        let portfolioResolver: (String) async -> Portfolio? = { [weak self] propertyId in
            guard let self = self else { return nil }
            return await self.portfolioService.fetchPortfolioForProperty(propertyId: propertyId)
        }

        let hasPermission = await canUser(user, performOperation: operation, onDevice: device, portfolioResolver: portfolioResolver)

        if hasPermission {
            var successLogDetails: [String: String] = [
                "userId": user.id,
                "deviceId": device.id,
                "operation": operation.rawValue,
                "lockPropertyId": device.propertyId ?? "N/A",
                "lockUnitId": device.unitId ?? "N/A"
            ]
            if let associations = user.roleAssociations, let primaryAssociation = associations.first {
                 successLogDetails["userPrimaryRole"] = "\(primaryAssociation.roleWithinEntity.rawValue)@\(primaryAssociation.associatedEntityType.rawValue):\(primaryAssociation.associatedEntityId)"
            }
            auditLogger.logSecurityEvent(type: "access_granted_by_rbac", details: successLogDetails)
        } else {
            var logDetails: [String: String] = [
                "reason": "insufficient_permissions_rbac",
                "userId": user.id,
                "deviceId": device.id,
                "operation": operation.rawValue,
                "lockPropertyId": device.propertyId ?? "N/A",
                "lockUnitId": device.unitId ?? "N/A"
            ]
            if let associations = user.roleAssociations {
                let rolesDescription = associations.map { "\($0.roleWithinEntity.rawValue)@\($0.associatedEntityType.rawValue):\($0.associatedEntityId)" }.joined(separator: ", ")
                logDetails["userRoles"] = rolesDescription
            } else {
                logDetails["userRoles"] = "No associations found"
            }
            auditLogger.logSecurityEvent(type: "access_denied_by_rbac", details: logDetails)
            throw SecurityError.insufficientPermissions
        }
        
        if operation == .unlock && userManager.requiresBiometricConfirmationForUnlock {
            print("INFO: Biometric confirmation would be required for unlock operation by user \(user.id) on device \(device.id). Ensure authenticateAndPerform is integrated if this check is active.")
        }
    }

    public func getLockDevice(id: String) async throws -> LockDevice {
        guard let device = try? await self.deviceManager.getDeviceState(id: id),
              let lockDevice = device as? LockDevice else {
            let errorMessage = "Failed to get LockDevice with ID: \(id). Device not found or not a LockDevice."
            auditLogger.logSecurityEvent(type: "get_lock_device_failed", details: [
                "deviceId": id,
                "errorReason": errorMessage
            ])
            throw SecurityError.deviceNotFound
        }
        return lockDevice
    }

    public func secureCriticalOperation(completion: @escaping () throws -> Void) async throws {
        guard !isDeviceJailbroken() else {
            auditLogger.logSecurityEvent(type: "security_violation", details: ["reason": "jailbroken_device"])
            throw SecurityError.operationNotAllowed("Operation not allowed on jailbroken device.")
        }
        
        try await Task.detached {
            try completion()
        }.value
    }

    public func authenticateAndPerform(_ reason: String, completion: @escaping () throws -> Void) async throws {
        try completion()
    }

    public func isDeviceJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let jailbreakFiles = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]
        
        for path in jailbreakFiles {
            if FileManager.default.fileExists(atPath: path) {
                auditLogger.logSecurityEvent(type: "security_alert", details: ["reason": "jailbreak_file_found", "path": path])
                return true
            }
        }
        
        let restrictedPath = "/private/" + UUID().uuidString
        do {
            try "test".write(toFile: restrictedPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: restrictedPath)
            auditLogger.logSecurityEvent(type: "security_alert", details: ["reason": "jailbreak_write_check_successful", "path": restrictedPath])
            return true
        } catch {
        }
        
        return false
        #endif
    }

    // MARK: - Conformance to OperationalSecurityProtocol
    public func validateUserPermission(userId: String, deviceId: String, operation: String) async throws -> Bool {
        // TODO: Implement actual permission validation logic based on multi-tenancy rules.
        // This is a placeholder implementation.
        print("WARN: validateUserPermission is not fully implemented. Returning true by default for userId: \(userId), deviceId: \(deviceId), operation: \(operation)")
        auditLogger.logSecurityEvent(type: "permission_check_stubbed", details: [
            "userId": userId,
            "deviceId": deviceId,
            "operation": operation,
            "result": "allowed_by_default_stub"
        ])
        return true // Placeholder
    }
}

public enum SecurityError: Error, LocalizedError {
    case userNotFound
    case deviceNotFound
    case insufficientPermissions
    case biometricAuthRequired
    case biometricAuthFailed
    case operationNotAllowed(String? = nil)
    case unsupportedOperation
    case portfolioResolutionFailed
    
    public var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .deviceNotFound:
            return "Device not found"
        case .insufficientPermissions:
            return "You don't have permission to perform this operation"
        case .biometricAuthRequired:
            return "Biometric authentication is required for this operation"
        case .biometricAuthFailed:
            return "Biometric authentication failed"
        case .operationNotAllowed(let reason):
            return reason ?? "This operation is not allowed"
        case .unsupportedOperation:
            return "This operation type is not supported for validation"
        case .portfolioResolutionFailed:
            return "Could not determine portfolio context for the device to check permissions"
        }
    }
}

public protocol PortfolioServiceProtocol {
    func fetchPortfolioForProperty(propertyId: String) async -> Portfolio?
}