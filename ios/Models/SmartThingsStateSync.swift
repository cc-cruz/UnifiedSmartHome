import Foundation
import Combine

/// Manages device state synchronization for SmartThings devices
public class SmartThingsStateSync {
    public static let shared = SmartThingsStateSync()
    private let logger = SmartThingsLogger.shared
    private let metrics = SmartThingsMetrics.shared
    
    private var syncTimer: Timer?
    private var deviceStates: [String: DeviceState] = [:]
    private var stateSubscribers: [String: [AnyCancellable]] = [:]
    
    private init() {
        setupSyncTimer()
    }
    
    // MARK: - Public Methods
    
    /// Starts state synchronization for a device
    /// - Parameters:
    ///   - deviceId: The ID of the device to sync
    ///   - deviceType: The type of device
    ///   - initialState: The initial state of the device
    public func startSync(deviceId: String, deviceType: DeviceType, initialState: DeviceState) {
        deviceStates[deviceId] = initialState
        setupDeviceSubscribers(deviceId: deviceId, deviceType: deviceType)
        
        logger.logInfo("Started state sync", context: [
            "deviceId": deviceId,
            "deviceType": deviceType.rawValue
        ])
    }
    
    /// Stops state synchronization for a device
    /// - Parameter deviceId: The ID of the device to stop syncing
    public func stopSync(deviceId: String) {
        deviceStates.removeValue(forKey: deviceId)
        stateSubscribers.removeValue(forKey: deviceId)
        
        logger.logInfo("Stopped state sync", context: ["deviceId": deviceId])
    }
    
    /// Updates the state for a device
    /// - Parameters:
    ///   - deviceId: The ID of the device
    ///   - newState: The new state to set
    public func updateState(deviceId: String, newState: DeviceState) {
        deviceStates[deviceId] = newState
        notifySubscribers(deviceId: deviceId, state: newState)
        
        logger.logInfo("Updated device state", context: [
            "deviceId": deviceId,
            "state": newState
        ])
    }
    
    /// Gets the current state for a device
    /// - Parameter deviceId: The ID of the device
    /// - Returns: The current state of the device
    public func getState(deviceId: String) -> DeviceState? {
        deviceStates[deviceId]
    }
    
    /// Subscribes to state changes for a device
    /// - Parameters:
    ///   - deviceId: The ID of the device
    ///   - completion: The completion handler for state updates
    /// - Returns: A cancellable subscription
    public func subscribeToState(deviceId: String, completion: @escaping (DeviceState) -> Void) -> AnyCancellable {
        let subscriber = NotificationCenter.default
            .publisher(for: .deviceStateChanged)
            .compactMap { notification -> DeviceState? in
                guard let state = notification.userInfo?["state"] as? DeviceState,
                      notification.userInfo?["deviceId"] as? String == deviceId else {
                    return nil
                }
                return state
            }
            .sink { state in
                completion(state)
            }
        
        if stateSubscribers[deviceId] == nil {
            stateSubscribers[deviceId] = []
        }
        stateSubscribers[deviceId]?.append(subscriber)
        
        // Send initial state if available
        if let currentState = deviceStates[deviceId] {
            completion(currentState)
        }
        
        return subscriber
    }
    
    // MARK: - Private Methods
    
    private func setupSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.syncAllDevices()
        }
    }
    
    private func setupDeviceSubscribers(deviceId: String, deviceType: DeviceType) {
        // Subscribe to device-specific events
        let eventSubscriber = NotificationCenter.default
            .publisher(for: .deviceEvent)
            .filter { notification in
                notification.userInfo?["deviceId"] as? String == deviceId
            }
            .sink { [weak self] notification in
                self?.handleDeviceEvent(deviceId: deviceId, event: notification)
            }
        
        if stateSubscribers[deviceId] == nil {
            stateSubscribers[deviceId] = []
        }
        stateSubscribers[deviceId]?.append(eventSubscriber)
    }
    
    private func syncAllDevices() {
        Task {
            for (deviceId, _) in deviceStates {
                await syncDevice(deviceId: deviceId)
            }
        }
    }
    
    private func syncDevice(deviceId: String) async {
        let startTime = Date()
        
        do {
            // Fetch latest state from SmartThings
            let state = try await SmartThingsAdapter.shared.fetchDeviceState(deviceId: deviceId)
            
            // Update local state
            updateState(deviceId: deviceId, newState: state)
            
            let latency = Date().timeIntervalSince(startTime)
            metrics.recordOperationLatency("stateSync", latency: latency)
            
            logger.logInfo("Synced device state", context: [
                "deviceId": deviceId,
                "latency": latency
            ])
        } catch {
            logger.logError(error as? SmartThingsError ?? .deviceNotFound(deviceId), context: [
                "deviceId": deviceId,
                "operation": "stateSync"
            ])
        }
    }
    
    private func handleDeviceEvent(deviceId: String, event: Notification) {
        guard let eventData = event.userInfo else { return }
        
        // Update state based on event
        if let newState = eventData["state"] as? DeviceState {
            updateState(deviceId: deviceId, newState: newState)
        }
    }
    
    private func notifySubscribers(deviceId: String, state: DeviceState) {
        NotificationCenter.default.post(
            name: .deviceStateChanged,
            object: nil,
            userInfo: [
                "deviceId": deviceId,
                "state": state
            ]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let deviceStateChanged = Notification.Name("deviceStateChanged")
    static let deviceEvent = Notification.Name("deviceEvent")
} 