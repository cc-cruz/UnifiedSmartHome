import Foundation
import Combine

/// Configuration for SmartThings API
struct SmartThingsConfiguration {
    static let shared = SmartThingsConfiguration()
    
    let apiKey: String
    let baseURL: String
    
    private init() {
        // Load from environment variables or secure configuration
        self.apiKey = ProcessInfo.processInfo.environment["SMARTTHINGS_API_KEY"] ?? ""
        self.baseURL = ProcessInfo.processInfo.environment["SMARTTHINGS_BASE_URL"] ?? "https://api.smartthings.com/v1"
        
        guard !apiKey.isEmpty else {
            fatalError("SmartThings configuration is incomplete. Please set the required environment variables.")
        }
    }
}

/// A concrete implementation of the `SmartDeviceAdapter` protocol for Samsung SmartThings devices.
class SmartThingsAdapter: SmartDeviceAdapter {
    
    // MARK: - Properties
    
    private var authToken: String?
    private let baseURL = SmartThingsConfiguration.shared.baseURL
    
    private let networkService: NetworkServiceProtocol
    private let tokenManager: SmartThingsTokenManager
    private let securityService: SecurityServiceProtocol
    private let auditLogger: AuditLoggerProtocol
    
    // Security / certificate pinning
    private let pinnedCertificates: Set<Data>
    
    // Rate limiting
    private var lastRequestTime: Date?
    private var minRequestInterval: TimeInterval = 0.5  // 500ms by default
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelayBase: TimeInterval = 2.0
    
    // MARK: - Initializer
    
    init(networkService: NetworkServiceProtocol = NetworkService(),
         securityService: SecurityServiceProtocol,
         auditLogger: AuditLoggerProtocol) {
        
        self.networkService = networkService
        self.securityService = securityService
        self.auditLogger = auditLogger
        
        // Token manager is responsible for OAuth2 token lifecycle
        self.tokenManager = SmartThingsTokenManager(
            networkService: networkService,
            baseURL: SmartThingsConfiguration.shared.baseURL
        )
        
        // Certificate pinning setup
        self.pinnedCertificates = initializePinnedCertificates()
    }
    
    // MARK: - SmartDeviceAdapter Protocol Methods
    
    /// Initializes the adapter with a valid auth token (if needed).
    func initializeConnection(authToken: String) throws {
        self.authToken = authToken
    }
    
    /// Fetches a list of devices (in abstract form) from the SmartThings API.
    func fetchDevices() async throws -> [AbstractDevice] {
        // Rate limiting check
        try await enforceRateLimits()
        
        do {
            let token = try await tokenManager.getValidToken()
            
            // Log the operation attempt
            auditLogger.logEvent(
                type: .deviceOperation,
                action: "fetch_devices",
                status: .started,
                details: ["adapter": "smartthings"]
            )
            
            // Make the network request
            let response: SmartThingsDevicesResponse = try await networkService.authenticatedGet(
                endpoint: "\(baseURL)/devices",
                token: token
            )
            
            // Log success
            auditLogger.logEvent(
                type: .deviceOperation,
                action: "fetch_devices",
                status: .success,
                details: ["adapter": "smartthings", "count": response.items.count]
            )
            
            return mapDevices(response.items)
            
        } catch {
            handleAndLogError(error, action: "fetch_devices")
            throw error
        }
    }
    
    /// Fetches the detailed status for a specific device by its ID.
    func getDeviceStatus(id: String) async throws -> AbstractDevice {
        // Rate limiting check
        try await enforceRateLimits()
        
        do {
            let token = try await tokenManager.getValidToken()
            
            let response: SmartThingsDeviceStatusResponse = try await networkService.authenticatedGet(
                endpoint: "\(baseURL)/devices/\(id)/status",
                token: token
            )
            
            return mapDeviceStatus(id, response)
            
        } catch {
            handleAndLogError(error, action: "get_device_status")
            throw error
        }
    }
    
