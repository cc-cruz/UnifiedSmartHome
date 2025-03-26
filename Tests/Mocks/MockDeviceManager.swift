import Foundation
@testable import UnifiedSmartHome

class MockDeviceManager: DeviceManagerProtocol {
    var getDeviceResult: AbstractDevice?
    var fetchDeviceResult: AbstractDevice?
    var updateDeviceStateCalled = false
    var updateDeviceStateDevice: AbstractDevice?
    var updateDeviceStateData: [String: AnyCodable]?
    var updateDeviceHealthCalled = false
    var updateDeviceHealthDevice: AbstractDevice?
    var updateDeviceHealthState: String?
    var addDeviceCalled = false
    var addDeviceDevice: AbstractDevice?
    var removeDeviceCalled = false
    var removeDeviceId: String?
    
    func getDevice(id: String) async throws -> AbstractDevice? {
        return getDeviceResult
    }
    
    func fetchDevice(id: String) async throws -> AbstractDevice? {
        return fetchDeviceResult
    }
    
    func updateDeviceState(_ device: AbstractDevice, with data: [String: AnyCodable]) async throws {
        updateDeviceStateCalled = true
        updateDeviceStateDevice = device
        updateDeviceStateData = data
    }
    
    func updateDeviceHealth(_ device: AbstractDevice, state: String) async throws {
        updateDeviceHealthCalled = true
        updateDeviceHealthDevice = device
        updateDeviceHealthState = state
    }
    
    func addDevice(_ device: AbstractDevice) async throws {
        addDeviceCalled = true
        addDeviceDevice = device
    }
    
    func removeDevice(id: String) async throws {
        removeDeviceCalled = true
        removeDeviceId = id
    }
} 