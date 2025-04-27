import Foundation
import Combine
import Models
import Services // Assuming NetworkServiceProtocol and potential HueTokenManager are here or accessible

// MARK: - Hue API Data Structures (V2 /clip/v2/resource)

/// Generic wrapper for Hue API GET responses
struct HueGetResponse<T: Decodable>: Decodable {
    let errors: [HueError]
    let data: [T]
}

struct HuePutResponse: Decodable {
    let errors: [HueError]
    let data: [HuePutResult]? // Contains rids (resource identifiers) of updated items
}

struct HuePutResult: Decodable {
    let rid: String // Resource ID (e.g., light UUID)
    let rtype: String // Resource type (e.g., "light")
}


struct HueError: Decodable, Error {
    let description: String
    // Potentially add type, address, etc. if needed
}

/// Represents a generic Hue resource (used for filtering)
struct HueResource: Decodable {
    let id: String // UUID
    let type: String // e.g., "light", "bridge_home", "device"
}

/// Represents a Hue Light resource specifically
struct HueLight: Decodable {
    let id: String // UUID v1
    let owner: HueOwner? // Info about which device owns this resource (e.g., the light device itself)
    let metadata: HueMetadata?
    let on: HueOn? // On/Off state
    let dimming: HueDimming? // Brightness state
    let colorTemperature: HueColorTemperature? // Color temperature state
    let color: HueColor? // XY Color state
    let dynamics: HueDynamics? // For dynamic scenes/effects
    let alert: HueAlert? // Alert effect state
    let mode: String? // e.g., "normal"

    // Simplified mapping to AbstractDevice properties
    var name: String { metadata?.name ?? "Hue Light" }
    var modelId: String { metadata?.archetype ?? "unknown_archetype" } // Use archetype as model
}

struct HueOwner: Decodable {
    let rid: String
    let rtype: String // e.g., "device"
}

struct HueMetadata: Decodable {
    let name: String
    let archetype: String // e.g., "sultan_bulb", "hue_go", "lightstrip"
    // let fixed_mired: Int? // Might indicate tunable white only
}

struct HueOn: Decodable {
    let on: Bool
}

struct HueDimming: Decodable {
    let brightness: Double // Percentage 0-100
    // let min_dim_level: Double?
}

struct HueColorTemperature: Decodable {
    let mirek: Int? // Color temperature in Mirek scale (153-500)
    // let mirek_valid: Bool?
    // let mirek_schema: HueMirekSchema?
}

// struct HueMirekSchema: Decodable { let mirek_minimum: Int; let mirek_maximum: Int }

struct HueColor: Decodable {
    let xy: HueXyColor?
    // let gamut: HueGamut?
    // let gamut_type: String? // e.g., "C"
}

struct HueXyColor: Decodable {
    let x: Double
    let y: Double
}

// Other structs (HueDynamics, HueAlert, HueGamut etc.) can be added if needed

// MARK: - Hue API Payloads (for PUT requests)

struct HuePutOnPayload: Encodable {
    let on: HueOnPayload
}
struct HueOnPayload: Encodable {
    let on: Bool
}

struct HuePutDimmingPayload: Encodable {
    let dimming: HueDimmingPayload
}
struct HueDimmingPayload: Encodable {
    let brightness: Double // 0-100
}

struct HuePutColorTemperaturePayload: Encodable {
    let color_temperature: HueColorTemperaturePayload
}
struct HueColorTemperaturePayload: Encodable {
    let mirek: Int // 153-500
}

struct HuePutColorPayload: Encodable {
    let color: HueColorPayload
}
struct HueColorPayload: Encodable {
    let xy: HueXyColorPayload
}
struct HueXyColorPayload: Encodable {
    let x: Double
    let y: Double
}


// MARK: - HueLightAdapter Implementation

// TODO: Define Hue API specifics (Client ID/Secret for OAuth)
struct HueConfiguration {
    // Base URL for local CLIP API - requires bridge IP discovery
    // For simplicity, assume IP is known or handled by NetworkService construction
    static let localApiBasePath = "/clip/v2/resource"
    // TODO: Add remote API base URL (api.meethue.com) if needed
    // TODO: Add OAuth endpoints and client credentials
}

