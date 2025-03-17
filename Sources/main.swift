// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Models

print("UnifiedSmartHome Build Verification")
print("-----------------------------------")

// Check if we can create a LockDevice
do {
    // Create a simple LockDevice for testing
    let lockDevice = LockDevice(
        id: "test-lock",
        name: "Test Lock",
        room: "Living Room",
        manufacturer: "Test",
        model: "Test Model",
        firmwareVersion: "1.0.0",
        isOnline: true,
        lastSeen: Date(),
        dateAdded: Date(),
        metadata: [:],
        currentState: LockDevice.LockState.locked,
        batteryLevel: 100,
        lastStateChange: Date(),
        isRemoteOperationEnabled: true,
        accessHistory: []
    )

    print("Successfully created LockDevice: \(lockDevice.name)")
    print("Build verification successful!")
} catch {
    print("Error creating LockDevice: \(error)")
    print("Build verification failed!")
}
