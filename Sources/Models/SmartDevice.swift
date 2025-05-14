import Foundation

/// A protocol representing a smart home device, refining the basic AbstractDevice.
/// Concrete device types (LockDevice, LightDevice, etc.) should conform to this protocol.
public protocol SmartDevice: AbstractDevice {
    // Initially, this protocol might not add new requirements beyond AbstractDevice.
    // It serves as a more specific type constraint for newer interfaces
    // and can be expanded later with common properties/methods if needed.
}

// Example: How a concrete type might conform (DO NOT ADD THIS TO THE FILE)
// struct LockDevice: SmartDevice {
//     var id: String
//     var name: String
//     var type: DeviceType
//     var status: DeviceStatus
//     var lockState: LockState
//     // ... other properties and methods ...
// } 