class HueLightAdapter: SmartDeviceAdapter {

    private let networkService: NetworkServiceProtocol // Assumed to handle base URL + Auth headers
    // private let tokenManager: HueTokenManager // TODO: Implement proper OAuth token management
    private var applicationKey: String? // Hue Application Key (username) obtained during pairing
    private var bearerToken: String?    // OAuth Bearer Token (primarily for remote API, but good practice)


    // TODO: Add rate limiting, retry logic if needed for Hue API

    // init(networkService: NetworkServiceProtocol, tokenManager: HueTokenManager) {
    init(networkService: NetworkServiceProtocol, applicationKey: String? = nil) { // App Key needed for local API
        self.networkService = networkService
        self.applicationKey = applicationKey
        // self.tokenManager = tokenManager
        // NOTE: NetworkService needs to be configured with the Bridge IP
        // and add 'hue-application-key' header with self.applicationKey
    }

    // MARK: - SmartDeviceAdapter Conformance

    func initialize(with authToken: String) throws {
        // For Hue, 'authToken' might represent the Bearer token for remote API,
        // or maybe the local applicationKey. Clarify usage.
        // Let's assume it's the Bearer token for now.
        self.bearerToken = authToken
        // TODO: If using remote API, validate token or perform initial setup
        print("HueLightAdapter initialized. Bearer token set (if applicable). Application Key: \\(applicationKey ?? "Not Set")")
    }

    func refreshAuthentication() async throws -> Bool {
        print("HueLightAdapter: refreshAuthentication() - Not Implemented")
        // TODO: Implement Hue OAuth token refresh logic using tokenManager
        // This is mainly needed for the remote API. Local API uses the persistent applicationKey.
        // guard let refreshed = try await tokenManager.refreshToken() else { return false }
        // self.bearerToken = refreshed.accessToken
        // return true
        throw SmartDeviceError.authenticationFailed("Refresh not implemented") // Placeholder
    }

    func fetchDevices() async throws -> [AbstractDevice] {
        print("HueLightAdapter: fetchDevices()")
        // Ensure we have the application key for local API calls
        guard applicationKey != nil else {
            print("Error: Hue Application Key not set for local API call.")
            throw SmartDeviceError.authenticationRequired("Missing Hue Application Key")
        }

        // Fetch all light resources
        let endpoint = HueConfiguration.localApiBasePath + "/light"
        
        do {
            let response: HueGetResponse<HueLight> = try await networkService.get(endpoint: endpoint)

            guard response.errors.isEmpty else {
                // TODO: Handle specific Hue errors
                print("Hue API Error fetching devices: \\(response.errors.first?.description ?? "Unknown error")")
                throw SmartDeviceError.apiError(response.errors.first?.description ?? "Unknown Hue API error")
            }

            // Map HueLight data to LightDevice
            return response.data.compactMap { mapHueLightToLightDevice($0) }

        } catch let error as SmartDeviceError {
            throw error // Re-throw known errors
        } catch {
            print("Error fetching Hue devices: \\(error)")
            throw SmartDeviceError.networkError(error.localizedDescription)
        }
    }

    func getDeviceState(deviceId: String) async throws -> AbstractDevice {
        print("HueLightAdapter: getDeviceState(deviceId: \\(deviceId))")
        guard applicationKey != nil else { throw SmartDeviceError.authenticationRequired("Missing Hue Application Key") }

        let endpoint = "\\(HueConfiguration.localApiBasePath)/light/\\(deviceId)"
        
        do {
            let response: HueGetResponse<HueLight> = try await networkService.get(endpoint: endpoint)

            guard response.errors.isEmpty else {
                // TODO: Handle specific Hue errors (e.g., device not found)
                 print("Hue API Error fetching state for \\(deviceId): \\(response.errors.first?.description ?? "Unknown error")")
                 throw SmartDeviceError.apiError(response.errors.first?.description ?? "Unknown Hue API error")
            }

            guard let hueLight = response.data.first else {
                throw SmartDeviceError.deviceNotFound(deviceId)
            }

            guard let lightDevice = mapHueLightToLightDevice(hueLight) else {
                throw SmartDeviceError.mappingError("Failed to map HueLight to LightDevice")
            }
            return lightDevice

        } catch let error as SmartDeviceError {
            throw error
        } catch {
            print("Error fetching Hue device state for \\(deviceId): \\(error)")
            throw SmartDeviceError.networkError(error.localizedDescription)
        }
    }

