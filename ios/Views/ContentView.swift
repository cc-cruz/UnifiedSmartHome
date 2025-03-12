import SwiftUI

struct ContentView: View {
    @EnvironmentObject var thermostatViewModel: ThermostatViewModel
    @State private var selectedTab = 0
    
    var body: some View {
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