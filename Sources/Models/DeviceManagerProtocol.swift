import Foundation
import Combine // Ensure Combine is imported if needed for any async sequences/publishers potentially added later

/// Protocol defining the interface for managing device interactions via adapters.
public protocol DeviceManagerProtocol {

    // MARK: - Original AbstractDevice Methods (Potentially used elsewhere)

    /// Fetches all available devices from all configured adapters.
    /// - Returns: An array of devices conforming to AbstractDevice.
    /// - Throws: An error if fetching fails.
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


    // MARK: - Methods Required by Webhook Handlers & Newer Implementations (Using SmartDevice)

    /// Fetches a specific device by its ID (potentially returning a more concrete type).
    /// Used by webhook handlers.
    /// - Parameter id: The unique identifier of the device.
    /// - Returns: The `SmartDevice` if found, otherwise nil.
    /// - Throws: An error if the underlying fetch operation fails.
    func getDevice(id: String) async throws -> SmartDevice?

    /// Fetches detailed device information from the underlying service/API (potentially creating/updating).
    /// Used by webhook handlers for lifecycle events.
    /// - Parameter id: The unique identifier of the device.
    /// - Returns: The `SmartDevice` if found/fetched, otherwise nil.
    /// - Throws: An error if the underlying fetch operation fails.
    func fetchDevice(id: String) async throws -> SmartDevice?

    /// Adds a new device (likely of type `SmartDevice`) to the manager's tracking.
    /// Used by webhook handlers.
    /// - Parameter device: The `SmartDevice` to add.
    /// - Throws: An error if adding fails.
    func addDevice(_ device: SmartDevice) async throws

    /// Removes a device from the manager's tracking using its ID.
    /// Used by webhook handlers.
    /// - Parameter id: The unique identifier of the device to remove.
    /// - Throws: An error if removal fails.
    func removeDevice(id: String) async throws // Note: Signature matches AbstractDevice version, implementation detail matters

    /// Updates the lock state of a specific device.
    /// Used by webhook handlers.
    /// - Parameters:
    ///   - deviceId: The ID of the lock device.
    ///   - newState: The target `LockDevice.LockState`.
    /// - Throws: An error if the update fails or device not found.
    func updateLockState(deviceId: String, newState: LockDevice.LockState) async throws

    /// Updates the switch state (on/off) of a specific device.
    /// Used by webhook handlers.
    /// - Parameters:
    ///   - deviceId: The ID of the switch device.
    ///   - isOn: The target state (true for on, false for off).
    /// - Throws: An error if the update fails or device not found.
    func updateSwitchState(deviceId: String, isOn: Bool) async throws

    /// Updates the health status of a specific device (using SmartDevice).
    /// Used by webhook handlers.
    /// - Parameters:
    ///   - device: The `SmartDevice` instance to update.
    ///   - state: The new health state string (e.g., "ONLINE", "OFFLINE").
    /// - Throws: An error if the update fails.
    func updateDeviceHealth(_ device: SmartDevice, state: String) async throws

} 