    func executeCommand(deviceId: String, command: DeviceCommand) async throws -> AbstractDevice {
        print("HueLightAdapter: executeCommand(deviceId: \\(deviceId), command: \\(command))")
        guard applicationKey != nil else { throw SmartDeviceError.authenticationRequired("Missing Hue Application Key") }

        let endpoint = "\\(HueConfiguration.localApiBasePath)/light/\\(deviceId)"
        
        // Prepare payload based on command
        let payload: Data
        do {
            payload = try encodeCommandPayload(command: command)
        } catch {
            throw error // Could be unsupported command or encoding error
        }

        // Make PUT request
        do {
             let response: HuePutResponse = try await networkService.put(endpoint: endpoint, body: payload)

             guard response.errors.isEmpty else {
                 print("Hue API Error executing command for \\(deviceId): \\(response.errors.first?.description ?? "Unknown error")")
                 throw SmartDeviceError.commandFailed(response.errors.first?.description ?? "Unknown Hue API error")
             }
             
             // Optional: Verify response.data contains the updated rid
             if let updatedRids = response.data, updatedRids.contains(where: { $0.rid == deviceId && $0.rtype == "light" }) {
                 print("Hue command successful for \\(deviceId).")
             } else {
                 print("Warning: Hue command response did not explicitly confirm update for \\(deviceId).")
                 // Might still have worked, proceed to fetch state.
             }

            // Fetch and return the updated state
            return try await getDeviceState(deviceId: deviceId)

        } catch let error as SmartDeviceError {
            throw error
        } catch {
            print("Error executing Hue command for \\(deviceId): \\(error)")
            throw SmartDeviceError.commandFailed(error.localizedDescription)
        }
    }

    func revokeAuthentication() async throws {
        print("HueLightAdapter: revokeAuthentication() - Not Implemented")
        // TODO: Implement Hue token revocation (remote API) or app key deletion (local API)
        // For local API, deleting the applicationKey requires a PUT to /clip/v2/resource/authkey/{applicationKey}
        self.bearerToken = nil
        // self.applicationKey = nil // Deleting key requires API call
    }

    // MARK: - Helper Methods (Private)

    /// Maps a HueLight API object to our internal LightDevice model
    private func mapHueLightToLightDevice(_ hueLight: HueLight) -> LightDevice? {
        let id = hueLight.id
        let name = hueLight.name
        // Room info isn't directly available in the light resource, might need separate query or default
        let room = "Unknown Room" // Placeholder
        let manufacturer = "Signify" // Philips Hue is owned by Signify
        let model = hueLight.modelId
        // Firmware version isn't directly in the /light resource, maybe in /device?
        let firmwareVersion = "Unknown" // Placeholder

        let isOn = hueLight.on?.on ?? false
        let brightness = hueLight.dimming?.brightness // Hue uses 0-100

        // Color mapping: Hue provides XY and Mirek. Our model uses HSB.
        // This requires conversion. For simplicity, check mirek first for white, then XY.
        var lightColor: LightColor? = nil
        let supportsDimming = hueLight.dimming != nil
        var supportsColor = false // Assume false unless color info present

        if let colorTemp = hueLight.colorTemperature, let mirek = colorTemp.mirek {
             supportsColor = true // Tunable white counts as color support
             // Convert Mirek to approximate HSB (simple approach: map mirek range to ~white hues/sats)
             // A more accurate conversion would use Kelvin -> RGB -> HSB
             let kelvin = 1_000_000 / mirek
             let hsb = kelvinToApproxHSB(kelvin: kelvin, brightness: brightness ?? 100.0)
             lightColor = LightColor(hue: hsb.hue, saturation: hsb.saturation, brightness: hsb.brightness)

        } else if let color = hueLight.color, let xy = color.xy {
            supportsColor = true
            // Convert XY to approximate HSB
            // This is complex and depends on the light's gamut. Using a standard conversion.
             let hsb = xyToApproxHSB(x: xy.x, y: xy.y, brightness: brightness ?? 100.0)
             lightColor = LightColor(hue: hsb.hue, saturation: hsb.saturation, brightness: hsb.brightness)
        }
        
        // isOnline: Hue API v2 doesn't have a direct 'reachable' boolean like v1.
        // We might infer online status if we successfully get state. Assume true for now.
        let isOnline = true

        return LightDevice(
            id: id,
            name: name,
            room: room,
            manufacturer: manufacturer,
            model: model,
            firmwareVersion: firmwareVersion,
            isOnline: isOnline,
            // lastSeen: // Not available directly
            // dateAdded: // Not available directly
            metadata: ["hue_archetype": hueLight.metadata?.archetype ?? ""], // Store archetype
            isOn: isOn,
            brightness: brightness,
            color: lightColor,
            supportsColor: supportsColor,
            supportsDimming: supportsDimming
        )
    }
    
