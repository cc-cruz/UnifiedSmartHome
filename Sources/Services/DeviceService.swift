import Foundation
import Models // Ensure Models are imported for protocols and device types
import Combine // For potential future state publishing

// Service for managing devices via injected adapters
// Conforms to DeviceManagerProtocol - we may need to adjust the protocol later
class DeviceService: DeviceManagerProtocol {

    // Private storage for the injected adapters
    private let adapters: [SmartDeviceAdapter]
    
    // Logger (Optional but good practice)
    // private let logger: YourLoggerProtocol // Assuming a logging system exists

    // Dependency Injection via initializer
    // Removed singleton pattern
    // Inject adapters and any other dependencies (like a logger)
    init(adapters: [SmartDeviceAdapter]) { // logger: YourLoggerProtocol) {
        self.adapters = adapters
        // self.logger = logger
        print("DeviceService initialized with \\(adapters.count) adapters.")
    }

    // MARK: - Core DeviceManagerProtocol Implementation (Adapter-Based)

    // Fetch devices from all configured adapters concurrently
    func getAllDevices() async throws -> [AbstractDevice] {
        print("DeviceService: Fetching devices from all adapters...")
        
        // Use a TaskGroup to fetch from all adapters concurrently
        let allDevices = await withTaskGroup(of: Result<[AbstractDevice], Error>.self, returning: [AbstractDevice].self) { group in
            
            for adapter in adapters {
                group.addTask {
                    do {
                        // logger.debug("Fetching devices from adapter: \\(type(of: adapter))")
                        let devices = try await adapter.fetchDevices()
                        // logger.info("Fetched \\(devices.count) devices from adapter: \\(type(of: adapter))")
                        return .success(devices)
                    } catch {
                        // logger.error("Failed to fetch devices from adapter \\(type(of: adapter)): \\(error)")
                         print("Error fetching from adapter \\(type(of: adapter)): \\(error.localizedDescription)")
                        return .failure(error) // Propagate the error to handle below
                    }
                }
            }
            
            var combinedDevices: [AbstractDevice] = []
            for await result in group {
                switch result {
                case .success(let devices):
                    combinedDevices.append(contentsOf: devices)
                case .failure(let error):
                    // Decide how to handle partial failures.
                    // Option 1: Log and continue (returning partial results) - Chosen here
                     print("Warning: Adapter failed during fetch, returning partial results. Error: \\(error.localizedDescription)")
                    // Option 2: Rethrow the first error encountered
                    // throw error
                    // Option 3: Collect all errors and throw an aggregate error
                }
            }
            return combinedDevices
        }
        
        print("DeviceService: Fetched a total of \\(allDevices.count) devices.")
        // TODO: Consider caching results if appropriate (Sprint 5)
        // TODO: Consider filtering based on user permissions (Sprint 3)
        return allDevices
    }

    // Get the state of a specific device by querying adapters
    func getDeviceState(id: String) async throws -> AbstractDevice {
         print("DeviceService: Getting state for device ID \\(id)...")
        
        var lastError: Error? = nil
        
        for adapter in adapters {
            do {
                // logger.debug("Querying adapter \\(type(of: adapter)) for device state: \\(id)")
                let device = try await adapter.getDeviceState(deviceId: id)
                // logger.info("Found state for device \\(id) via adapter: \\(type(of: adapter))")
                return device
            } catch let error as SmartDeviceError where error == .deviceNotFound(id) {
                // This adapter doesn't have the device, try the next one
                // logger.debug("Device \\(id) not found by adapter: \\(type(of: adapter))")
                lastError = error // Keep track of the 'not found' error
                continue
            } catch let error as SmartDeviceError where isNotFoundError(error) {
                 // Handle other potential "not found" style errors from adapters
                 lastError = error
                 continue
             } catch {
                // A different error occurred (e.g., network, API error from this adapter)
                // logger.error("Error getting state for device \\(id) from adapter \\(type(of: adapter)): \\(error)")
                 print("Error getting state for \\(id) from adapter \\(type(of: adapter)): \\(error.localizedDescription)")
                lastError = error // Record the error
                // Option: Re-throw immediately if a non-'not found' error occurs?
                // throw error
            }
        }
        
        // If we looped through all adapters and didn't find it or encountered errors
        // logger.warning("Device \\(id) not found by any adapter.")
        throw lastError ?? DeviceServiceError.deviceNotFound // Throw last error, default to NotFound
    }

