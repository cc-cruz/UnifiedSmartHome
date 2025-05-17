import SwiftUI
import Models
import Services
import Adapters // Assuming adapters are in this module

@main
struct UnifiedSmartHomeApp: App {
    
    // StateObject to manage the lifecycle of our core services
    @StateObject private var appServices = AppServices()
    @StateObject private var userContext = UserContextViewModel()
    
    var body: some Scene {
        WindowGroup {
            // Pass DeviceService down via environment
            ContentView() // Replace MainTabView or adapt it
                .environmentObject(appServices.deviceService) // Provide DeviceService
                .environmentObject(appServices.userManager) // Provide UserManager
                .environmentObject(userContext)
                // Provide other services/viewmodels as needed
                .onAppear {
                    // Setup any app-wide configurations here
                    setupAppearance()
                    
                    // TODO: Trigger initial data load or authentication check if needed
                    // Task { await appServices.userManager.checkLoginStatus() }
                }
        }
    }
    
    private func setupAppearance() {
        // Configure global UI appearance
        UINavigationBar.appearance().tintColor = .systemBlue
        // Add other appearance settings
    }
}

// Class to encapsulate the setup and holding of core services
// Follows ObservableObject to allow UI updates if needed (e.g., auth state)
class AppServices: ObservableObject {
    let networkService: NetworkServiceProtocol
    let keychainHelper: KeychainHelperProtocol // Use protocol
    let userManager: UserManager // Assuming UserManager manages its own state and notifies views
    let auditLogger: AuditLoggerProtocol // Use protocol
    let analyticsService: AnalyticsService // Use protocol if available
    
    // Adapters
    let nestAdapter: SmartDeviceAdapter
    let augustLockAdapter: SmartDeviceAdapter
    let yaleLockAdapter: SmartDeviceAdapter
    let smartThingsAdapter: SmartDeviceAdapter
    let hueLightAdapter: SmartDeviceAdapter
    
    // Core Services
    let deviceService: DeviceManagerProtocol // Use protocol
    let securityService: SecurityServiceProtocol // Use protocol

    init() {
        // 1. Instantiate Core Shared Services
        // Use concrete types here, but ideally use protocols for testability
        self.networkService = NetworkService() // Basic instance
        self.keychainHelper = KeychainHelper.shared // Existing singleton usage
        self.userManager = UserManager.shared // Existing singleton usage
        self.analyticsService = AnalyticsService.shared // Existing singleton usage
        self.auditLogger = AuditLogger(
            analyticsService: self.analyticsService,
            persistentStorage: CoreDataAuditLogStorage() // Assuming this exists
        )
        
        // 2. Instantiate Adapters (Requires Configuration!)
        // TODO: Replace placeholders with actual config/keys/tokens/IPs
        
        // Network services might need specific base URLs or auth handlers per adapter
        let nestNetworkService = NetworkService() // Configure for Nest API
        let augustNetworkService = NetworkService() // Configure for August API
        let yaleNetworkService = NetworkService() // Configure for Yale API
        let smartThingsNetworkService = NetworkService() // Configure for SmartThings API
        
        // MODIFIED: Define Hue Bridge IP and create base URL
        // TODO: Replace this placeholder with actual bridge IP discovery/configuration
        // Using 0.0.0.0 as a valid placeholder for compilation when a real bridge is not available for testing.
        let hueBridgeIP = "0.0.0.0" // <<< --- Placeholder for compilation. Replace with real IP or discovery later! ---
        guard let hueBridgeBaseURL = URL(string: "https://\(hueBridgeIP)") else {
            // This should ideally not fail with a hardcoded valid format string like above.
            // If it does, there's a fundamental issue with URL string formatting.
            fatalError("Critical error: Could not form Hue Bridge Base URL from placeholder IP.") 
        }
        let hueNetworkService = NetworkService() // Initializer does not take baseURL

        // Token Managers
        let nestTokenManager = NestOAuthManager(keychainHelper: self.keychainHelper, networkService: nestNetworkService)
        let augustTokenManager = AugustTokenManager(keychainHelper: self.keychainHelper, networkService: augustNetworkService)
        // Yale might use same as August or its own?
        let yaleTokenManager = AugustTokenManager(keychainHelper: self.keychainHelper, networkService: yaleNetworkService) // Placeholder!
        let smartThingsTokenManager = SmartThingsTokenManager(keychainHelper: self.keychainHelper, networkService: smartThingsNetworkService)
        // Hue uses Application Key locally, potentially OAuth remotely (Token manager needed for remote)
        let hueAppKey = keychainHelper.getString(forKey: "hueApplicationKey") // Example: Get key from Keychain

        self.nestAdapter = NestAdapter(networkService: nestNetworkService, oauthManager: nestTokenManager)
        self.augustLockAdapter = AugustLockAdapter(networkService: augustNetworkService, tokenManager: augustTokenManager)
        self.yaleLockAdapter = YaleLockAdapter(networkService: yaleNetworkService, tokenManager: yaleTokenManager) // Placeholder!
        self.smartThingsAdapter = SmartThingsAdapter(networkService: smartThingsNetworkService, tokenManager: smartThingsTokenManager)
        // MODIFIED: Pass bridgeBaseURL to HueLightAdapter initializer
        self.hueLightAdapter = HueLightAdapter(networkService: hueNetworkService, bridgeBaseURL: hueBridgeBaseURL, applicationKey: hueAppKey)
        
        let allAdapters: [SmartDeviceAdapter] = [
            self.nestAdapter, 
            self.augustLockAdapter, 
            self.yaleLockAdapter, 
            self.smartThingsAdapter, 
            self.hueLightAdapter
        ]
        
        // 3. Instantiate DeviceService with Adapters
        self.deviceService = DeviceService(adapters: allAdapters)
        
        // 4. Instantiate SecurityService
        // Assuming SecurityServiceProtocol exists and SecurityService conforms to it
        self.securityService = SecurityService(
            userManager: self.userManager,
            auditLogger: self.auditLogger,
            deviceManager: self.deviceService
        )
        
        print("AppServices initialized successfully.")
        // TODO: Perform initial adapter setup/auth if needed
        // Task { try? await nestTokenManager.initialize() ... etc }
    }
}

