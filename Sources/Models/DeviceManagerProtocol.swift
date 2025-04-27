import Foundation

/// Protocol defining the interface for managing device interactions via adapters.
public protocol DeviceManagerProtocol {
    
    /// Fetches all available devices from all configured adapters.
    /// - Returns: An array of devices conforming to AbstractDevice.
    /// - Throws: An error if fetching fails (may return partial results depending on implementation).
    func getAllDevices() async throws -> [AbstractDevice]
    
    /// Retrieves the current state of a specific device by querying the responsible adapter.
    /// - Parameter id: The unique identifier of the device.
    /// - Returns: The device with its current state.
    /// - Throws: An error if the device cannot be found or its state cannot be fetched.
    func getDeviceState(id: String) async throws -> AbstractDevice
    
    /// Executes a command on a specific device by delegating to the responsible adapter.
    /// - Parameters:
    ///   - deviceId: The unique identifier of the device.
    ///   - command: The command to execute (e.g., .lock, .setBrightness).
    /// - Returns: The device with its state after the command execution.
    /// - Throws: An error if the command fails, the device is not found, or the command is unsupported.
    func executeCommand(deviceId: String, command: DeviceCommand) async throws -> AbstractDevice
    
    /// Updates the health status of a device.
    /// - Parameters:
    ///   - device: The device instance to update.
    ///   - state: The new health state string (e.g., "ONLINE", "OFFLINE").
    /// - Throws: An error if the update fails.
    func updateDeviceHealth(_ device: AbstractDevice, state: String) async throws
    
    /// Adds a new device to the manager's tracking.
    /// - Parameter device: The device to add.
    /// - Throws: An error if adding fails.
    func addDevice(_ device: AbstractDevice) async throws
    
    /// Removes a device from the manager's tracking.
    /// - Parameter id: The unique identifier of the device to remove.
    /// - Throws: An error if removal fails.
    func removeDevice(id: String) async throws
} 