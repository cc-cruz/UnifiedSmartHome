import SwiftUI

@main
struct UnifiedSmartHomeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AuthViewModel())
        }
    }
} 