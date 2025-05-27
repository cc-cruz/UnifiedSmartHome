import Foundation
import Models // Ensure Models are imported for protocols and device types
import Combine // For potential future state publishing
import SwiftUI

// Service for managing devices via injected adapters
// Conforms to DeviceManagerProtocol - we may need to adjust the protocol later
class DeviceService<Context: UserContextInterface>: DeviceManagerProtocol where Context: ObservableObject {

    // Private storage for the injected adapters
    private let adapters: [SmartDeviceAdapter]
    private let userManager: UserManager // Added UserManager dependency
    private let apiService: APIService   // Added APIService dependency
    @ObservedObject private var userContextProvider: Context // Use the generic type Context
    
    // Logger (Optional but good practice)
    // private let logger: YourLoggerProtocol // Assuming a logging system exists

    // Dependency Injection via initializer
    // Removed singleton pattern
    // Inject adapters and any other dependencies (like a logger)
    init(adapters: [SmartDeviceAdapter], userManager: UserManager, apiService: APIService, userContextProvider: Context) { // Use Context for parameter
        self.adapters = adapters
        self.userManager = userManager // Store injected UserManager
        self.apiService = apiService     // Store injected APIService
        self.userContextProvider = userContextProvider // Store injected UserContextInterface
        // self.logger = logger
        print("DeviceService initialized with \(adapters.count) adapters, UserManager, APIService, and UserContextInterface.")
    }

    // MARK: - Core DeviceManagerProtocol Implementation (Adapter-Based)

    // Fetch devices from all configured adapters concurrently and filter by user permissions
    func getAllDevices() async throws -> [AbstractDevice] {
        print("DeviceService: Fetching devices from backend API based on UserContextInterface...")
        
        guard userManager.currentUser != nil else {
            print("DeviceService: No current user found. Returning empty list.")
            // Or throw an authentication error, e.g., DeviceServiceError.authenticationRequired
            return [] 
        }

        let propertyId: String? = userContextProvider.selectedPropertyId // Use the protocol property
        let unitId: String? = userContextProvider.selectedUnitId // Use the protocol property

        print("DeviceService: Fetching with context - PropertyID: \(propertyId ?? "None"), UnitID: \(unitId ?? "None")")

        return try await fetchDevices(propertyId: propertyId, unitId: unitId)
    }

