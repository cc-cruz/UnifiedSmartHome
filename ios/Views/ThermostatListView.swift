import SwiftUI

struct ThermostatListView: View {
    @StateObject var viewModel = ThermostatViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Content based on authentication and loading state
                if viewModel.isLoading {
                    ProgressView("Loading thermostats...")
                } else if !viewModel.nestOAuthManager.isAuthenticated {
                    authenticationView
                } else if viewModel.thermostats.isEmpty {
                    emptyStateView
                } else {
                    thermostatsListView
                }
            }
            .navigationTitle("Thermostats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Show refresh button if authenticated
                    if viewModel.nestOAuthManager.isAuthenticated {
                        Button {
                            viewModel.fetchThermostats()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .alert(isPresented: Binding<Bool>(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.error ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // View for when the user is not authenticated
    private var authenticationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "thermometer")
                .font(.system(size: 70))
                .foregroundColor(.blue)
            
            Text("Connect to Nest")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Link your Nest account to control your thermostats")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                viewModel.authenticateNest()
            } label: {
                Text("Connect to Nest")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 50)
            .padding(.top, 20)
        }
        .padding()
    }
    
    // View for when there are no thermostats
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "thermometer.slash")
                .font(.system(size: 70))
                .foregroundColor(.gray)
            
            Text("No Thermostats Found")
                .font(.title)
                .fontWeight(.bold)
            
            Text("No thermostats were found in your Nest account. Make sure your devices are set up correctly.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 15) {
                Button {
                    viewModel.fetchThermostats()
                } label: {
                    Text("Retry")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button {
                    viewModel.signOut()
                } label: {
                    Text("Sign Out")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 20)
        }
        .padding()
    }
    
    // List of thermostats
    private var thermostatsListView: some View {
        List {
            ForEach(viewModel.thermostats) { thermostat in
                NavigationLink(destination: ThermostatDetailView(viewModel: viewModel, thermostat: thermostat)) {
                    ThermostatRow(thermostat: thermostat)
                }
            }
        }
    }
}

// Row for each thermostat in the list
struct ThermostatRow: View {
    let thermostat: ThermostatDevice
    
    var body: some View {
        HStack {
            // Icon based on mode
            Image(systemName: iconName)
                .font(.system(size: 30))
                .foregroundColor(iconColor)
                .frame(width: 50, height: 50)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(thermostat.name)
                    .font(.headline)
                
                HStack {
                    Text("\(Int(thermostat.currentTemperature))°\(thermostat.units == .celsius ? "C" : "F")")
                        .font(.subheadline)
                    
                    Text("•")
                    
                    Text(modeText)
                        .font(.subheadline)
                        .foregroundColor(iconColor)
                }
            }
            
            Spacer()
            
            // Target temperature
            Text("\(Int(thermostat.targetTemperature))°")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 8)
    }
    
    // Icon based on thermostat mode
    private var iconName: String {
        switch thermostat.mode {
        case .heat:
            return "flame.fill"
        case .cool:
            return "snowflake"
        case .auto:
            return "thermometer"
        case .eco:
            return "leaf.fill"
        case .off:
            return "power"
        }
    }
    
    // Color based on thermostat mode
    private var iconColor: Color {
        switch thermostat.mode {
        case .heat:
            return .orange
        case .cool:
            return .blue
        case .auto:
            return .purple
        case .eco:
            return .green
        case .off:
            return .gray
        }
    }
    
    // Text representation of mode
    private var modeText: String {
        switch thermostat.mode {
        case .heat:
            return "Heating"
        case .cool:
            return "Cooling"
        case .auto:
            return "Auto"
        case .eco:
            return "Eco"
        case .off:
            return "Off"
        }
    }
}

struct ThermostatListView_Previews: PreviewProvider {
    static var previews: some View {
        ThermostatListView()
    }
} 