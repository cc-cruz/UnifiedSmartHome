import SwiftUI

@main
struct UnifiedSmartHomeApp: App {
    // Create the view models at the app level
    @StateObject private var thermostatViewModel = ThermostatViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(thermostatViewModel)
                .onOpenURL { url in
                    // Handle OAuth callback URLs
                    handleURL(url)
                }
                .onAppear {
                    // Display setup instructions in debug mode
                    #if DEBUG
                    checkConfiguration()
                    #endif
                }
        }
    }
    
    // Handle callback URLs (e.g., for OAuth)
    private func handleURL(_ url: URL) {
        if url.scheme == "unifiedsmarthome" {
            // This is our OAuth callback, no action needed here
            // The OAuth manager will handle extracting the code
        }
    }
    
    // Check if the app has been properly configured
    private func checkConfiguration() {
        let config = NestConfiguration()
        
        if config.clientID.contains("[YOUR_") || 
           config.clientSecret.contains("[YOUR_") || 
           config.projectID.contains("[YOUR_") {
            print("""
            ⚠️ SETUP REQUIRED: You need to configure your Nest API credentials
            
            1. Open Info.plist
            2. Replace the placeholder values:
               - NestClientID: Your Nest API client ID
               - NestClientSecret: Your Nest API client secret
               - NestProjectID: Your Nest API project ID
               
            Ensure you've set up the Google Smart Device Management API in 
            the Google Cloud Console and configured the OAuth consent screen.
            
            See the implementation guide documentation for more details.
            """)
        }
    }
} 