    // New method to fetch devices with specific context or all accessible if context is nil
    public func fetchDevices(propertyId: String?, unitId: String?) async throws -> [AbstractDevice] {
        print("DeviceService: Fetching devices with PropertyID: \(propertyId ?? "nil"), UnitID: \(unitId ?? "nil")")

        guard userManager.currentUser != nil else {
            print("DeviceService: No current user for fetchDevices. Returning empty list.")
            return []
        }
        
        // Using a cancellable for the Combine publisher
        var cancellables = Set<AnyCancellable>()

        do {
            let devicesFromAPI: [Device] = try await withCheckedThrowingContinuation { continuation in
                apiService.getDevices(propertyId: propertyId, unitId: unitId) 
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("DeviceService: Error fetching devices from API: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        }
                    }, receiveValue: { devices in
                        print("DeviceService: Successfully fetched \(devices.count) devices from API.")
                        continuation.resume(returning: devices)
                    })
                    .store(in: &cancellables) // Manage subscription
            }
            
            // Transform [Models.Device] to [AbstractDevice]
            let abstractDevices: [AbstractDevice] = devicesFromAPI.compactMap { apiDevice -> AbstractDevice? in
                // Determine the concrete type based on apiDevice.deviceTypeName or capabilities
                // This is a simplified example; you might need more sophisticated logic
                let typeName = apiDevice.deviceTypeName?.lowercased() ?? "generic"
                
                // TODO: Enhance type determination logic, possibly using capabilities as well.
                // For now, primarily using deviceTypeName.

                if typeName.contains("lock") {
                    return LockDevice(fromApiDevice: apiDevice)
                } else if typeName.contains("light") || typeName.contains("bulb") {
                    return LightDevice(fromApiDevice: apiDevice)
                } else if typeName.contains("switch") {
                    return SwitchDevice(fromApiDevice: apiDevice)
                } else if typeName.contains("thermostat") {
                    return ThermostatDevice(fromApiDevice: apiDevice)
                } else {
                    // Fallback to GenericDevice
                    return GenericDevice(fromApiDevice: apiDevice)
                }
            }
            
            print("DeviceService: Transformed \(abstractDevices.count) devices to AbstractDevice subclasses.")
            return abstractDevices

        } catch {
            print("DeviceService: Failed to fetch devices from backend API. Error: \(error.localizedDescription)")
            throw error
        }
    }

    // Get the state of a specific device by querying adapters
    func getDeviceState(id: String) async throws -> AbstractDevice {
         print("DeviceService: Getting state for device ID \(id)...")
        
        var lastError: Error? = nil
        var foundDevice: AbstractDevice? = nil
        
        for adapter in adapters {
            do {
                let device = try await adapter.getDeviceState(deviceId: id)
                foundDevice = device // Store device temporarily to get its portfolio ID
                break // Found device, exit adapter loop
            } catch let error as SmartDeviceError where error == .deviceNotFound(id) {
                lastError = error 
                continue
            } catch let error as SmartDeviceError where isNotFoundError(error) {
                 lastError = error
                 continue
             } catch {
                 lastError = error 
            }
        }
        
        guard let device = foundDevice else {
            throw lastError ?? DeviceServiceError.deviceNotFound
        }

        // After fetching, verify if the current user should see this device
        if let currentUser = userManager.currentUser {
            let devicePropertyId: String? = (device as? LockDevice)?.propertyId ?? device.metadata["propertyId"]
            let deviceUnitId: String? = (device as? LockDevice)?.unitId ?? device.metadata["unitId"]
            var devicePortfolioId: String? = nil
            if let propId = devicePropertyId {
                devicePortfolioId = userManager.getPortfolioIdForProperty(propertyId: propId)
            }

            if !currentUser.canAccessDevice(propertyId: devicePropertyId, unitId: deviceUnitId, deviceId: device.id, devicePortfolioId: devicePortfolioId) {
                print("DeviceService: User \(currentUser.id) not authorized for device \(id) after fetch.")
                throw DeviceServiceError.unauthorizedAccess
            }
        }
        return device
    }

    // Execute a command by delegating to the appropriate adapter
    // Permissions for command execution are handled by SecurityService -> LockDAL -> LockDevice.canPerformRemoteOperation
    // So, no explicit permission check needed here again, assuming SecurityService is called first.
    func executeCommand(deviceId: String, command: DeviceCommand) async throws -> AbstractDevice {
        print("DeviceService: Executing command \(command) for device ID \(deviceId)...")
        
        var lastError: Error? = nil
        
        for adapter in adapters {
            do {
                // logger.debug("Attempting command \(command) on device \(deviceId) via adapter: \(type(of: adapter))")
                let updatedDevice = try await adapter.executeCommand(deviceId: deviceId, command: command)
                // logger.info("Command \(command) successful for device \(deviceId) via adapter: \(type(of: adapter))")
                
                // TODO: Publish state change notifications (using Combine/Notifications)
                
                return updatedDevice
            } catch let error as SmartDeviceError where error == .deviceNotFound(deviceId) {
                 // logger.debug("Device \(deviceId) not found by adapter \(type(of: adapter)) for command execution.")
                 lastError = error
                 continue // Try next adapter
             } catch let error as SmartDeviceError where isNotFoundError(error) {
                 // Handle other potential "not found" style errors from adapters
                 lastError = error
                 continue
            } catch let error as SmartDeviceError where error == .commandNotSupported(String(describing: command)) || error == .unsupportedOperation {
                // This adapter found the device but doesn't support the command. This *might* mean no other adapter will either.
                // logger.warning("Command \(command) not supported by adapter \(type(of: adapter)) for device \(deviceId).")
                // Option 1: Continue searching other adapters (Chosen here - maybe another adapter handles it?)
                lastError = error
                continue
                // Option 2: Throw immediately, assuming command is unsupported for the device type
                // throw error
            } catch {
                // A different error occurred (network, API, command failed)
                // logger.error("Error executing command \(command) for device \(deviceId) from adapter \(type(of: adapter)): \(error)")
                 print("Error executing command for \(deviceId) from adapter \(type(of: adapter)): \(error.localizedDescription)")
                 lastError = error
                 // Option: Re-throw immediately? Depends on desired behaviour for partial failures.
                 // throw error
            }
        }
        
        // If we looped through all adapters and couldn't execute the command
        // logger.error("Command \(command) could not be executed for device \(deviceId) by any adapter.")
        throw lastError ?? DeviceServiceError.commandExecutionFailed // Throw last encountered error, default to general failure
    }

    // MARK: - DeviceManagerProtocol Methods Using SmartDevice (Stubs)

    func getDevice(id: String) async throws -> SmartDevice? {
        print("STUB: DeviceService.getDevice(id:) called - Requires multi-tenancy review.")
        // TODO: Implement logic to find the correct adapter and call its getDeviceState,
        //       then attempt to cast/convert the result to SmartDevice? or fetch specific SmartDevice data.
        //       For now, returning nil or re-throwing getDeviceState error after casting might work.
        fatalError("Not implemented. Requires multi-tenancy review.")
    }

    func fetchDevice(id: String) async throws -> SmartDevice? {
        print("STUB: DeviceService.fetchDevice(id:) called - Requires multi-tenancy review.")
        // TODO: Implement logic, potentially similar to getDevice, but maybe focused on fetching
        //       fresh data from the source API via an adapter.
        fatalError("Not implemented. Requires multi-tenancy review.")
    }

    func addDevice(_ device: SmartDevice) async throws {
        print("STUB: DeviceService.addDevice(SmartDevice) called - Device onboarding needs multi-tenancy design.")
        // TODO: Logic likely involves finding the responsible adapter and potentially
        //       calling an adapter-specific registration or update method.
        //       Manual addition is complex; often handled by adapter discovery.
        fatalError("Not implemented. Device onboarding needs multi-tenancy design.")
    }

    // Note: removeDevice(id:) signature matches both AbstractDevice and SmartDevice uses in the protocol.
    // The existing warning/throw implementation might suffice if manual removal isn't supported.
    // If specific SmartDevice removal logic is needed, this needs adjusting.
    func removeDevice(id: String) async throws {
        print("WARN: DeviceService.removeDevice called - Requires multi-tenancy review and design.")
        throw DeviceServiceError.operationNotSupported("Manual device removal - multi-tenancy review needed")
    }

    func updateLockState(deviceId: String, newState: LockDevice.LockState) async throws {
        print("DeviceService: updateLockState called for device ID \(deviceId). Routing to executeCommand.")
        let command: DeviceCommand = (newState == .locked) ? .lock : .unlock
        _ = try await executeCommand(deviceId: deviceId, command: command) 
        print("INFO: Attempted lock state update via executeCommand for \(deviceId).")
    }

    func updateSwitchState(deviceId: String, isOn: Bool) async throws {
        print("DeviceService: updateSwitchState called for device ID \(deviceId). Routing to executeCommand.")
        _ = try await executeCommand(deviceId: deviceId, command: .setSwitch(isOn))
        print("INFO: Attempted switch state update via executeCommand for \(deviceId).")
    }

    func updateDeviceHealth(_ device: SmartDevice, state: String) async throws {
        print("STUB: DeviceService.updateDeviceHealth(SmartDevice:state:) called - Requires multi-tenancy review.")
        // TODO: Implement logic. This might involve finding the adapter and calling
        //       an adapter-specific health update method, or this might be purely
        //       informational based on adapter polling/events and not directly settable.
        fatalError("Not implemented. Requires multi-tenancy review.")
    }

    // MARK: - Helper for Error Checking
    
    // Helper to check for various "not found" type errors from adapters
    // This might need refinement based on actual errors thrown by adapters
    private func isNotFoundError(_ error: Error) -> Bool {
        if let smartError = error as? SmartDeviceError {
            switch smartError {
            case .deviceNotFound, .resourceNotFound: // Add .resourceNotFound if defined
                return true
            default:
                return false
            }
        }
        // Add checks for specific underlying adapter errors if needed
        // e.g., if let hueError = error as? HueError where hueError.type == HUE_RESOURCE_NOT_FOUND_CODE
        return false
    }
}

