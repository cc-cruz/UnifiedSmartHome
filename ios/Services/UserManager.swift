import Foundation
import Combine

class UserManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    
    // Security settings
    var requiresBiometricConfirmation = false
    var requiresBiometricConfirmationForUnlock = true
    
    // Computed property for login state
    var isLoggedIn: Bool {
        return isAuthenticated && currentUser != nil
    }
    
    private let apiService: APIService
    private let keychainHelper: KeychainHelper
    private var cancellables = Set<AnyCancellable>()
    
    // Singleton instance
    static let shared = UserManager()
    
    private init(apiService: APIService = APIService(), keychainHelper: KeychainHelper = KeychainHelper()) {
        self.apiService = apiService
        self.keychainHelper = keychainHelper
        
        // Check for existing token on initialization
        checkToken()
    }
    
    // MARK: - Authentication Methods
    
    func login(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        let credentials = LoginCredentials(email: email, password: password)
        
        do {
            // Convert the Combine publisher to async/await
            let authResponse = try await withCheckedThrowingContinuation { continuation in
                apiService.login(with: credentials)
                    .sink { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    } receiveValue: { response in
                        continuation.resume(returning: response)
                    }
                    .store(in: &cancellables)
            }
            
            // Save token and update state
            saveToken(token: authResponse.token)
            
            await MainActor.run {
                self.currentUser = authResponse.user
                self.isAuthenticated = true
                self.isLoading = false
            }
            
            // Log analytics event
            AnalyticsService.shared.logEvent("user_login", parameters: [
                "user_id": authResponse.user.id,
                "user_role": authResponse.user.role.rawValue
            ])
            
            // Set user ID for analytics
            AnalyticsService.shared.setUserID(authResponse.user.id)
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func logout() async {
        // Clear token from Keychain
        do {
            try keychainHelper.delete(service: "com.smarthome.auth", account: "token")
        } catch {
            print("Error deleting token: \(error.localizedDescription)")
        }
        
        // Log analytics event
        if let userId = currentUser?.id {
            AnalyticsService.shared.logEvent("user_logout", parameters: [
                "user_id": userId
            ])
        }
        
        // Reset state
        await MainActor.run {
            isAuthenticated = false
            currentUser = nil
        }
        
        // Clear user ID from analytics
        AnalyticsService.shared.setUserID("")
    }
    
    // MARK: - User Management Methods
    
    func getUser(id: String) async -> User? {
        // In a real implementation, this would fetch from the API
        // For now, just return the current user if IDs match
        if let currentUser = currentUser, currentUser.id == id {
            return currentUser
        }
        
        // Otherwise, fetch from API
        do {
            return try await apiService.getUser(id: id)
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateUserRole(userId: String, newRole: User.Role) async throws {
        // Check if current user has permission to change roles
        guard let currentUser = currentUser,
              (currentUser.role == .owner || currentUser.role == .propertyManager) else {
            throw SecurityError.insufficientPermissions
        }
        
        // Call API to update role
        try await apiService.updateUserRole(userId: userId, role: newRole.rawValue)
        
        // If updating the current user, refresh local state
        if userId == currentUser.id {
            var updatedUser = currentUser
            updatedUser.role = newRole
            await MainActor.run {
                self.currentUser = updatedUser
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveToken(token: String) {
        do {
            try keychainHelper.save(
                token.data(using: .utf8)!,
                service: "com.smarthome.auth",
                account: "token"
            )
        } catch {
            print("Error saving token: \(error.localizedDescription)")
        }
    }
    
    private func checkToken() {
        do {
            let tokenData = try keychainHelper.get(
                service: "com.smarthome.auth",
                account: "token"
            )
            
            if let tokenData = tokenData,
               let token = String(data: tokenData, encoding: .utf8) {
                // Token exists, validate with backend
                validateToken(token)
            }
        } catch {
            // No token found or error retrieving it
            isAuthenticated = false
        }
    }
    
    private func validateToken(_ token: String) {
        isLoading = true
        
        apiService.validateToken(token: token)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure = completion {
                    // Token invalid, clear it
                    try? self?.keychainHelper.delete(service: "com.smarthome.auth", account: "token")
                    self?.isAuthenticated = false
                }
            } receiveValue: { [weak self] user in
                self?.currentUser = user
                self?.isAuthenticated = true
                
                // Set user ID for analytics
                AnalyticsService.shared.setUserID(user.id)
            }
            .store(in: &cancellables)
    }
}

// Login credentials model
struct LoginCredentials: Codable {
    let email: String
    let password: String
}

// Auth response model
struct AuthResponse: Codable {
    let user: User
    let token: String
} 