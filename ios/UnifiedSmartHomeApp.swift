import SwiftUI

@main
struct UnifiedSmartHomeApp: App {
    // Initialize view models at app level to maintain state
    @StateObject private var lockViewModel = createMockLockViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainTabView(lockViewModel: lockViewModel)
                .onAppear {
                    // Setup any app-wide configurations here
                    setupAppearance()
                }
        }
    }
    
    private func setupAppearance() {
        // Configure global UI appearance
        UINavigationBar.appearance().tintColor = .systemBlue
    }
    
    // Create a mock LockViewModel for testing
    private static func createMockLockViewModel() -> LockViewModel {
        // Create dependencies
        let networkService = NetworkService()
        let keychainHelper = KeychainHelper.shared
        let tokenManager = AugustTokenManager(keychainHelper: keychainHelper, networkService: networkService)
        let augustAdapter = AugustLockAdapter(networkService: networkService, tokenManager: tokenManager)
        
        let auditLogger = AuditLogger(
            analyticsService: AnalyticsService.shared,
            persistentStorage: CoreDataAuditLogStorage()
        )
        
        let securityService = SecurityService(
            userManager: UserManager.shared,
            auditLogger: auditLogger
        )
        
        let lockDAL = LockDAL(
            lockAdapter: augustAdapter,
            securityService: securityService,
            auditLogger: auditLogger
        )
        
        // Create and return the view model
        return LockViewModel(
            lockAdapter: augustAdapter,
            lockDAL: lockDAL,
            userManager: UserManager.shared,
            analyticsService: AnalyticsService.shared
        )
    }
}

struct MainTabView: View {
    @ObservedObject var lockViewModel: LockViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Locks tab
            NavigationView {
                LockListView(viewModel: lockViewModel)
                    .navigationTitle("Locks")
            }
            .tabItem {
                Label("Locks", systemImage: "lock.fill")
            }
            .tag(0)
            
            // Dashboard tab (placeholder)
            NavigationView {
                Text("Dashboard Coming Soon")
                    .navigationTitle("Dashboard")
            }
            .tabItem {
                Label("Dashboard", systemImage: "square.grid.2x2")
            }
            .tag(1)
            
            // Settings tab (placeholder)
            NavigationView {
                SettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(2)
        }
    }
}

// Simple placeholder for Settings view
struct SettingsView: View {
    @State private var isLoggedIn = UserManager.shared.isLoggedIn
    
    var body: some View {
        List {
            Section(header: Text("Account")) {
                if isLoggedIn {
                    Button("Log Out") {
                        Task {
                            await UserManager.shared.logout()
                            isLoggedIn = UserManager.shared.isLoggedIn
                        }
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Log In") {
                        // In a real app, this would show a login screen
                        Task {
                            // Simulate login for demo purposes
                            await UserManager.shared.login(email: "demo@example.com", password: "password")
                            isLoggedIn = UserManager.shared.isLoggedIn
                        }
                    }
                }
            }
            
            Section(header: Text("Preferences")) {
                Toggle("Dark Mode", isOn: .constant(false))
                Toggle("Notifications", isOn: .constant(true))
                Toggle("Biometric Authentication", isOn: .constant(true))
            }
            
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
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
    }
} 