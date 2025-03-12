import SwiftUI

struct ThermostatListView: View {
    @ObservedObject var viewModel: ThermostatViewModel
    @State private var temperatureUnit: TemperatureUnit = .celsius
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.thermostats.isEmpty {
                    // Show loading indicator when initially loading
                    VStack {
                        ProgressView("Loading thermostats...")
                        
                        if let error = viewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                                .multilineTextAlignment(.center)
                        }
                    }
                } else if viewModel.thermostats.isEmpty {
                    // Show empty state
                    VStack(spacing: 20) {
                        Image(systemName: "thermometer")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Thermostats Found")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        if let error = viewModel.error {
                            ErrorView(errorMessage: error)
                                .padding(.horizontal, 40)
                        } else {
                            Text("Connect your Nest account to see your thermostats")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Button(action: {
                            viewModel.authenticateNest()
                        }) {
                            Label("Connect Nest Account", systemImage: "link")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.horizontal, 40)
                        }
                        
                        // If already authenticated, add a refresh button
                        if viewModel.nestOAuthManager.isAuthenticated {
                            Button(action: {
                                viewModel.fetchThermostats()
                            }) {
                                Label("Refresh Devices", systemImage: "arrow.clockwise")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .padding(.horizontal, 40)
                            }
                        }
                    }
                    .padding()
                } else {
                    // Show thermostat list
                    ScrollView {
                        VStack(spacing: 16) {
                            // Unit selector
                            HStack {
                                Text("Temperature Unit:")
                                Picker("Temperature Unit", selection: $temperatureUnit) {
                                    Text("Celsius").tag(TemperatureUnit.celsius)
                                    Text("Fahrenheit").tag(TemperatureUnit.fahrenheit)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            // Error banner
                            if let error = viewModel.error {
                                ErrorView(errorMessage: error)
                                    .padding(.horizontal)
                            }
                            
                            // Thermostat list
                            ForEach(viewModel.thermostats, id: \.id) { thermostat in
                                NavigationLink(destination: ThermostatDetailView(viewModel: viewModel, thermostat: thermostat)) {
                                    ThermostatCard(thermostat: thermostat, unit: temperatureUnit)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Refresh button at the bottom
                            Button(action: {
                                viewModel.fetchThermostats()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Refresh")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                            .padding(.bottom)
                            
                            // Loading indicator when refreshing
                            if viewModel.isLoading {
                                LoadingView()
                            }
                        }
                        .padding(.vertical)
                    }
                    .navigationTitle("Thermostats")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                viewModel.signOut()
                            }) {
                                Text("Disconnect")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Thermostats")
            .onAppear {
                // On first appear, attempt to fetch thermostats if authenticated
                if viewModel.nestOAuthManager.isAuthenticated && viewModel.thermostats.isEmpty {
                    viewModel.fetchThermostats()
                }
            }
            .refreshable {
                // Pull to refresh
                viewModel.fetchThermostats()
            }
        }
    }
}

struct ThermostatCard: View {
    let thermostat: ThermostatDevice
    let unit: TemperatureUnit
    
    var body: some View {
        HStack(spacing: 16) {
            // Mode icon
            ZStack {
                Circle()
                    .fill(modeColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: thermostat.mode.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(modeColor)
            }
            
            // Thermostat info
            VStack(alignment: .leading, spacing: 4) {
                Text(thermostat.name)
                    .font(.headline)
                
                Text("Current: \(thermostat.formattedTemperature(thermostat.currentTemperature, unit: unit))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Target: \(thermostat.formattedTemperature(thermostat.targetTemperature, unit: unit))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Mode: \(thermostat.mode.displayName)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(modeColor.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Navigation indicator
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 3)
    }
    
    private var modeColor: Color {
        switch thermostat.mode {
        case .heat:
            return .orange
        case .cool:
            return .blue
        case .auto:
            return .purple
        case .off:
            return .gray
        }
    }
}

struct ThermostatListView_Previews: PreviewProvider {
    static var previews: some View {
        ThermostatListView(viewModel: ThermostatViewModel())
    }
} 