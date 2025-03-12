import Foundation
import Combine

class ThermostatViewModel: ObservableObject {
    @Published var thermostats: [ThermostatDevice] = []
    @Published var isLoading = false
    @Published var error: String?
    
    // Retry settings for operations
    private let maxRetryAttempts = 3
    private var currentRetryCount = 0
    
    // State tracking for token refreshes
    private var isRefreshingToken = false
    private var pendingOperations: [() -> Void] = []
    
    // Dependencies
    private var nestAdapter: NestAdapter
    private(set) var nestOAuthManager: NestOAuthManager
    private var cancellables = Set<AnyCancellable>()
    
    init(nestAdapter: NestAdapter? = nil, nestOAuthManager: NestOAuthManager = NestOAuthManager()) {
        self.nestOAuthManager = nestOAuthManager
        self.nestAdapter = nestAdapter ?? NestAdapter(nestOAuthManager: nestOAuthManager)
        
        // Listen for authentication changes
        nestOAuthManager.$isAuthenticated
            .dropFirst()
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                
                if isAuthenticated {
                    // User just authenticated, fetch devices
                    self.fetchThermostats()
                    
                    // Process any pending operations
                    self.processPendingOperations()
                } else {
                    // Clear thermostats when logged out
                    self.thermostats = []
                }
            }
            .store(in: &cancellables)
        