// MARK: - Placeholder/Existing UI Code (Needs Refactoring)

// TODO: Replace MainTabView with a ContentView that uses DeviceService from environment
//       to feed a DevicesViewModel, which powers the consolidated DevicesView.
struct ContentView: View { // Example replacement for MainTabView
    @EnvironmentObject var deviceService: DeviceManagerProtocol
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var userContext: UserContextViewModel
    
    var body: some View {
        // Check login state, show LoginView or main content
        if userManager.isLoggedIn {
             MainAppView() // Your main tab view or structure
                 .environmentObject(deviceService) // Pass down again if needed
         } else {
             LoginView() // Use existing LoginView
                 .environmentObject(userManager) // Pass UserManager for login action
         }
    }
}

struct MainAppView: View { // Example replacement for MainTabView content
     @EnvironmentObject var deviceService: DeviceManagerProtocol
     // Create a ViewModel that uses the deviceService
     @StateObject private var devicesViewModel: DevicesViewModel // Create this ViewModel
     
     // Inject deviceService into the ViewModel upon creation
     init(deviceService: DeviceManagerProtocol) {
         _devicesViewModel = StateObject(wrappedValue: DevicesViewModel(deviceManager: deviceService))
     }
     
    var body: some View {
        TabView { // Simplified TabView for now
            // Devices Tab - Uses the new consolidated view & ViewModel
            NavigationView {
                DevicesView(viewModel: devicesViewModel) // Use the new DevicesView
                    .navigationTitle("All Devices")
            }
            .tabItem { Label("Devices", systemImage: "house.fill") }
            
            // Settings Tab
            NavigationView {
                SettingsView() // Use existing SettingsView
                     .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}


// NOTE: Keeping SettingsView for now, it uses UserManager.shared directly
struct SettingsView: View {
    // Make UserManager an EnvironmentObject here too for consistency
    @EnvironmentObject var userManager: UserManager 
    @State private var isLoggedIn: Bool = false // Initialize based on environment later

    var body: some View {
        List {
            Section(header: Text("Account")) {
                if isLoggedIn {
                    Button("Log Out") {
                        Task {
                            await userManager.logout()
                            // isLogged In state will update via @EnvironmentObject change
                        }
                    }
                    .foregroundColor(.red)
                } else {
                    // Login should be handled by the LoginView presented by ContentView
                    Text("Not Logged In")
                }
            }
            
            Section(header: Text("Preferences")) {
                Toggle("Dark Mode", isOn: .constant(false)) // Placeholder
                Toggle("Notifications", isOn: .constant(true)) // Placeholder
                Toggle("Biometric Authentication", isOn: .constant(true)) // Placeholder
            }
            
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0") // TODO: Get from bundle
                        .foregroundColor(.gray)
                }
                
                NavigationLink(destination: Text("Privacy Policy would go here")) {
                    Text("Privacy Policy")
                }
                
                NavigationLink(destination: Text("Terms of Service would go here")) {
                    Text("Terms of Service")
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .onAppear {
             // Update local state when view appears based on environment object
             isLoggedIn = userManager.isLoggedIn
         }
         .onChange(of: userManager.isLoggedIn) { _ , newState in
             // Update local state when environment object changes
             isLoggedIn = newState
         }
    }
}

// MARK: - Protocol Definitions (Placeholders - ensure these exist in Models/Services)

protocol KeychainHelperProtocol { // Example
    func getString(forKey key: String) -> String?
    func setString(_ value: String, forKey key: String) -> Bool
    // Add other methods needed
}

protocol AuditLoggerProtocol { // Example
     func logSecurityEvent(type: String, details: [String: String])
     // Add other methods needed
}

protocol SecurityServiceProtocol { // Example
    // Define methods used by SecurityService
     func validateUserPermission(userId: String, deviceId: String, operation: String) async throws -> Bool
     // Add others like secureCriticalOperation, authenticateAndPerform, isDeviceJailbroken
}

// Placeholder for storage dependency
struct CoreDataAuditLogStorage { }

// MARK: - Core ViewModels

// ViewModel for the consolidated DevicesView
@MainActor // Ensure UI updates happen on the main thread
class DevicesViewModel: ObservableObject {
    private let deviceManager: DeviceManagerProtocol
    // TODO: Inject UserManager, SecurityService if needed for permission checks before command execution
    
    @Published var devices: [AbstractDevice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // Store devices in a dictionary for faster updates by ID
    private var deviceDict: [String: AbstractDevice] = [:]

    init(deviceManager: DeviceManagerProtocol) {
        self.deviceManager = deviceManager
        print("DevicesViewModel initialized.")
    }
    
    // Function to load devices from the DeviceManager
    func loadDevices() async {
        // Avoid concurrent loads
        guard !isLoading else { return }
        
        print("DevicesViewModel: Loading devices...")
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedDevices = try await deviceManager.getAllDevices()
            // Update dictionary and published array
            updateDeviceStore(with: fetchedDevices)
            print("DevicesViewModel: Successfully loaded \\(devices.count) devices.")
        } catch {
            print("DevicesViewModel: Error loading devices: \\(error)")
            errorMessage = "Failed to load devices: \\(error.localizedDescription)"
            // Optionally clear devices on critical error, or leave stale data?
            // updateDeviceStore(with: []) // Clear devices on error
        }
        isLoading = false
    }
    
    // Function to execute a command on a device
    func executeDeviceCommand(deviceId: String, command: DeviceCommand) async {
        print("DevicesViewModel: Executing command \\(command) for device \\(deviceId)")
        // Optional: Set a specific loading state for the device being controlled
        // setLoadingState(for: deviceId, isLoading: true)
        
        // Clear previous global error messages related to commands if desired
        // if errorMessage != nil && !isLoading { errorMessage = nil }
        
        do {
            // TODO: Add permission check here using SecurityService/UserManager if needed
            // guard try await securityService.canUserPerform(userId: ..., deviceId: deviceId, command: command) else { throw ... }
            
            let updatedDevice = try await deviceManager.executeCommand(deviceId: deviceId, command: command)
            // Update the specific device in the dictionary and array
            updateSingleDevice(updatedDevice)
            print("DevicesViewModel: Command successful for \\(deviceId). Updated state: \\(updatedDevice)")
            
            // Clear error message on success
            if errorMessage != nil && !errorMessage!.contains("Failed to load devices") { errorMessage = nil }
            
        } catch {
            print("DevicesViewModel: Error executing command for \\(deviceId): \\(error)")
            // Display error message to the user
            errorMessage = "Command failed for \\(deviceDict[deviceId]?.name ?? "device"): \\(error.localizedDescription)"
            // Optional: Refresh the device state from the server to ensure UI consistency after failure
            // Task { await refreshDeviceState(deviceId: deviceId) }
        }
        // setLoadingState(for: deviceId, isLoading: false)
    }
    
    // Function to refresh a single device's state
    func refreshDeviceState(deviceId: String) async {
         print("DevicesViewModel: Refreshing state for device \\(deviceId)")
         // Optional: Set loading state for the specific device
         // setLoadingState(for: deviceId, isLoading: true)
         do {
             let updatedDevice = try await deviceManager.getDeviceState(id: deviceId)
             updateSingleDevice(updatedDevice)
             print("DevicesViewModel: Successfully refreshed state for \\(deviceId).")
         } catch {
             print("DevicesViewModel: Error refreshing device state for \\(deviceId): \\(error)")
             errorMessage = "Failed to refresh \\(deviceDict[deviceId]?.name ?? "device"): \\(error.localizedDescription)"
         }
         // setLoadingState(for: deviceId, isLoading: false)
     }
     
    // MARK: - Private Helpers
    
    // Helper to update the internal dictionary and the published array
    private func updateDeviceStore(with newDevices: [AbstractDevice]) {
        // Update dictionary
        deviceDict = Dictionary(uniqueKeysWithValues: newDevices.map { ($0.id, $0) })
        // Update published array, maybe sort it?
        devices = newDevices.sorted { $0.name.lowercased() < $1.name.lowercased() } // Example sort
    }
    
    // Helper to update a single device in the store and published array
    private func updateSingleDevice(_ device: AbstractDevice) {
        deviceDict[device.id] = device
        // Update the array efficiently
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        } else {
            // Device wasn't in the list before? Add it and re-sort?
            devices.append(device)
            devices.sort { $0.name.lowercased() < $1.name.lowercased() } // Re-sort if needed
        }
    }
    
    // Optional: Helper for per-device loading state (requires more complex state management)
    // private func setLoadingState(for deviceId: String, isLoading: Bool) { ... }
}

// The consolidated view for displaying all devices
struct DevicesView: View {
     @StateObject var viewModel: DevicesViewModel // Owns the ViewModel passed from MainAppView
     @EnvironmentObject var userContext: UserContextViewModel
     
     var body: some View {
         List {
             // Display Error Banner if errorMessage is set
             if let error = viewModel.errorMessage {
                 errorBanner(message: error)
             }
             
             // Show devices or loading indicator
             if viewModel.isLoading && viewModel.devices.isEmpty { // Show loading only on initial load
                 ProgressView("Loading Devices...")
                     .frame(maxWidth: .infinity, alignment: .center)
             } else if !viewModel.isLoading && filteredDevices.isEmpty && viewModel.errorMessage == nil {
                 Text("No devices found for this context. Pull down to refresh.")
                      .foregroundColor(.gray)
                      .frame(maxWidth: .infinity, alignment: .center)
             } else {
                 // Device Rows
                 ForEach(filteredDevices, id: \.id) {
                      DeviceRow(device: $0)
                          .environmentObject(viewModel) // Pass ViewModel down to row for actions
                          // Add swipe actions if needed
                          // .swipeActions { Button("Refresh") { Task { await viewModel.refreshDeviceState(deviceId: $0.id) } } }
                  }
             }
         }
         .navigationTitle("Devices") // Set title here if used within NavigationView
         .toolbar { // Add refresh button to toolbar
             ToolbarItem(placement: .navigationBarTrailing) {
                 Button {
                     Task { await viewModel.loadDevices() }
                 } label: {
                     Label("Refresh", systemImage: "arrow.clockwise")
                 }
                 .disabled(viewModel.isLoading)
             }
         }
         .onAppear { // Load devices when the view appears
             // Only load if devices haven't been loaded yet to avoid redundant calls
             if viewModel.devices.isEmpty {
                 Task { await viewModel.loadDevices() }
             }
         }
         .refreshable { // Enable pull-to-refresh
              Task { await viewModel.loadDevices() }
         }
         // Optional: Display a global loading indicator overlay
         // .overlay { 
         //     if viewModel.isLoading { 
         //          ProgressView().controlSize(.large) 
         //     } 
         // }
     }
     
     private var filteredDevices: [AbstractDevice] {
         viewModel.devices.filter { device in
             // If a unit is selected, match unitId first.
             if let unitId = userContext.selectedUnitId, let lock = device as? LockDevice {
                 return lock.unitId == unitId
             }
             // Else if property selected, match propertyId
             if let propertyId = userContext.selectedPropertyId {
                 if let lock = device as? LockDevice {
                     return lock.propertyId == propertyId
                 }
                 if let thermo = device as? ThermostatDevice { /* assume propertyId available via metadata? */ }
             }
             return true // fall back if no context filter
         }
     }
     
     // Helper view for displaying errors
     private func errorBanner(message: String) -> some View {
         HStack {
             Image(systemName: "exclamationmark.octagon.fill")
                 .foregroundColor(.white)
             Text(message)
                 .foregroundColor(.white)
                 .font(.system(size: 14, weight: .medium))
             Spacer()
             Button {
                 viewModel.errorMessage = nil // Dismiss error
             } label: {
                  Image(systemName: "xmark.circle.fill")
                      .foregroundColor(.white)
             }
         }
         .padding()
         .background(Color.red)
         .cornerRadius(8)
         .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
     }
 }
 
// Row view for a single device
struct DeviceRow: View {
    let device: AbstractDevice
    @EnvironmentObject var viewModel: DevicesViewModel

    var body: some View {
        HStack {
            // Device Icon (Example)
            deviceIcon
                .font(.title2)
                .frame(width: 30)
                .foregroundColor(device.isOnline ? .primary : .secondary)

            // Device Info
            VStack(alignment: .leading) {
                Text(device.name).font(.headline)
                Text(deviceTypeText).font(.subheadline).foregroundColor(.gray)
                if !device.isOnline {
                     Text("Offline").font(.caption).foregroundColor(.red)
                }
                // Optionally show room: Text(device.room).font(.caption).foregroundColor(.gray)
            }
            
            Spacer()
            
            // Device Controls
            deviceControls
        }
        .opacity(device.isOnline ? 1.0 : 0.6) // Dim offline devices
        // TODO: Add tap gesture for navigation to a detail view if needed
        // .contentShape(Rectangle()) // Make entire row tappable
        // .onTapGesture { ... navigate to detail view ... }
    }
    
    // MARK: - Computed Views for Row Components

    // Determine icon based on device type
    @ViewBuilder
    private var deviceIcon: some View {
        switch device {
        case is LockDevice:
            Image(systemName: "lock.shield.fill")
        case is LightDevice:
            Image(systemName: "lightbulb.fill")
        case is ThermostatDevice:
            Image(systemName: "thermometer")
        case is SwitchDevice:
             Image(systemName: "switch.2")
        default:
            Image(systemName: "questionmark.circle")
        }
    }
    
    // Determine descriptive text based on device type and state
    private var deviceTypeText: String {
        switch device {
        case let lock as LockDevice:
            return lock.currentState.rawValue.capitalized
        case let light as LightDevice:
            var status = light.isOn ? "On" : "Off"
            if light.isOn, let brightness = light.brightness {
                 status += ", \\(Int(brightness))%"
            }
            // Add color info if needed/available
            return status
        case let thermostat as ThermostatDevice:
            return "\\(thermostat.currentTemperature, specifier: "%.1f")°\\(thermostat.targetTemperature != nil ? " (Target: \\(thermostat.targetTemperature!, specifier: "%.1f")°)" : "") - \\(thermostat.mode.rawValue.capitalized)"
        case let sw as SwitchDevice:
             return sw.isOn ? "On" : "Off"
        default:
            return "Unknown Device Type"
        }
    }
    
    // Determine interactive controls based on device type
    @ViewBuilder
    private var deviceControls: some View {
        // Use a group to avoid needing explicit AnyView returns
        Group {
            switch device {
            case let lock as LockDevice:
                Button {
                    let command: DeviceCommand = lock.currentState == .locked ? .unlock : .lock
                    Task { await viewModel.executeDeviceCommand(deviceId: lock.id, command: command) }
                } label: {
                    Image(systemName: lock.currentState == .locked ? "lock.fill" : "lock.open.fill")
                        .font(.title2)
                        .frame(width: 40, height: 40) // Ensure tappable area
                        .contentShape(Rectangle())
                }
                .disabled(!device.isOnline) // Disable if offline
                .foregroundColor(device.isOnline ? (lock.currentState == .locked ? .blue : .orange) : .gray)
                
            case let light as LightDevice:
                 HStack {
                     // TODO: Add NavigationLink/Button to detail view for brightness/color
                     // NavigationLink(destination: LightDetailView(light: light)) { Image(systemName: "slider.horizontal.3") } 
                     Toggle("", isOn: Binding(
                         get: { light.isOn },
                         set: { isOn in
                             let command: DeviceCommand = isOn ? .turnOn : .turnOff
                             Task { await viewModel.executeDeviceCommand(deviceId: light.id, command: command) }
                         }
                     ))
                     .labelsHidden()
                     .disabled(!device.isOnline)
                 }
                 
             case let thermostat as ThermostatDevice:
                  // TODO: Add controls for thermostat (e.g., +/- buttons, link to detail view)
                  Text("Controls TBD")
                  .font(.caption)
                  .foregroundColor(.gray)
                  
              case let sw as SwitchDevice:
                   Toggle("", isOn: Binding(
                        get: { sw.isOn },
                        set: { isOn in
                            let command: DeviceCommand = .setSwitch(isOn)
                            Task { await viewModel.executeDeviceCommand(deviceId: sw.id, command: command) }
                        }
                    ))
                    .labelsHidden()
                    .disabled(!device.isOnline)

            default:
                EmptyView()
            }
        }
        .buttonStyle(BorderlessButtonStyle()) // Prevent controls from triggering row tap if added
    }
}

// Protocol placeholders need to be moved to appropriate files
// Remove these from here once defined properly in Models/Services
protocol AnalyticsService { }
protocol SmartDeviceAdapter {
     func fetchDevices() async throws -> [AbstractDevice]
     func getDeviceState(deviceId: String) async throws -> AbstractDevice
     func executeCommand(deviceId: String, command: DeviceCommand) async throws -> AbstractDevice
     // Add initialize, refreshAuthentication, revokeAuthentication if needed by protocol
}
protocol NestAdapter: SmartDeviceAdapter { }
protocol AugustLockAdapter: SmartDeviceAdapter { }
protocol YaleLockAdapter: SmartDeviceAdapter { }
protocol SmartThingsAdapter: SmartDeviceAdapter { }
protocol HueLightAdapter: SmartDeviceAdapter { }

class NestOAuthManager { init(keychainHelper: KeychainHelperProtocol, networkService: NetworkServiceProtocol) {} }
class AugustTokenManager { init(keychainHelper: KeychainHelperProtocol, networkService: NetworkServiceProtocol) {} }
class SmartThingsTokenManager { init(keychainHelper: KeychainHelperProtocol, networkService: NetworkServiceProtocol) {} }

// Concrete adapter classes need importing or defining
// These are placeholders assuming they exist in an Adapters module
class NestAdapter: NestAdapter { init(networkService: NetworkServiceProtocol, oauthManager: NestOAuthManager) {} }
class AugustLockAdapter: AugustLockAdapter { init(networkService: NetworkServiceProtocol, tokenManager: AugustTokenManager) {} }
class YaleLockAdapter: YaleLockAdapter { init(networkService: NetworkServiceProtocol, tokenManager: AugustTokenManager) {} }
class SmartThingsAdapter: SmartThingsAdapter { init(networkService: NetworkServiceProtocol, tokenManager: SmartThingsTokenManager) {} }
// HueLightAdapter is already defined in the project

// Remove NetworkService placeholder if defined elsewhere
 class NetworkService: NetworkServiceProtocol { 
     func get<T>(endpoint: String) async throws -> T where T : Decodable { fatalError("Not implemented") }
     func put<T>(endpoint: String, body: Data) async throws -> T where T : Decodable { fatalError("Not implemented") }
 }
 protocol NetworkServiceProtocol { 
     func get<T>(endpoint: String) async throws -> T where T : Decodable
     func put<T>(endpoint: String, body: Data) async throws -> T where T : Decodable
 }

