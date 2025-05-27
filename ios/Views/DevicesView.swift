import SwiftUI

struct DevicesView: View {
    @StateObject private var viewModel: DevicesViewModel
    @EnvironmentObject var userContextViewModel: UserContextViewModel
    @StateObject private var thermostatViewModel = ThermostatViewModel()
    
    @State private var searchText = ""
    @State private var selectedFilter: DeviceFilter = .all
    
    enum DeviceFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case lights = "Lights"
        case thermostats = "Thermostats"
        case locks = "Locks"
        case cameras = "Cameras"
        
        var id: String { self.rawValue }
    }
    
    init(deviceService: DeviceService, userManager: UserManager, userContextViewModel: UserContextViewModel) {
        _viewModel = StateObject(wrappedValue: DevicesViewModel(
            deviceService: deviceService, 
            userManager: userManager, 
            userContextViewModel: userContextViewModel
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Filter by category
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(DeviceFilter.allCases) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Content based on selected filter
                if selectedFilter == .thermostats {
                    // Show thermostat-specific view
                    thermostatContent
                } else {
                    // Show regular device list
                    deviceListContent
                }
            }
            .navigationTitle(viewModel.currentContextName)
            .searchable(text: $searchText, prompt: "Search devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.canAddDeviceInCurrentContext {
                        Button(action: {
                            print("Add device tapped in context: \(viewModel.currentContextName)")
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.fetchDevices()
                }
            }
        }
        .environmentObject(userContextViewModel)
    }
    
    // Thermostat-specific view
    private var thermostatContent: some View {
        VStack {
            // Header for thermostats section
            HStack {
                Text("Thermostats")
                    .font(.headline)
                
                Spacer()
                
                if thermostatViewModel.nestOAuthManager.isAuthenticated {
                    Button {
                        thermostatViewModel.fetchThermostats()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                } else {
                    Button {
                        thermostatViewModel.authenticateNest()
                    } label: {
                        Text("Connect Nest")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Content based on authentication and loading state
            if thermostatViewModel.isLoading {
                ProgressView("Loading thermostats...")
                    .padding()
            } else if thermostatViewModel.nestOAuthManager.isAuthenticated && thermostatViewModel.thermostats.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "thermometer.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No thermostats found")
                        .font(.headline)
                    
                    Text("No Nest thermostats were discovered on your account")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button {
                        thermostatViewModel.fetchThermostats()
                    } label: {
                        Text("Refresh")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
            } else if !thermostatViewModel.nestOAuthManager.isAuthenticated {
                // Not authenticated state is handled by the connect button in the header
                Text("Connect your Nest account to see and control your thermostats")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                // List of thermostats
                List {
                    ForEach(thermostatViewModel.thermostats) { thermostat in
                        NavigationLink(destination: ThermostatDetailView(viewModel: thermostatViewModel, thermostat: thermostat)) {
                            ThermostatRow(thermostat: thermostat)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            
            Spacer()
        }
        .alert(isPresented: Binding<Bool>(
            get: { thermostatViewModel.error != nil },
            set: { if !$0 { thermostatViewModel.error = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(thermostatViewModel.error ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Regular device list view
    private var deviceListContent: some View {
        Group {
            if viewModel.devicesState.isLoading && viewModel.devicesState.data == nil {
                ProgressView("Loading devices...")
            } else if let error = viewModel.devicesState.error, viewModel.devicesState.data == nil {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Error loading devices in \(viewModel.currentContextName)")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    Button("Try Again") { Task { await viewModel.fetchDevices() } }.buttonStyle(.bordered)
                }
            } else if viewModel.groupedDevices.isEmpty && !viewModel.devicesState.isLoading {
                 VStack(spacing: 16) {
                    Image(systemName: "questionmark.folder")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No devices found in \(viewModel.currentContextName)")
                        .font(.headline)
                    Text(viewModel.canAddDeviceInCurrentContext ? "You can add a new device here." : "Check back later or contact support.")
                        .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    if viewModel.canAddDeviceInCurrentContext {
                        Button("Add Device") { /* Add device action */ }.buttonStyle(.borderedProminent)
                    }
                }
            } else {
                List {
                    ForEach(viewModel.groupedDevices) { group in
                        Section(header: Text(group.name)) {
                            ForEach(group.devices, id: \.id) { device in
                                NavigationLink(destination: destinationForDevice(device)) {
                                    DeviceListItem(
                                        name: device.name,
                                        type: String(describing: type(of: device)),
                                        isOnline: device.status == .online
                                    )
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .refreshable {
            await viewModel.fetchDevices()
        }
    }

    @ViewBuilder
    private func destinationForDevice(_ device: AbstractDevice) -> some View {
        if let lock = device as? LockDevice {
            Text("Lock Detail for \(lock.name)")
        } else if let thermostat = device as? ThermostatDevice {
            ThermostatDetailView(viewModel: thermostatViewModel, thermostat: thermostat)
        } else {
            Text("Detail view for \(device.name) (Type: \(String(describing: type(of: device))))")
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct DeviceListItem: View {
    let name: String
    let type: String
    let isOnline: Bool
    
    var body: some View {
        HStack {
            Image(systemName: iconForType(type))
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                
                Text(type)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack {
                Circle()
                    .fill(isOnline ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                
                Text(isOnline ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundColor(isOnline ? .green : .red)
            }
        }
        .padding(.vertical, 8)
    }
    
    func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "light": return "lightbulb.fill"
        case "thermostat": return "thermometer"
        case "lock": return "lock.fill"
        case "camera": return "video.fill"
        case "speaker": return "speaker.wave.2.fill"
        case "tv": return "tv.fill"
        case "appliance": return "button.programmable"
        case "fan": return "fan.ceiling.fill"
        default: return "square.fill"
        }
    }
}

/*
// Preview Provider for DevicesView
// This will require providing mock/stub implementations for DeviceService, UserManager,
// and UserContextViewModel if you want previews to work, as their initializers need concrete instances.
// Alternatively, for complex views, previews might be omitted or use a simpler setup.

struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        // Example with placeholder initializers (these would need to be actual or mock classes)
        // class MockDeviceService: DeviceService { /* ... */ }
        // class MockUserManager: UserManager { /* ... */ }
        // class MockUserContextViewModel: UserContextViewModel { /* ... */ }
        
        // let mockDeviceService = MockDeviceService(adapters: [], userManager: MockUserManager(), apiService: APIService(), userContextViewModel: MockUserContextViewModel())
        // let mockUserManager = MockUserManager(apiService: APIService(), keychainHelper: Helpers.KeychainHelper())
        // let mockUserContext = MockUserContextViewModel()

        // DevicesView(
        //     deviceService: mockDeviceService, 
        //     userManager: mockUserManager, 
        //     userContextViewModel: mockUserContext
        // )
        // .environmentObject(mockUserContext) // Also provide UserContextViewModel as an environment object
        // .environmentObject(mockUserManager) // If UserManager is also used as EnvObject anywhere

        // Simplified: If you cannot easily mock, you might need to remove the preview for this view
        // or create a very basic version of the view for preview purposes.
        Text("DevicesView Preview (Requires Dependency Injection Setup)")
    }
} 
*/ 