        // Listen for errors
        nestOAuthManager.$error
            .compactMap { $0 }
            .sink { [weak self] errorMessage in
                self?.error = errorMessage
            }
            .store(in: &cancellables)
    }
    
    // Initiate Nest OAuth flow
    func authenticateNest() {
        nestOAuthManager.startOAuthFlow()
    }
    
    // Sign out from Nest
    func signOut() {
        nestOAuthManager.signOut()
    }
    
    // Fetch thermostats with retry logic
    func fetchThermostats() {
        // Reset retry counter for a new operation
        currentRetryCount = 0
        _fetchThermostatsWithRetry()
    }
    
    // Internal method that handles retries
    private func _fetchThermostatsWithRetry() {
        guard let token = nestOAuthManager.getAccessToken() else {
            // Not authenticated, store this operation to run after authentication
            if !isRefreshingToken {
                error = "Not authenticated with Nest. Please connect your account."
                addPendingOperation { [weak self] in 
                    self?._fetchThermostatsWithRetry()
                }
            }
            return
        }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                try nestAdapter.initializeConnection(authToken: token)
                let devices = try await nestAdapter.fetchDevices()
                
                // Filter for thermostat devices only
                let thermostats = devices.compactMap { $0 as? ThermostatDevice }
                
                DispatchQueue.main.async {
                    self.thermostats = thermostats
                    self.isLoading = false
                    self.currentRetryCount = 0 // Reset on success
                }
            } catch let adapterError as NestAdapterError {
                await handleAdapterError(adapterError, for: "fetch thermostats") {
                    self._fetchThermostatsWithRetry()
                }
            } catch {
                DispatchQueue.main.async {
                    // Generic error handling for unknown errors
                    if self.currentRetryCount < self.maxRetryAttempts {
                        self.currentRetryCount += 1
                        // Exponential backoff: 1s, 2s, 4s...
                        let delay = TimeInterval(pow(2.0, Double(self.currentRetryCount - 1)))
                        
                        self.error = "Retrying in \(Int(delay)) seconds..."
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self._fetchThermostatsWithRetry()
                        }
                    } else {
                        self.error = "Failed to fetch thermostats: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    // Set temperature with retry logic
    func setTemperature(for thermostat: ThermostatDevice, to temperature: Double) {
        // Reset retry counter for a new operation
        currentRetryCount = 0
        _setTemperatureWithRetry(for: thermostat, to: temperature)
    }
    
    private func _setTemperatureWithRetry(for thermostat: ThermostatDevice, to temperature: Double) {
        guard let token = nestOAuthManager.getAccessToken() else {
            // Not authenticated, store this operation to run after authentication
            if !isRefreshingToken {
                error = "Not authenticated with Nest. Please connect your account."
                addPendingOperation { [weak self] in 
                    guard let self = self else { return }
                    self._setTemperatureWithRetry(for: thermostat, to: temperature)
                }
            }
            return
        }
        
        isLoading = true
        error = nil
        
        // Create the updated state with the new target temperature
        let updatedState = thermostat.updateTargetTemperature(to: temperature)
        
        Task {
            do {
                try nestAdapter.initializeConnection(authToken: token)
                let _ = try await nestAdapter.updateDeviceState(deviceId: thermostat.id, newState: updatedState)
                
                DispatchQueue.main.async {
                    // Reset counter on success
                    self.currentRetryCount = 0
                    
                    // Update the local model immediately for responsive UI
                    if let index = self.thermostats.firstIndex(where: { $0.id == thermostat.id }) {
                        self.thermostats[index].updateTargetTemperature(to: temperature)
                    }
                    
                    // Then refresh all thermostats to get the fully updated state
                    self.fetchThermostats()
                }
            } catch let adapterError as NestAdapterError {
                await handleAdapterError(adapterError, for: "set temperature") {
                    self._setTemperatureWithRetry(for: thermostat, to: temperature)
                }
            } catch {
                DispatchQueue.main.async {
                    // Generic error handling with retry
                    if self.currentRetryCount < self.maxRetryAttempts {
                        self.currentRetryCount += 1
                        // Exponential backoff: 1s, 2s, 4s...
                        let delay = TimeInterval(pow(2.0, Double(self.currentRetryCount - 1)))
                        
                        self.error = "Retrying in \(Int(delay)) seconds..."
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self._setTemperatureWithRetry(for: thermostat, to: temperature)
                        }
                    } else {
                        self.error = "Failed to set temperature: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    // Set mode with retry logic
    func setMode(for thermostat: ThermostatDevice, to mode: ThermostatDevice.ThermostatMode) {
        // Reset retry counter for a new operation
        currentRetryCount = 0
        _setModeWithRetry(for: thermostat, to: mode)
    }
    
    private func _setModeWithRetry(for thermostat: ThermostatDevice, to mode: ThermostatDevice.ThermostatMode) {
        guard let token = nestOAuthManager.getAccessToken() else {
            // Not authenticated, store this operation to run after authentication
            if !isRefreshingToken {
                error = "Not authenticated with Nest. Please connect your account."
                addPendingOperation { [weak self] in 
                    guard let self = self else { return }
                    self._setModeWithRetry(for: thermostat, to: mode)
                }
            }
            return
        }
        
        isLoading = true
        error = nil
        
        // Create the updated state with the new mode
        let updatedState = thermostat.updateMode(to: mode)
        
        Task {
            do {
                try nestAdapter.initializeConnection(authToken: token)
                let _ = try await nestAdapter.updateDeviceState(deviceId: thermostat.id, newState: updatedState)
                
                DispatchQueue.main.async {
                    // Reset counter on success
                    self.currentRetryCount = 0
                    
                    // Update the local model immediately for responsive UI
                    if let index = self.thermostats.firstIndex(where: { $0.id == thermostat.id }) {
                        self.thermostats[index].updateMode(to: mode)
                    }
                    
                    // Then refresh all thermostats to get the fully updated state
                    self.fetchThermostats()
                }
            } catch let adapterError as NestAdapterError {
                await handleAdapterError(adapterError, for: "set mode") {
                    self._setModeWithRetry(for: thermostat, to: mode)
                }
            } catch {
                DispatchQueue.main.async {
                    // Generic error handling with retry
                    if self.currentRetryCount < self.maxRetryAttempts {
                        self.currentRetryCount += 1
                        // Exponential backoff: 1s, 2s, 4s...
                        let delay = TimeInterval(pow(2.0, Double(self.currentRetryCount - 1)))
                        
                        self.error = "Retrying in \(Int(delay)) seconds..."
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self._setModeWithRetry(for: thermostat, to: mode)
                        }
                    } else {
                        self.error = "Failed to set mode: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    // Common handler for adapter-specific errors
    private func handleAdapterError(_ error: NestAdapterError, for operation: String, retryOperation: @escaping () -> Void) async {
        DispatchQueue.main.async {
            switch error {
            case .notAuthenticated:
                // Token issue - try to refresh
                self.error = "Authentication expired. Refreshing credentials..."
                self.isRefreshingToken = true
                self.nestOAuthManager.refreshAccessToken()
                self.addPendingOperation(retryOperation)
                
            case .rateLimited(let retryAfter):
                // Handle rate limiting with backoff
                let delay = retryAfter ?? Double(self.currentRetryCount + 1)
                self.error = "Rate limited. Retrying in \(Int(delay)) seconds..."
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    retryOperation()
                }
                
            case .serverError(let code):
                if self.currentRetryCount < self.maxRetryAttempts {
                    self.currentRetryCount += 1
                    let delay = TimeInterval(pow(2.0, Double(self.currentRetryCount - 1)))
                    
                    self.error = "Server error (\(code)). Retrying in \(Int(delay)) seconds..."
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        retryOperation()
                    }
                } else {
                    self.error = "Failed to \(operation): Server error (\(code))"
                    self.isLoading = false
                }
                
            default:
                // For other errors, show the error message
                self.error = "Failed to \(operation): \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // Utility to track pending operations (e.g., while refreshing token)
    private func addPendingOperation(_ operation: @escaping () -> Void) {
        pendingOperations.append(operation)
    }
    
    // Process pending operations after token refresh
    private func processPendingOperations() {
        isRefreshingToken = false
        
        // Take a copy of pending operations and clear the queue
        let operations = pendingOperations
        pendingOperations.removeAll()
        
        // Execute each operation
        for operation in operations {
            operation()
        }
    }
} 