    /// Encodes the DeviceCommand into a Hue JSON payload
    private func encodeCommandPayload(command: DeviceCommand) throws -> Data {
        let encoder = JSONEncoder()
        switch command {
        case .turnOn:
            return try encoder.encode(HuePutOnPayload(on: HueOnPayload(on: true)))
        case .turnOff:
            return try encoder.encode(HuePutOnPayload(on: HueOnPayload(on: false)))
        case .setBrightness(let level):
            // Ensure brightness is within Hue's 0-100 range
            let clampedLevel = max(0.0, min(100.0, level))
            // If setting brightness > 0, also ensure light is turned on
            // Hue API handles this implicitly in V2, setting brightness turns it on.
            // If setting brightness == 0, should we explicitly turn off? V2 might do this. Test needed.
            return try encoder.encode(HuePutDimmingPayload(dimming: HueDimmingPayload(brightness: clampedLevel)))
        case .setColor(let lightColor):
             // Convert our HSB LightColor to Hue's XY color space
             // This is complex and needs a proper color conversion library or approximation.
             // For now, let's try setting color temperature if saturation is low, otherwise skip color.
             // A better implementation would convert HSB -> RGB -> XY based on light gamut.
             if lightColor.saturation < 15 { // Arbitrary threshold for near-white
                 // Convert HSB brightness/temp to Mirek
                 if let mirek = hsbToApproxMirek(hue: lightColor.hue, saturation: lightColor.saturation) {
                     // Set brightness separately first? Or combine payloads? Hue PUT combines.
                     // Combine doesn't work directly with PUT /light/{id}. Need separate properties.
                     // Setting color temp implies 'on', brightness needs separate handling if needed.
                     // Let's just set color temp payload here. Brightness might need separate command.
                     print("Approximating HSB to Mirek: \\(mirek)")
                     return try encoder.encode(HuePutColorTemperaturePayload(color_temperature: HueColorTemperaturePayload(mirek: mirek)))
                 } else {
                     print("Cannot approximate HSB to Mirek, skipping color set.")
                     throw SmartDeviceError.commandNotSupported("Color set (HSB->Mirek) not implemented accurately")
                 }
             } else {
                 // Convert HSB to XY (Requires proper color science)
                 // Placeholder: Throw error until HSB->XY conversion is implemented
                  print("HSB -> XY conversion not implemented.")
                  throw SmartDeviceError.commandNotSupported("Color set (HSB->XY) not implemented")
                 
                 // Example if conversion existed:
                 // let xy = hsbToXy(hue: lightColor.hue, saturation: lightColor.saturation, brightness: lightColor.brightness)
                 // let payload = HuePutColorPayload(color: HueColorPayload(xy: HueXyColorPayload(x: xy.x, y: xy.y)))
                 // return try encoder.encode(payload)
             }
        
        // Handle other commands if necessary, or throw unsupported
        default:
            throw SmartDeviceError.commandNotSupported(String(describing: command))
        }
    }

    // MARK: - Color Conversion Helpers (Approximations - NEED IMPROVEMENT)

