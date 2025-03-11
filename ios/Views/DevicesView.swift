import SwiftUI

struct DevicesView: View {
    @State private var searchText = ""
    @State private var selectedFilter: DeviceFilter = .all
    @StateObject private var thermostatViewModel = ThermostatViewModel()
    
    enum DeviceFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case lights = "Lights"
        case thermostats = "Thermostats"
        case locks = "Locks"
        case cameras = "Cameras"
        
        var id: String { self.rawValue }
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
            .navigationTitle("Devices")
            .searchable(text: $searchText, prompt: "Search devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Add device action
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
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
        List {
            // Room section
            Section(header: Text("Living Room")) {
                DeviceListItem(name: "Smart TV", type: "TV", isOnline: true)
                DeviceListItem(name: "Ceiling Light", type: "Light", isOnline: true)
                
                // Show thermostats if we have any and we're not filtering them out
                if selectedFilter == .all {
                    ForEach(thermostatViewModel.thermostats.filter { $0.name.contains("Living") }) { thermostat in
                        NavigationLink(destination: ThermostatDetailView(viewModel: thermostatViewModel, thermostat: thermostat)) {
                            DeviceListItem(
                                name: thermostat.name,
                                type: "Thermostat",
                                isOnline: thermostat.status == .online
                            )
                        }
                    }
                }
                
                if thermostatViewModel.thermostats.isEmpty && (selectedFilter == .all || selectedFilter == .thermostats) {
                    DeviceListItem(name: "Air Conditioner", type: "Thermostat", isOnline: true)
                }
            }
            
            Section(header: Text("Kitchen")) {
                DeviceListItem(name: "Refrigerator", type: "Appliance", isOnline: true)
                DeviceListItem(name: "Microwave", type: "Appliance", isOnline: false)
                DeviceListItem(name: "Coffee Maker", type: "Appliance", isOnline: true)
                
                // Show thermostats if we have any and we're not filtering them out
                if selectedFilter == .all {
                    ForEach(thermostatViewModel.thermostats.filter { $0.name.contains("Kitchen") }) { thermostat in
                        NavigationLink(destination: ThermostatDetailView(viewModel: thermostatViewModel, thermostat: thermostat)) {
                            DeviceListItem(
                                name: thermostat.name,
                                type: "Thermostat",
                                isOnline: thermostat.status == .online
                            )
                        }
                    }
                }
            }
            
            Section(header: Text("Bedroom")) {
                DeviceListItem(name: "Ceiling Fan", type: "Fan", isOnline: true)
                DeviceListItem(name: "Bedside Lamp", type: "Light", isOnline: true)
                DeviceListItem(name: "Smart Speaker", type: "Speaker", isOnline: true)
                
                // Show thermostats if we have any and we're not filtering them out
                if selectedFilter == .all {
                    ForEach(thermostatViewModel.thermostats.filter { $0.name.contains("Bedroom") }) { thermostat in
                        NavigationLink(destination: ThermostatDetailView(viewModel: thermostatViewModel, thermostat: thermostat)) {
                            DeviceListItem(
                                name: thermostat.name,
                                type: "Thermostat",
                                isOnline: thermostat.status == .online
                            )
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .onAppear {
            // Attempt to fetch thermostats when the view appears
            if thermostatViewModel.nestOAuthManager.isAuthenticated && thermostatViewModel.thermostats.isEmpty {
                thermostatViewModel.fetchThermostats()
            }
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

struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        DevicesView()
    }
} 