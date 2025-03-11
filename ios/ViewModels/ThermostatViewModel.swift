import Foundation
import Combine

class ThermostatViewModel: ObservableObject {
    @Published var thermostats: [ThermostatDevice] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var nestAdapter: NestAdapter
    private var nestOAuthManager: NestOAuthManager
    private var cancellables = Set<AnyCancellable>()
    
    init(nestAdapter: NestAdapter = NestAdapter(), nestOAuthManager: NestOAuthManager = NestOAuthManager()) {
        self.nestAdapter = nestAdapter
        self.nestOAuthManager = nestOAuthManager
        
        // Listen for authentication changes
        nestOAuthManager.$isAuthenticated
            .dropFirst()
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.fetchThermostats()
                } else {
                    self?.thermostats = []
                }
            }
            .store(in: &cancellables)
    }
    
    func authenticateNest() {
        nestOAuthManager.startOAuthFlow()
    }
    
    func signOut() {
        nestOAuthManager.signOut()
    }
    
    func fetchThermostats() {
        guard let token = nestOAuthManager.getAccessToken() else {
            error = "Not authenticated with Nest"
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
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = "Failed to fetch thermostats: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func setTemperature(for thermostat: ThermostatDevice, to temperature: Double) {
        guard let token = nestOAuthManager.getAccessToken() else {
            error = "Not authenticated with Nest"
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
                
                // Refresh thermostats to get the updated state
                fetchThermostats()
            } catch {
                DispatchQueue.main.async {
                    self.error = "Failed to set temperature: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func setMode(for thermostat: ThermostatDevice, to mode: ThermostatDevice.ThermostatMode) {
        guard let token = nestOAuthManager.getAccessToken() else {
            error = "Not authenticated with Nest"
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
                
                // Refresh thermostats to get the updated state
                fetchThermostats()
            } catch {
                DispatchQueue.main.async {
                    self.error = "Failed to set mode: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
} 