import Foundation

/// Webhook subscription request
public struct SmartThingsWebhookSubscription: Codable {
    public let webhookId: String
    public let url: String
    public let events: [SmartThingsWebhookEvent]
    public let deviceIds: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case webhookId = "webhookId"
        case url = "url"
        case events = "events"
        case deviceIds = "deviceIds"
    }
}

/// Webhook event types
public enum SmartThingsWebhookEvent: String, Codable {
    case deviceEvent = "DEVICE_EVENT"
    case deviceHealth = "DEVICE_HEALTH"
    case deviceLifecycle = "DEVICE_LIFECYCLE"
}

/// Webhook event payload
public struct SmartThingsWebhookEventPayload: Codable {
    public let eventId: String
    public let eventType: SmartThingsWebhookEvent
    public let deviceId: String
    public let timestamp: String
    public let data: [String: AnyCodable]
    
    private enum CodingKeys: String, CodingKey {
        case eventId = "eventId"
        case eventType = "eventType"
        case deviceId = "deviceId"
        case timestamp = "timestamp"
        case data = "data"
    }
}

/// Webhook subscription response
public struct SmartThingsWebhookSubscriptionResponse: Codable {
    public let webhookId: String
    public let url: String
    public let events: [SmartThingsWebhookEvent]
    public let deviceIds: [String]?
    public let status: String
    public let createdAt: String
    
    private enum CodingKeys: String, CodingKey {
        case webhookId = "webhookId"
        case url = "url"
        case events = "events"
        case deviceIds = "deviceIds"
        case status = "status"
        case createdAt = "createdAt"
    }
} 