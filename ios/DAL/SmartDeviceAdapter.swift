import Foundation
import Combine

protocol SmartDeviceAdapter {
    func initializeConnection(authToken: String) throws
    func fetchDevices() async throws -> [AbstractDevice]
    func updateDeviceState(deviceId: String, newState: DeviceState) async throws -> DeviceState
}

// Represents a generic device state that can be used across different device types
struct DeviceState: Codable {
    var isOnline: Bool
    var attributes: [String: AnyCodable]
    
    init(isOnline: Bool = true, attributes: [String: AnyCodable] = [:]) {
        self.isOnline = isOnline
        self.attributes = attributes
    }
}

// Abstract base device class that specific device types will inherit from
class AbstractDevice: Identifiable, Codable {
    let id: String
    let name: String
    let manufacturer: Device.Manufacturer
    let type: Device.DeviceType
    let roomId: String?
    let propertyId: String
    var status: Device.DeviceStatus
    var capabilities: [Device.DeviceCapability]
    
    init(id: String, name: String, manufacturer: Device.Manufacturer, type: Device.DeviceType, 
         roomId: String?, propertyId: String, status: Device.DeviceStatus, 
         capabilities: [Device.DeviceCapability]) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.type = type
        self.roomId = roomId
        self.propertyId = propertyId
        self.status = status
        self.capabilities = capabilities
    }
    
    // Convert from abstracted device to the UI model
    func toDevice() -> Device {
        return Device(
            id: id,
            name: name,
            manufacturer: manufacturer,
            type: type,
            roomId: roomId,
            propertyId: propertyId,
            status: status,
            capabilities: capabilities
        )
    }
} 