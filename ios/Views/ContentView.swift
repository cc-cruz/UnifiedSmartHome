import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                        .tag(0)
                    
                    DevicesView()
                        .tabItem {
                            Label("Devices", systemImage: "lightbulb.fill")
                        }
                        .tag(1)
                    
                    AutomationsView()
                        .tabItem {
                            Label("Automations", systemImage: "gear")
                        }
                        .tag(2)
                    
                    ActivityView()
                        .tabItem {
                            Label("Activity", systemImage: "chart.bar.fill")
                        }
                        .tag(3)
                    
                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        .tag(4)
                }
            } else {
                LoginView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
    }
} 