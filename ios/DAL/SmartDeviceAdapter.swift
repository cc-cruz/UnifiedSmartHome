import Foundation
import Combine

protocol SmartDeviceAdapter {
    func initializeConnection(authToken: String) throws
    func fetchDevices() async throws -> [AbstractDevice]
    func updateDeviceState(deviceId: String, newState: DeviceState) async throws -> DeviceState
}

// Default implementation of executeCommand for adapters
extension SmartDeviceAdapter {
    func executeCommand<T: AbstractDevice>(device: T, command: DeviceCommand) async throws -> T {
        // Default implementation throws unimplemented error
        throw DeviceOperationError.operationFailed("Command execution not implemented by this adapter")
    }
} 