// MODIFIED: Make DeviceServiceError public
public enum DeviceServiceError: Error, Equatable {
    case deviceNotFound
    case commandExecutionFailed
    case operationNotSupported(String) // Indicate which operation
    case adapterFetchError(String) // Contains description from underlying adapter error
    case unauthorizedAccess // Added for getDeviceState explicit check
    // Add other specific errors as needed
}

// Convenience extension for User model to check device access
// This should ideally be part of User.swift or a User+Permissions.swift extension file.
// For brevity in this edit, placing it here temporarily.
extension User {
    func canAccessDevice(propertyId devicePropertyId: String?, unitId deviceUnitId: String?, deviceId: String, devicePortfolioId: String?) -> Bool {
        guard let associations = self.roleAssociations else {
            // If user has no associations, check for general guest access by deviceId only
            if let guestAccess = self.guestAccess, guestAccess.deviceIds.contains(deviceId) {
                let now = Date()
                return now >= guestAccess.validFrom && now <= guestAccess.validUntil && guestAccess.propertyId == nil && guestAccess.unitId == nil
            }
            return false
        }

        for association in associations {
            switch association.associatedEntityType {
            case .portfolio:
                if association.roleWithinEntity == .portfolioAdmin || association.roleWithinEntity == .owner {
                    // User is admin/owner of portfolio `association.associatedEntityId`.
                    // Grant access ONLY if the device's portfolio (devicePortfolioId) matches `association.associatedEntityId`.
                    if let dPortfolioId = devicePortfolioId, dPortfolioId == association.associatedEntityId {
                        // print("DEBUG: User \(self.id) access GRANTED to device in portfolio \(dPortfolioId) based on portfolio admin/owner role for \(association.associatedEntityId)")
                        return true // Device is in the portfolio this user administers.
                    } else {
                        // print("DEBUG: User \(self.id) access DENIED/SKIPPED for device (portfolio: \(devicePortfolioId ?? "nil")) based on portfolio admin/owner role for \(association.associatedEntityId)")
                        // If devicePortfolioId is nil, or doesn't match, this specific portfolio role does not grant access.
                        // We continue to check other associations or guest access.
                    }
                }
            case .property:
                if let propId = devicePropertyId, propId == association.associatedEntityId {
                    if association.roleWithinEntity == .propertyManager {
                        return true // Manager of this property
                    }
                }
            case .unit:
                if let uId = deviceUnitId, uId == association.associatedEntityId {
                    if association.roleWithinEntity == .tenant {
                        return true // Tenant of this unit
                    }
                }
            }
        }

        // Check guest access tied to specific property/unit or device ID
        if let guestAccess = self.guestAccess, guestAccess.deviceIds.contains(deviceId) {
            let now = Date()
            guard now >= guestAccess.validFrom && now <= guestAccess.validUntil else { return false }

            if let guestPropertyId = guestAccess.propertyId {
                if guestPropertyId == devicePropertyId { return true } // Guest for this property & device
            } else if let guestUnitId = guestAccess.unitId {
                if guestUnitId == deviceUnitId { return true } // Guest for this unit & device
            } else {
                return true // General guest access for this device ID, not tied to property/unit
            }
        }
        return false
    }
}

// TODO: Review DeviceManagerProtocol and update it to align with this
// adapter-based approach. Remove methods that are no longer relevant.
