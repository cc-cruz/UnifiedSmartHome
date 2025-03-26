import Foundation
import Combine

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
        try await auditLogger.logEvent(
            category: .deviceEvent,
            action: .webhookReceived,
            status: .success,
            details: [
                "eventId": event.eventId,
                "eventType": event.eventType.rawValue,
                "deviceId": event.deviceId,
                "timestamp": event.timestamp
            ]
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
        if let device = try await deviceManager.getDevice(id: event.deviceId) {
            try await deviceManager.updateDeviceState(device, with: event.data)
        }
    }
    
    private func handleDeviceHealth(_ event: SmartThingsWebhookEventPayload) async throws {
        // Update device health status
        if let device = try await deviceManager.getDevice(id: event.deviceId) {
            if let healthState = event.data["healthState"]?.value as? String {
                try await deviceManager.updateDeviceHealth(device, state: healthState)
            }
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