    /// Updates a device's state via the SmartThings API.
    func updateDeviceState(deviceId: String, newState: DeviceState) async throws -> DeviceState {
        // First, get the current device to determine its type
        let device = try await getDeviceStatus(deviceId: deviceId)
        
        // Determine what kind of command to send based on device type and state changes
        let command = createCommandFromState(device: device, newState: newState)
        
        // Execute the command
        let updatedDevice = try await executeCommand(device: device, command: command)
        
        // Map the updated device back to a DeviceState
        return DeviceState(
            isOnline: updatedDevice.status == .online,
            attributes: mapDeviceToAttributes(updatedDevice)
        )
    }
    
    /// Executes a command on a device
    /// - Parameters:
    ///   - command: The command to execute
    ///   - device: The device to execute the command on
    /// - Returns: Updated device state after command execution
    func executeCommand(_ command: DeviceCommand, on device: AbstractDevice) async throws -> AbstractDevice {
        guard let deviceId = device.id else {
            throw DeviceOperationError.invalidDeviceId
        }
        
        // Validate auth state
        guard let token = self.authToken, !token.isEmpty else {
            throw DeviceOperationError.authenticationRequired
        }
        
        // Log attempt
        auditLogger.logEvent(
            category: .deviceControl,
            action: .executeCommand,
            metadata: [
                "deviceId": deviceId,
                "command": command.description,
                "timestamp": Date().ISO8601Format()
            ]
        )
        
        // Rate limiting check
        if !rateLimiter.canPerformAction(for: deviceId) {
            auditLogger.logEvent(
                category: .security,
                action: .rateLimitExceeded,
                metadata: [
                    "deviceId": deviceId,
                    "command": command.description,
                    "timestamp": Date().ISO8601Format()
                ]
            )
            throw DeviceOperationError.rateLimitExceeded
        }
        
        // Prepare command parameters
        var component: String = ""
        var capability: String = ""
        var command: String = ""
        var arguments: [String: Any] = [:]
        
        // Map device command to SmartThings command
        switch device {
        case let lightDevice as LightDevice:
            return try await executeCommandForLight(command, on: lightDevice)
            
        case let switchDevice as SwitchDevice:
            return try await executeCommandForSwitch(command, on: switchDevice)
            
        case let thermostatDevice as ThermostatDevice:
            return try await executeCommandForThermostat(command, on: thermostatDevice)
            
        case let lockDevice as LockDevice:
            return try await executeCommandForLock(command, on: lockDevice)
            
        default:
            throw DeviceOperationError.unsupportedDeviceType
        }
    }
    
    /// Fetches the detailed status for a specific device by its ID.
    func getDeviceStatus(deviceId: String) async throws -> AbstractDevice {
        return try await getDeviceStatus(id: deviceId)
    }
    
    // MARK: - Internal Helpers
    