    // Basic approximation: Kelvin to HSB (Assumes D65 white point for conversion)
    // Ignores gamut limitations. Brightness passed through. Saturation is low for white.
    private func kelvinToApproxHSB(kelvin: Int, brightness: Double) -> (hue: Double, saturation: Double, brightness: Double) {
        // Very rough mapping - cooler temps slightly blue, warmer slightly yellow/orange
        let temp = Double(max(2000, min(6500, kelvin))) // Clamp to reasonable range
        var hue: Double = 0
        var saturation: Double = 0

        if temp < 4000 { // Warmer
            hue = 30 + (4000 - temp) / 2000 * 30 // Map 4000K->30deg, 2000K->60deg (Orange/Yellow)
            saturation = 30 + (4000 - temp) / 2000 * 40 // Increase saturation for warmer
        } else { // Cooler
             hue = 240 - (temp - 4000) / 2500 * 60 // Map 4000K->240deg, 6500K->180deg (Blue/Cyan)
             saturation = 20 + (temp - 4000) / 2500 * 30 // Lower saturation for cooler, but not zero
        }
        return (hue: hue, saturation: saturation, brightness: brightness)
    }
    
    // Basic approximation: Near-white HSB to Mirek
    private func hsbToApproxMirek(hue: Double, saturation: Double) -> Int? {
         guard saturation < 25 else { return nil } // Only attempt for low saturation colors
         
         // Very rough mapping based on hue (assuming low saturation)
         var kelvin: Double
         if (hue >= 0 && hue <= 60) || hue > 300 { // Reds/Oranges/Yellows -> Warm
             kelvin = 2500 + (60 - abs(hue - 30)) / 60 * 1500 // ~2500K - 4000K
         } else if hue > 180 && hue <= 270 { // Blues/Cyans -> Cool
             kelvin = 5000 + (hue - 180) / 90 * 1500 // ~5000K - 6500K
         } else { // Greens/Magentas -> Mid-range (less likely for white)
             kelvin = 4500
         }
         
         return Int(1_000_000 / kelvin)
    }

    // Basic approximation: XY to HSB (Assumes sRGB gamut, ignores brightness ('Y') component of XYZ)
    // Requires a proper color science library for accuracy.
    private func xyToApproxHSB(x: Double, y: Double, brightness: Double) -> (hue: Double, saturation: Double, brightness: Double) {
        // 1. Convert xyY to XYZ (Assume Y = brightness/100 for simplicity, NOT accurate)
        let Y = brightness / 100.0
        let X = (Y / y) * x
        let Z = (Y / y) * (1.0 - x - y)

        // 2. Convert XYZ to Linear sRGB (using standard matrices, requires inversion)
        // Matrix for sRGB primaries (approximation)
        let r_lin = X *  3.2406 + Y * -1.5372 + Z * -0.4986
        let g_lin = X * -0.9689 + Y *  1.8758 + Z *  0.0415
        let b_lin = X *  0.0557 + Y * -0.2040 + Z *  1.0570
        
        // 3. Gamma correction (Linear sRGB to sRGB)
        func gammaCorrect(_ c: Double) -> Double {
             return (c <= 0.0031308) ? (12.92 * c) : (1.055 * pow(c, 1.0/2.4) - 0.055)
        }
        let r = gammaCorrect(r_lin) * 255.0
        let g = gammaCorrect(g_lin) * 255.0
        let b = gammaCorrect(b_lin) * 255.0
        
        // Clamp to 0-255
        let r_int = max(0, min(255, Int(r.rounded())))
        let g_int = max(0, min(255, Int(g.rounded())))
        let b_int = max(0, min(255, Int(b.rounded())))

        // 4. Convert RGB to HSB (using existing LightColor logic)
        let lightColor = LightColor.fromRGB(red: r_int, green: g_int, blue: b_int)
        
        // Return HSB, but keep original brightness if possible (RGB->HSB brightness might differ)
        return (hue: lightColor.hue, saturation: lightColor.saturation, brightness: brightness)
    }
}

// MARK: - SmartDeviceError Extension (Optional)
// Add Hue-specific cases if needed, e.g., bridge errors
extension SmartDeviceError {
    // case hueBridgeError(String)
    // case hueResourceNotFound(String)
} 