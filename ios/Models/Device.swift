import Foundation

struct Device: Codable, Identifiable {
    let id: String
    let name: String
    let manufacturer: Manufacturer
    let type: DeviceType
    let roomId: String?
    let propertyId: String
    var status: DeviceStatus
    var capabilities: [DeviceCapability]
    
    enum Manufacturer: String, Codable {
        case samsung = "SAMSUNG"
        case lg = "LG"
        case ge = "GE"
        case googleNest = "GOOGLE_NEST"
        case philipsHue = "PHILIPS_HUE"
        case amazon = "AMAZON"
        case apple = "APPLE"
        case other = "OTHER"
    }
    
    enum DeviceType: String, Codable {
        case light = "LIGHT"
        case thermostat = "THERMOSTAT"
        case lock = "LOCK"
        case camera = "CAMERA"
        case doorbell = "DOORBELL"
        case speaker = "SPEAKER"
        case tv = "TV"
        case appliance = "APPLIANCE"
        case sensor = "SENSOR"
        case other = "OTHER"
    }
    
    enum DeviceStatus: String, Codable {
        case online = "ONLINE"
        case offline = "OFFLINE"
        case error = "ERROR"
    }
    
    struct DeviceCapability: Codable {
        let type: String
        // Use the AnyCodable from AnyCodable.swift
        let attributes: [String: AnyCodable]
    }
} 