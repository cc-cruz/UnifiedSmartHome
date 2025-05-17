import SwiftUI

struct ContentView: View {
    @EnvironmentObject var thermostatViewModel: ThermostatViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var userContext: UserContextViewModel
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var propertyViewModel = PropertyViewModel()
    @StateObject private var unitViewModel = UnitViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        // If not authenticated, show login
        if !authViewModel.isAuthenticated {
            LoginView()
                .environmentObject(authViewModel)
        } else if needsRoleSelection {
            RoleSelectionView()
                .environmentObject(authViewModel)
                .environmentObject(userContext)
        } else if needsPortfolioSelection {
            PortfolioListView(viewModel: portfolioViewModel)
                .environmentObject(userContext)
                .environmentObject(authViewModel)
        } else if needsPropertySelection {
            PropertyListView(viewModel: propertyViewModel)
                .environmentObject(userContext)
        } else if needsUnitSelection {
            UnitListView(viewModel: unitViewModel)
                .environmentObject(userContext)
        } else {
            TabView(selection: $selectedTab) {
                // Home tab
                NavigationView {
                    HomeView()
                }
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
                
                // Devices tab (includes thermostats)
                NavigationView {
                    DevicesView()
                }
                .tabItem {
                    Label("Devices", systemImage: "slider.horizontal.3")
                }
                .tag(1)
                
                // Thermostats tab
                NavigationView {
                    ThermostatListView(viewModel: thermostatViewModel)
                }
                .tabItem {
                    Label("Thermostats", systemImage: "thermometer")
                }
                .tag(2)
                
                // Settings tab
                NavigationView {
                    SettingsView(isAuthenticated: thermostatViewModel.nestOAuthManager.isAuthenticated,
                                authenticate: { thermostatViewModel.authenticateNest() },
                                signOut: { thermostatViewModel.signOut() })
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
            }
            .accentColor(.blue)
        }
    }
    
    var needsRoleSelection: Bool {
        guard let user = authViewModel.currentUser else { return false }
        let roles = Set(user.roleAssociations?.map { $0.roleWithinEntity } ?? [])
        return roles.count > 1 && userContext.selectedRole == nil
    }
    
    var needsPortfolioSelection: Bool {
        // Show if user has more than one portfolio and hasn't selected one
        guard let user = authViewModel.currentUser, let role = userContext.selectedRole else { return false }
        let portfolios = portfolioViewModel.portfolios
        return portfolios.count > 1 && userContext.selectedPortfolioId == nil
    }
    
    var needsPropertySelection: Bool {
        // Show if properties loaded count > 1; if exactly 1 auto-select
        guard userContext.selectedPortfolioId != nil else { return false }
        let count = propertyViewModel.properties.count
        if count == 1, userContext.selectedPropertyId == nil {
            // Auto-select single property
            if let onlyId = propertyViewModel.properties.first?.id {
                userContext.selectedPropertyId = onlyId
                propertyViewModel.selectProperty(onlyId)
            }
        }
        return count > 1 && userContext.selectedPropertyId == nil
    }
    
    var needsUnitSelection: Bool {
        guard userContext.selectedPropertyId != nil else { return false }
        let count = unitViewModel.units.count
        if count == 1, userContext.selectedUnitId == nil {
            if let onlyId = unitViewModel.units.first?.id {
                userContext.selectedUnitId = onlyId
                unitViewModel.selectUnit(onlyId)
            }
        }
        return count > 1 && userContext.selectedUnitId == nil
    }
}

struct HomeView: View {
    var body: some View {
        VStack {
            Text("Welcome to Unified Smart Home")
                .font(.title)
                .multilineTextAlignment(.center)
                .padding()
            
            Text("Control all your smart devices from one place")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Home")
    }
}

struct SettingsView: View {
    let isAuthenticated: Bool
    let authenticate: () -> Void
    let signOut: () -> Void
    
    var body: some View {
        List {
            Section(header: Text("Account")) {
                if isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected to Nest")
                        Spacer()
                        Button("Disconnect") {
                            signOut()
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Nest Account")
                        Spacer()
                        Button("Connect") {
                            authenticate()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link(destination: URL(string: "https://unifiedsmarthome.example.com/privacy")!) {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                    }
                }
                
                Link(destination: URL(string: "https://unifiedsmarthome.example.com/terms")!) {
                    HStack {
                        Text("Terms of Service")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ThermostatViewModel())
    }
} 