    /// Enforces a minimum request interval to help with rate-limiting.
    private func enforceRateLimits() async throws {
        guard let lastRequest = lastRequestTime else {
            lastRequestTime = Date()
            return
        }
        
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
        if timeSinceLastRequest < minRequestInterval {
            let waitTime = minRequestInterval - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
    
    /// Validates whether we can proceed with a security-critical operation.
    private func validateCommandSecurity(device: AbstractDevice, command: DeviceCommand) async throws {
        // Check if operation is security-critical (e.g., unlocking a door)
        if device is LockDevice && command == .unlock {
            // Require biometric authentication
            try await securityService.authenticateAndPerform("Authenticate to unlock") {
                // Then check if the device is jailbroken
                try await securityService.secureCriticalOperation {
                    // Additional security checks can be placed here if needed
                }
            }
        } else {
            // For non-critical operations, still perform some checks
            try await securityService.secureCriticalOperation { }
        }
    }
    
    /// Creates a command from a device state update.
    private func createCommandFromState(device: AbstractDevice, newState: DeviceState) -> DeviceCommand {
        // Extract attributes from the new state
        let attributes = newState.attributes
        
        if let lockDevice = device as? LockDevice {
            // Check if there's a lock state change
            if let lockState = attributes["lockState"]?.value as? String {
                return lockState == "locked" ? .lock : .unlock
            }
        }
        else if let thermostatDevice = device as? ThermostatDevice {
            // Check if there's a temperature change
            if let targetTemp = attributes["targetTemperature"]?.value as? Double {
                return .setTemperature(targetTemp)
            }
            // Check if there's a mode change
            else if let modeString = attributes["mode"]?.value as? String,
                    let mode = ThermostatMode(rawValue: modeString) {
                return .setMode(mode)
            }
        }
        else if let lightDevice = device as? LightDevice {
            // Check if there's an on/off change
            if let isOn = attributes["isOn"]?.value as? Bool {
                return isOn ? .turnOn : .turnOff
            }
            // Check if there's a brightness change
            else if let brightness = attributes["brightness"]?.value as? Int {
                return .setBrightness(brightness)
            }
            // Check if there's a color change
            else if let hue = attributes["hue"]?.value as? Double,
                    let saturation = attributes["saturation"]?.value as? Double,
                    let brightness = attributes["brightness"]?.value as? Double {
                let color = LightColor(hue: hue, saturation: saturation, brightness: brightness)
                return .setColor(color)
            }
        }
        else if let switchDevice = device as? SwitchDevice {
            // Check if there's an on/off change
            if let isOn = attributes["isOn"]?.value as? Bool {
                return .setSwitch(isOn)
            }
        }
        
        // Default - no recognized command
        fatalError("Unable to determine command from state update for device: \(device.id)")
    }
    
    /// Creates the HTTP body for sending a specific command to a device.
    private func createCommandBody(device: AbstractDevice, command: DeviceCommand) -> [String: Any] {
        var commandBody: [String: Any] = ["commands": []]
        var commands: [[String: Any]] = []
        
        if let lockDevice = device as? LockDevice {
            // Lock-related commands
            switch command {
            case .lock:
                commands.append([
                    "component": "main",
                    "capability": "lock",
                    "command": "lock"
                ])
            case .unlock:
                commands.append([
                    "component": "main",
                    "capability": "lock",
                    "command": "unlock"
                ])
            default:
                break
            }
        }
        else if let thermostatDevice = device as? ThermostatDevice {
            // Thermostat-related commands
            if case .setTemperature(let temperature) = command {
                commands.append([
                    "component": "main",
                    "capability": "thermostatHeatingSetpoint",
                    "command": "setHeatingSetpoint",
                    "arguments": [temperature]
                ])
            }
            else if case .setMode(let mode) = command {
                commands.append([
                    "component": "main",
                    "capability": "thermostatMode",
                    "command": "setThermostatMode",
                    "arguments": [mode.rawValue]
                ])
            }
        }
        else if let lightDevice = device as? LightDevice {
            // Light-related commands
            switch command {
            case .turnOn:
                commands.append([
                    "component": "main",
                    "capability": "switch",
                    "command": "on"
                ])
            case .turnOff:
                commands.append([
                    "component": "main",
                    "capability": "switch",
                    "command": "off"
                ])
            case .setBrightness(let brightness):
                commands.append([
                    "component": "main",
                    "capability": "switchLevel",
                    "command": "setLevel",
                    "arguments": [brightness]
                ])
            case .setColor(let color):
                commands.append([
                    "component": "main",
                    "capability": "colorControl",
                    "command": "setColor",
                    "arguments": [["hue": color.hue, "saturation": color.saturation]]
                ])
            default:
                break
            }
        }
        else if let switchDevice = device as? SwitchDevice {
            // Switch-related commands
            if case .setSwitch(let isOn) = command {
                commands.append([
                    "component": "main",
                    "capability": "switch",
                    "command": isOn ? "on" : "off"
                ])
            }
        }
        
        commandBody["commands"] = commands
        return commandBody
    }
    
    /// Maps a device to a DeviceState with attributes.
    private func mapDeviceToAttributes(_ device: AbstractDevice) -> [String: AnyCodable] {
        var attributes: [String: AnyCodable] = [:]
        
        if let lockDevice = device as? LockDevice {
            // Map lock device attributes
            attributes["lockState"] = AnyCodable(lockDevice.currentState.rawValue)
            if let batteryLevel = lockDevice.batteryLevel {
                attributes["batteryLevel"] = AnyCodable(batteryLevel)
            }
        }
        else if let thermostatDevice = device as? ThermostatDevice {
            // Map thermostat device attributes
            if let currentTemp = thermostatDevice.currentTemperature {
                attributes["currentTemperature"] = AnyCodable(currentTemp)
            }
            if let targetTemp = thermostatDevice.targetTemperature {
                attributes["targetTemperature"] = AnyCodable(targetTemp)
            }
            if let mode = thermostatDevice.mode {
                attributes["mode"] = AnyCodable(mode.rawValue)
            }
            if let humidity = thermostatDevice.humidity {
                attributes["humidity"] = AnyCodable(humidity)
            }
            attributes["isHeating"] = AnyCodable(thermostatDevice.isHeating)
            attributes["isCooling"] = AnyCodable(thermostatDevice.isCooling)
            attributes["isFanRunning"] = AnyCodable(thermostatDevice.isFanRunning)
        }
        else if let lightDevice = device as? LightDevice {
            // Map light device attributes
            attributes["isOn"] = AnyCodable(lightDevice.isOn)
            if let brightness = lightDevice.brightness {
                attributes["brightness"] = AnyCodable(brightness)
            }
            if let color = lightDevice.color {
                attributes["hue"] = AnyCodable(color.hue)
                attributes["saturation"] = AnyCodable(color.saturation)
                attributes["brightness"] = AnyCodable(color.brightness)
            }
        }
        else if let switchDevice = device as? SwitchDevice {
            // Map switch device attributes
            attributes["isOn"] = AnyCodable(switchDevice.isOn)
        }
        
        return attributes
    }
    
    /// Verifies that the device state changed as expected after a command.
    private func verifyStateChange(device: AbstractDevice, command: DeviceCommand) async throws {
        // Add a small delay to allow SmartThings cloud to update status
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let updatedDevice = try await getDeviceStatus(id: device.id)
        
        // Example for locks:
        if let originalLock = device as? LockDevice,
           let updatedLock = updatedDevice as? LockDevice {
            
            switch command {
            case .lock:
                if updatedLock.currentState != .locked {
                    throw DeviceOperationError.stateVerificationFailed("Lock state verification failed")
                }
            case .unlock:
                if updatedLock.currentState != .unlocked {
                    throw DeviceOperationError.stateVerificationFailed("Unlock state verification failed")
                }
            default:
                break
            }
        }
        // Check lights
        else if let originalLight = device as? LightDevice,
                let updatedLight = updatedDevice as? LightDevice {
            
            switch command {
            case .turnOn:
                if !updatedLight.isOn {
                    throw DeviceOperationError.stateVerificationFailed("Light on state verification failed")
                }
            case .turnOff:
                if updatedLight.isOn {
                    throw DeviceOperationError.stateVerificationFailed("Light off state verification failed")
                }
            case .setBrightness(let brightness):
                if updatedLight.brightness != brightness {
                    throw DeviceOperationError.stateVerificationFailed("Light brightness verification failed")
                }
            default:
                break
            }
        }
        // Check thermostats
        else if let originalThermostat = device as? ThermostatDevice,
                let updatedThermostat = updatedDevice as? ThermostatDevice {
            
            switch command {
            case .setTemperature(let temperature):
                if updatedThermostat.targetTemperature != temperature {
                    throw DeviceOperationError.stateVerificationFailed("Temperature verification failed")
                }
            case .setMode(let mode):
                if updatedThermostat.mode != mode {
                    throw DeviceOperationError.stateVerificationFailed("Thermostat mode verification failed")
                }
            default:
                break
            }
        }
        // Check switches
        else if let originalSwitch = device as? SwitchDevice,
                let updatedSwitch = updatedDevice as? SwitchDevice {
            
            if case .setSwitch(let isOn) = command, updatedSwitch.isOn != isOn {
                throw DeviceOperationError.stateVerificationFailed("Switch state verification failed")
            }
        }
    }
    
    /// Maps a list of SmartThings devices to our internal abstract device models.
    private func mapDevices(_ devices: [SmartThingsDevice]) -> [AbstractDevice] {
        return devices.compactMap { device in
            let capabilities = device.components.flatMap { $0.capabilities.map { $0.id } }
            
            // Identify device type by capabilities
            if capabilities.contains("lock") {
                return createLockDevice(device)
            } else if capabilities.contains("thermostatMode") || capabilities.contains("temperatureMeasurement") {
                return createThermostatDevice(device)
            } else if capabilities.contains("switch") {
                // Could be a light or a simple switch
                if capabilities.contains("colorControl") || capabilities.contains("colorTemperature") {
                    return createLightDevice(device)
                } else {
                    return createSwitchDevice(device)
                }
            } else {
                // Default to a generic device if not recognized
                return createGenericDevice(device)
            }
        }
    }
    
    /// Maps a specific device's status to our AbstractDevice model with updated fields.
    private func mapDeviceStatus(_ id: String, _ statusResponse: SmartThingsDeviceStatusResponse) -> AbstractDevice {
        // For example, if this device is a lock, parse the "lock" attribute:
        // The logic here will mirror the approach from `mapDevices` but with actual status values.
        // If no recognized capability is found, return a generic device with partial data.
        
        // This snippet is an example for locks:
        if let lockAttribute = statusResponse.components["main"]?["lock"]?["lock"]?.value.stringValue {
            // It's a lock device
            let device = LockDevice(
                id: id,
                name: "SmartThings Lock",
                room: "Unknown",
                manufacturer: "SmartThings",
                model: "Lock Model",
                firmwareVersion: "Unknown",
                isOnline: true,
                lastSeen: Date(),
                dateAdded: Date(),
                metadata: [:],
                currentState: lockAttribute == "locked" ? .locked : .unlocked,
                batteryLevel: 100, // Could be updated from battery capability if available
                lastStateChange: nil,
                isRemoteOperationEnabled: true,
                accessHistory: []
            )
            return device
        }
        
        // Check for thermostat
        if let tempAttribute = statusResponse.components["main"]?["temperatureMeasurement"]?["temperature"]?.value.doubleValue {
            let targetTemp = statusResponse.components["main"]?["thermostatHeatingSetpoint"]?["heatingSetpoint"]?.value.doubleValue
            
            let device = ThermostatDevice(
                id: id,
                name: "SmartThings Thermostat",
                room: "Unknown",
                manufacturer: "SmartThings",
                model: "Thermostat Model",
                firmwareVersion: "Unknown",
                isOnline: true,
                lastSeen: Date(),
                dateAdded: Date(),
                metadata: [:],
                currentTemperature: tempAttribute,
                targetTemperature: targetTemp
            )
            return device
        }
        
        // Check for light
        if let switchAttribute = statusResponse.components["main"]?["switch"]?["switch"]?.value.stringValue {
            let isOn = switchAttribute == "on"
            
            // Check if it's a color light
            let brightness = statusResponse.components["main"]?["switchLevel"]?["level"]?.value.intValue
            
            // Check if it has color capabilities
            var color: LightColor? = nil
            if let hue = statusResponse.components["main"]?["colorControl"]?["hue"]?.value.doubleValue,
               let saturation = statusResponse.components["main"]?["colorControl"]?["saturation"]?.value.doubleValue {
                color = LightColor(hue: hue, saturation: saturation, brightness: Double(brightness ?? 100))
            }
            
            // If it has color capabilities, it's a light
            if color != nil || brightness != nil {
                let device = LightDevice(
                    id: id,
                    name: "SmartThings Light",
                    room: "Unknown",
                    manufacturer: "SmartThings",
                    model: "Light Model",
                    firmwareVersion: "Unknown",
                    isOnline: true,
                    lastSeen: Date(),
                    dateAdded: Date(),
                    metadata: [:],
                    brightness: brightness,
                    color: color,
                    isOn: isOn
                )
                return device
            }
            
            // It's a basic switch
            let device = SwitchDevice(
                id: id,
                name: "SmartThings Switch",
                room: "Unknown",
                manufacturer: "SmartThings",
                model: "Switch Model",
                firmwareVersion: "Unknown",
                isOnline: true,
                lastSeen: Date(),
                dateAdded: Date(),
                metadata: [:],
                isOn: isOn
            )
            return device
        }
        
        // Implement similar logic for thermostats, lights, sensors, etc.
        return GenericDevice(
            id: id,
            name: "Unrecognized SmartThings Device",
            isOnline: true,
            manufacturer: "SmartThings",
            model: "Unknown",
            firmwareVersion: "Unknown",
            dateAdded: Date(),
            lastSeen: Date(),
            metadata: [:]
        )
    }
    
    /// Creates a lock device from a SmartThingsDevice object (without real-time status).
    private func createLockDevice(_ device: SmartThingsDevice) -> LockDevice {
        return LockDevice(
            id: device.deviceId,
            name: device.label ?? device.name,
            room: device.roomId ?? "Unknown",
            manufacturer: "SmartThings",
            model: device.type,
            firmwareVersion: "Unknown",
            isOnline: true,
            lastSeen: Date(),
            dateAdded: Date(),
            metadata: [:],
            currentState: .unknown,
            batteryLevel: nil,
            lastStateChange: nil,
            isRemoteOperationEnabled: true,
            accessHistory: []
        )
    }
    
    /// Creates a thermostat device from a SmartThingsDevice object.
    private func createThermostatDevice(_ device: SmartThingsDevice) -> ThermostatDevice {
        return ThermostatDevice(
            id: device.deviceId,
            name: device.label ?? device.name,
            room: device.roomId ?? "Unknown",
            manufacturer: "SmartThings",
            model: device.type,
            firmwareVersion: "Unknown",
            isOnline: true,
            lastSeen: Date(),
            dateAdded: Date(),
            metadata: [:],
            currentTemperature: nil,
            targetTemperature: nil
        )
    }
    
    /// Creates a light device from a SmartThingsDevice object.
    private func createLightDevice(_ device: SmartThingsDevice) -> LightDevice {
        return LightDevice(
            id: device.deviceId,
            name: device.label ?? device.name,
            room: device.roomId ?? "Unknown",
            manufacturer: "SmartThings",
            model: device.type,
            firmwareVersion: "Unknown",
            isOnline: true,
            lastSeen: Date(),
            dateAdded: Date(),
            metadata: [:],
            brightness: nil,
            color: nil,
            isOn: false
        )
    }
    
    /// Creates a basic switch device from a SmartThingsDevice object.
    private func createSwitchDevice(_ device: SmartThingsDevice) -> SwitchDevice {
        return SwitchDevice(
            id: device.deviceId,
            name: device.label ?? device.name,
            room: device.roomId ?? "Unknown",
            manufacturer: "SmartThings",
            model: device.type,
            firmwareVersion: "Unknown",
            isOnline: true,
            lastSeen: Date(),
            dateAdded: Date(),
            metadata: [:],
            isOn: false
        )
    }
    
    /// Creates a generic device from a SmartThingsDevice object.
    private func createGenericDevice(_ device: SmartThingsDevice) -> GenericDevice {
        return GenericDevice(
            id: device.deviceId,
            name: device.label ?? device.name,
            isOnline: true,
            manufacturer: "SmartThings",
            model: device.type,
            firmwareVersion: "Unknown",
            dateAdded: Date(),
            lastSeen: Date(),
            metadata: [:]
        )
    }
    
    // MARK: - Security & Certificate Pinning
    
    private func validateCertificate(_ serverTrust: SecTrust) -> Bool {
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            return false
        }
        let serverCertificateData = SecCertificateCopyData(serverCertificate) as Data
        return pinnedCertificates.contains(serverCertificateData)
    }
    
    private func initializePinnedCertificates() -> Set<Data> {
        let bundle = Bundle.main
        let certificateNames = ["smartthings-cert-1", "smartthings-cert-2"]
        
        return Set(certificateNames.compactMap { name in
            guard
                let path = bundle.path(forResource: name, ofType: "cer"),
                let data = try? Data(contentsOf: URL(fileURLWithPath: path))
            else {
                return nil
            }
            return data
        })
    }
    
    // MARK: - Error Handling
    
    /// Logs errors and maps them to known error types.
    private func handleAndLogError(_ error: Error, action: String) {
        let sanitizedError = sanitizeError(error)
        
        auditLogger.logEvent(
            type: .deviceOperation,
            action: action,
            status: .failed,
            details: [
                "adapter": "smartthings",
                "error": sanitizedError
            ]
        )
    }
    
    private func sanitizeError(_ error: Error) -> String {
        let errorString = error.localizedDescription
        // Example regex to remove email addresses or other sensitive data:
        return errorString.replacingOccurrences(
            of: #"([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})"#,
            with: "[REDACTED]",
            options: .regularExpression
        )
    }
    
    // MARK: - Command Execution Helpers
    
    /// Executes a command on a light device
    private func executeCommandForLight(_ command: DeviceCommand, on device: LightDevice) async throws -> AbstractDevice {
        let deviceCopy = device.copy()
        
        switch command.name {
        case "turnOn":
            deviceCopy.isOn = true
            try await sendDeviceCommand(deviceId: device.id, capability: "switch", command: "on")
            
        case "turnOff":
            deviceCopy.isOn = false
            try await sendDeviceCommand(deviceId: device.id, capability: "switch", command: "off")
            
        case "setBrightness":
            guard let brightness = command.parameters["brightness"] as? Int else {
                throw DeviceOperationError.invalidCommandParameters
            }
            
            let validBrightness = min(100, max(0, brightness))
            deviceCopy.brightness = validBrightness
            try await sendDeviceCommand(
                deviceId: device.id,
                capability: "switchLevel",
                command: "setLevel",
                arguments: [validBrightness]
            )
            
        case "setColor":
            guard let hex = command.parameters["color"] as? String else {
                throw DeviceOperationError.invalidCommandParameters
            }
            
            deviceCopy.color = hex
            try await sendDeviceCommand(
                deviceId: device.id,
                capability: "colorControl",
                command: "setColor",
                arguments: [["hex": hex]]
            )
            
        default:
            throw DeviceOperationError.unsupportedCommand
        }
        
        return deviceCopy
    }
    
    /// Executes a command on a switch device
    private func executeCommandForSwitch(_ command: DeviceCommand, on device: SwitchDevice) async throws -> AbstractDevice {
        let deviceCopy = device.copy()
        
        switch command.name {
        case "turnOn":
            deviceCopy.isOn = true
            try await sendDeviceCommand(deviceId: device.id, capability: "switch", command: "on")
            
        case "turnOff":
            deviceCopy.isOn = false
            try await sendDeviceCommand(deviceId: device.id, capability: "switch", command: "off")
            
        default:
            throw DeviceOperationError.unsupportedCommand
        }
        
        return deviceCopy
    }
    
    /// Executes a command on a thermostat device
    private func executeCommandForThermostat(_ command: DeviceCommand, on device: ThermostatDevice) async throws -> AbstractDevice {
        let deviceCopy = device.copy()
        
        switch command.name {
        case "setTargetTemperature":
            guard let temperature = command.parameters["temperature"] as? Double else {
                throw DeviceOperationError.invalidCommandParameters
            }
            
            deviceCopy.targetTemperature = temperature
            try await sendDeviceCommand(
                deviceId: device.id,
                capability: "thermostatCoolingSetpoint",
                command: "setCoolingSetpoint",
                arguments: [temperature]
            )
            
        case "setMode":
            guard let modeStr = command.parameters["mode"] as? String,
                  let mode = ThermostatMode(rawValue: modeStr) else {
                throw DeviceOperationError.invalidCommandParameters
            }
            
            deviceCopy.mode = mode
            try await sendDeviceCommand(
                deviceId: device.id,
                capability: "thermostatMode",
                command: "setThermostatMode",
                arguments: [mode.rawValue]
            )
            
        case "setFanMode":
            guard let modeStr = command.parameters["mode"] as? String,
                  let mode = ThermostatFanMode(rawValue: modeStr) else {
                throw DeviceOperationError.invalidCommandParameters
            }
            
            deviceCopy.fanMode = mode
            try await sendDeviceCommand(
                deviceId: device.id,
                capability: "thermostatFanMode",
                command: "setThermostatFanMode",
                arguments: [mode.rawValue]
            )
            
        default:
            throw DeviceOperationError.unsupportedCommand
        }
        
        return deviceCopy
    }
    
    /// Executes a command on a lock device
    private func executeCommandForLock(_ command: DeviceCommand, on device: LockDevice) async throws -> AbstractDevice {
        let deviceCopy = device.copy()
        
        switch command.name {
        case "lock":
            deviceCopy.currentState = .locked
            deviceCopy.lastStateChange = Date()
            
            // Get authenticated user ID for the access record
            guard let userId = securityService.getCurrentUserId() else {
                throw DeviceOperationError.authenticationRequired
            }
            
            let record = LockDevice.LockAccessRecord(
                timestamp: Date(),
                operation: .lock,
                userId: userId,
                success: true
            )
            deviceCopy.accessHistory.append(record)
            
            try await sendDeviceCommand(deviceId: device.id, capability: "lock", command: "lock")
            
        case "unlock":
            // Verify biometric authentication for unlock commands
            try await securityService.verifyBiometricAuthentication(reason: "Unlock door")
            
            deviceCopy.currentState = .unlocked
            deviceCopy.lastStateChange = Date()
            
            // Get authenticated user ID for the access record
            guard let userId = securityService.getCurrentUserId() else {
                throw DeviceOperationError.authenticationRequired
            }
            
            let record = LockDevice.LockAccessRecord(
                timestamp: Date(),
                operation: .unlock,
                userId: userId,
                success: true
            )
            deviceCopy.accessHistory.append(record)
            
            try await sendDeviceCommand(deviceId: device.id, capability: "lock", command: "unlock")
            
        default:
            throw DeviceOperationError.unsupportedCommand
        }
        
        return deviceCopy
    }
    
    /// Sends a command to a SmartThings device
    private func sendDeviceCommand(deviceId: String, capability: String, command: String, arguments: [Any] = []) async throws {
        let endpoint = "\(baseURL)/devices/\(deviceId)/commands"
        
        let commandBody: [String: Any] = [
            "commands": [
                [
                    "component": "main",
                    "capability": capability,
                    "command": command,
                    "arguments": arguments
                ]
            ]
        ]
        
        guard let requestData = try? JSONSerialization.data(withJSONObject: commandBody) else {
            throw DeviceOperationError.invalidCommandParameters
        }
        
        guard let token = authToken else {
            throw DeviceOperationError.authenticationRequired
        }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Rate limiting - record this action
        rateLimiter.recordAction(for: deviceId)
        
        // Execute network request
        let (_, response) = try await URLSession.shared.data(for: request)
        
        // Check response status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeviceOperationError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200, 201, 204:
            return // Success
        case 401, 403:
            throw DeviceOperationError.authenticationError
        case 404:
            throw DeviceOperationError.deviceNotFound
        case 429:
            throw DeviceOperationError.rateLimitExceeded
        default:
            throw DeviceOperationError.serverError(statusCode: httpResponse.statusCode)
        }
    }
} 