    // Execute a command by delegating to the appropriate adapter
    func executeCommand(deviceId: String, command: DeviceCommand) async throws -> AbstractDevice {
        print("DeviceService: Executing command \\(command) for device ID \\(deviceId)...")
        
        var lastError: Error? = nil
        
        for adapter in adapters {
            do {
                // logger.debug("Attempting command \\(command) on device \\(deviceId) via adapter: \\(type(of: adapter))")
                let updatedDevice = try await adapter.executeCommand(deviceId: deviceId, command: command)
                // logger.info("Command \\(command) successful for device \\(deviceId) via adapter: \\(type(of: adapter))")
                
                // TODO: Publish state change notifications (using Combine/Notifications)
                
                return updatedDevice
            } catch let error as SmartDeviceError where error == .deviceNotFound(deviceId) {
                 // logger.debug("Device \\(deviceId) not found by adapter \\(type(of: adapter)) for command execution.")
                 lastError = error
                 continue // Try next adapter
             } catch let error as SmartDeviceError where isNotFoundError(error) {
                 // Handle other potential "not found" style errors from adapters
                 lastError = error
                 continue
            } catch let error as SmartDeviceError where error == .commandNotSupported(String(describing: command)) || error == .unsupportedOperation {
                // This adapter found the device but doesn't support the command. This *might* mean no other adapter will either.
                // logger.warning("Command \\(command) not supported by adapter \\(type(of: adapter)) for device \\(deviceId).")
                // Option 1: Continue searching other adapters (Chosen here - maybe another adapter handles it?)
                lastError = error
                continue
                // Option 2: Throw immediately, assuming command is unsupported for the device type
                // throw error
            } catch {
                // A different error occurred (network, API, command failed)
                // logger.error("Error executing command \\(command) for device \\(deviceId) from adapter \\(type(of: adapter)): \\(error)")
                 print("Error executing command for \\(deviceId) from adapter \\(type(of: adapter)): \\(error.localizedDescription)")
                 lastError = error
                 // Option: Re-throw immediately? Depends on desired behaviour for partial failures.
                 // throw error
            }
        }
        
        // If we looped through all adapters and couldn't execute the command
        // logger.error("Command \\(command) could not be executed for device \\(deviceId) by any adapter.")
        throw lastError ?? DeviceServiceError.commandExecutionFailed // Throw last encountered error, default to general failure
    }


    // MARK: - Methods to Re-evaluate or Remove

    // These methods operated on the old in-memory dictionary and are less relevant
    // when adapters are the source of truth. They might be removed or adapted
    // depending on whether DeviceManagerProtocol requires them.

    func getDevice(id: String) async throws -> AbstractDevice {
        // This should likely just call getDeviceState if needed by the protocol
        print("WARN: DeviceService.getDevice(id:) called - consider using getDeviceState.")
        return try await getDeviceState(id: id)
    }

    // updateDeviceState with AnyCodable seems complex and potentially unnecessary
    // if state updates come via executeCommand -> getDeviceState.
    func updateDeviceState(_ device: AbstractDevice, with data: [String : AnyCodable]?) async throws {
         print("WARN: DeviceService.updateDeviceState with AnyCodable data is likely obsolete.")
         // If needed, this would require finding the correct adapter and potentially
         // mapping the AnyCodable data back to a specific adapter command/update mechanism.
         // This is highly complex and error-prone. Best avoided.
         throw DeviceServiceError.operationNotSupported("Direct state update with AnyCodable")
    }

    // Specific state updates should go through executeCommand
    func updateLockState(deviceId: String, newState: LockDevice.LockState) async throws {
        print("WARN: DeviceService.updateLockState called - use executeCommand(.lock/.unlock) instead.")
        let command: DeviceCommand = (newState == .locked) ? .lock : .unlock
        _ = try await executeCommand(deviceId: deviceId, command: command)
        // Note: We discard the returned AbstractDevice here as this func doesn't return it.
    }

    func updateSwitchState(deviceId: String, isOn: Bool) async throws {
        print("WARN: DeviceService.updateSwitchState called - use executeCommand(.setSwitch) instead.")
         _ = try await executeCommand(deviceId: deviceId, command: .setSwitch(isOn))
    }
    
    // Device health should be part of the state returned by getDeviceState
    func updateDeviceHealth(_ device: AbstractDevice, state: String) async throws {
         print("WARN: DeviceService.updateDeviceHealth is likely obsolete. Health is part of device state.")
         // If explicit health update needed, maybe map state to a specific command?
         // Otherwise, health (e.g., isOnline) should come from getDeviceState polling/events.
         throw DeviceServiceError.operationNotSupported("Explicit health update")
    }

    // fetchDevice is redundant if getDeviceState is used.
    func fetchDevice(id: String) async throws -> AbstractDevice? {
        print("WARN: DeviceService.fetchDevice called - consider using getDeviceState.")
        do {
            return try await getDeviceState(id: id)
        } catch DeviceServiceError.deviceNotFound {
            return nil // Match original optional return type
        } catch {
             throw error // Propagate other errors
        }
    }

    // Adding/removing devices is managed by the vendor platforms, not this service.
    // Adapters discover devices via fetchDevices.
    func addDevice(_ device: AbstractDevice) async throws {
         print("WARN: DeviceService.addDevice called - Device addition is handled by vendor platforms.")
         throw DeviceServiceError.operationNotSupported("Manual device addition")
    }

    func removeDevice(id: String) async throws {
        print("WARN: DeviceService.removeDevice called - Device removal is handled by vendor platforms.")
        // We *could* potentially tell an adapter to revoke access/delete credentials
        // associated with a deviceId if the protocol demanded it.
        throw DeviceServiceError.operationNotSupported("Manual device removal")
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

// Updated/Simplified Error types for DeviceService
enum DeviceServiceError: Error, Equatable {
    case deviceNotFound
    case commandExecutionFailed
    case operationNotSupported(String) // Indicate which operation
    case adapterFetchError(String) // Contains description from underlying adapter error
    // Add other specific errors as needed
}

// TODO: Review DeviceManagerProtocol and update it to align with this
// adapter-based approach. Remove methods that are no longer relevant.
