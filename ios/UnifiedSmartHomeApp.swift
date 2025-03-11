import SwiftUI

@main
struct UnifiedSmartHomeApp: App {
    // Create shared instances of view models
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var thermostatViewModel = ThermostatViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(thermostatViewModel)
        }
    }
} 