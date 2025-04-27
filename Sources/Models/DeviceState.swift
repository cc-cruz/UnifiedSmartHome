import Foundation

// Represents a generic device state that can be used across different device types
public struct DeviceState: Codable {
    public var deviceType: String?
    public var isOnline: Bool
    public var attributes: [String: AnyCodable]
    
    public init(deviceType: String? = nil, isOnline: Bool = true, attributes: [String: AnyCodable] = [:]) {
        self.deviceType = deviceType
        self.isOnline = isOnline
        self.attributes = attributes
    }
} 