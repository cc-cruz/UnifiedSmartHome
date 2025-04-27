import Foundation
import Combine
import Models
import Services

/// Protocol for handling SmartThings webhook events
public protocol SmartThingsWebhookHandlerProtocol {
    func handleEvent(_ event: SmartThingsWebhookEventPayload) async throws
}

/// Default implementation of SmartThings webhook handler
public class SmartThingsWebhookHandler: SmartThingsWebhookHandlerProtocol {
    private let deviceManager: DeviceManagerProtocol
    private let auditLogger: AuditLoggerProtocol
    
    public init(deviceManager: DeviceManagerProtocol, auditLogger: AuditLoggerProtocol) {
        self.deviceManager = deviceManager
        self.auditLogger = auditLogger
    }
    
    public func handleEvent(_ event: SmartThingsWebhookEventPayload) async throws {
        // Log the event
        auditLogger.logEvent(
            type: .deviceOperation,
            action: "webhook_device_update",
            status: .success,
            details: ["device_id": event.deviceId, "source": "webhook"]
        )
        
        // Handle different event types
        switch event.eventType {
        case .deviceEvent:
            try await handleDeviceEvent(event)
        case .deviceHealth:
            try await handleDeviceHealth(event)
        case .deviceLifecycle:
            try await handleDeviceLifecycle(event)
        }
    }
    
    private func handleDeviceEvent(_ event: SmartThingsWebhookEventPayload) async throws {
        // Update device state based on event data
        let deviceData = event.data

        // --- Example: Handling Lock Events ---
        if deviceData["capability"]?.value as? String == "lock",
           deviceData["attribute"]?.value as? String == "lock",
           let lockValue = deviceData["value"]?.value as? String {

            let newState: LockDevice.LockState
            switch lockValue.lowercased() {
            case "locked":
                newState = .locked
            case "unlocked":
                newState = .unlocked
            default:
                newState = .unknown // Or log an error for unexpected value
                print("Warning: Received unknown lock state '\\(lockValue)' for deviceId: \\(event.deviceId)")
            }

            // Call a specific update method (adjust if your protocol is different)
            try await deviceManager.updateLockState(deviceId: event.deviceId, newState: newState)

        }
        // --- Example: Handling Switch Events (Lights/Switches) ---
        else if deviceData["capability"]?.value as? String == "switch",
                deviceData["attribute"]?.value as? String == "switch",
                let switchValue = deviceData["value"]?.value as? String {

             let newSwitchState: Bool
             switch switchValue.lowercased() {
             case "on":
                 newSwitchState = true
             case "off":
                 newSwitchState = false
             default:
                 // Handle unknown state or log error
                 print("Warning: Received unknown switch state '\\(switchValue)' for deviceId: \\(event.deviceId)")
                 // Decide how to handle - maybe return or use a default?
                 return // Example: Ignore unknown states for now
             }

             // Assume DeviceManager has a method like this
             // You might need separate LightDevice models/state enums
             try await deviceManager.updateSwitchState(deviceId: event.deviceId, isOn: newSwitchState)

         }
         // --- Add more 'else if' blocks here for other capabilities (switchLevel, etc.) ---
         else {
             // Optional: Log unhandled device events
             let _ = deviceData["capability"]?.value as? String ?? "N/A"
             let _ = deviceData["attribute"]?.value as? String ?? "N/A"
             print("Info: Received unhandled deviceEvent for deviceId: \(event.deviceId)")
             // You might still want a generic fallback if necessary,
             // but specific handling is preferred.
             // Original generic call (consider removing or using carefully):
             // if let device = try await deviceManager.getDevice(id: event.deviceId) {
             //     try await deviceManager.updateDeviceState(device, with: event.data)
             // }
         }
    }
    
    private func handleDeviceHealth(_ event: SmartThingsWebhookEventPayload) async throws {
        // Update device health status
        let device = try await deviceManager.getDevice(id: event.deviceId)
        
        if let healthState = event.data["healthState"]?.value as? String {
            try await deviceManager.updateDeviceHealth(device, state: healthState)
        }
    }
    
    private func handleDeviceLifecycle(_ event: SmartThingsWebhookEventPayload) async throws {
        // Handle device lifecycle events (added, removed, etc.)
        if let lifecycleEvent = event.data["lifecycle"]?.value as? String {
            switch lifecycleEvent {
            case "ADDED":
                // Fetch and add new device
                if let device = try await deviceManager.fetchDevice(id: event.deviceId) {
                    try await deviceManager.addDevice(device)
                }
            case "REMOVED":
                // Remove device
                try await deviceManager.removeDevice(id: event.deviceId)
            default:
                break
            }
        }
    }
} 