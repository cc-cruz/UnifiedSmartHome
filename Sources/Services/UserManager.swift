import Foundation
import Combine
import Models
import Helpers

public class UserManager: ObservableObject {
    @Published public var currentUser: User?
    @Published public var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    
    // Security settings
    var requiresBiometricConfirmation = false
    public var requiresBiometricConfirmationForUnlock = true
    
    // Computed property for login state
    var isLoggedIn: Bool {
        return isAuthenticated && currentUser != nil
    }
    
    private let apiService: APIService
    private let keychainHelper: Helpers.KeychainHelper
    private var cancellables = Set<AnyCancellable>()
    
    // Singleton instance
    static let shared = UserManager()
    
    public init(apiService: APIService = APIService(), keychainHelper: Helpers.KeychainHelper = Helpers.KeychainHelper()) {
        self.apiService = apiService
        self.keychainHelper = keychainHelper
        
        // Check for existing token on initialization
        checkToken()
    }
    
    // MARK: - Authentication Methods
    
    public func login(email: String, password: String) async {
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
    
    public func logout() async {
        // Clear token from Keychain - deleteItem doesn't throw
        _ = keychainHelper.deleteItem(for: "token") // Remove try, ignore result
        
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
    
    public func getUser(id: String) async -> User? {
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
    
    public func updateUserRole(userId: String, newRole: User.Role) async throws {
        // Check if current user has permission to change roles
        guard let currentUser = currentUser,
              (currentUser.role == .owner || currentUser.role == .propertyManager) else {
            throw SecurityError.insufficientPermissions
        }
        
        // Call API to update role
        try await apiService.updateUserRole(userId: userId, role: newRole.rawValue)
        
        // If updating the current user, refresh local state
        if userId == currentUser.id {
            // Create a new user object with the updated role
            let updatedUser = User(
                id: currentUser.id,
                email: currentUser.email,
                firstName: currentUser.firstName,
                lastName: currentUser.lastName,
                role: newRole, // Use the new role
                properties: currentUser.properties,
                assignedRooms: currentUser.assignedRooms,
                guestAccess: currentUser.guestAccess
            )
            await MainActor.run {
                // Assign the completely new user object
                self.currentUser = updatedUser
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveToken(token: String) {
        // Save token - saveData doesn't throw
        guard let tokenData = token.data(using: .utf8) else {
            print("Error: Could not convert token string to data")
            return
        }
        _ = keychainHelper.saveData(
            tokenData,
            for: "token"
        )
    }
    
    private func checkToken() {
        // Get token - getData doesn't throw
        let tokenData = keychainHelper.getData(
            for: "token"
        )
        
        if let tokenData = tokenData,
           let token = String(data: tokenData, encoding: .utf8) {
            // Token exists, validate with backend
            validateToken(token)
        }
    }
    
    private func validateToken(_ token: String) {
        isLoading = true
        
        apiService.validateToken(token: token)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure = completion {
                    // Token invalid, clear it - deleteItem doesn't throw
                    _ = self?.keychainHelper.deleteItem(for: "token") // Remove try?
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
public struct LoginCredentials: Codable {
    public let email: String
    public let password: String
    
    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

// Auth response model
public struct AuthResponse: Codable {
    public let user: User
    public let token: String
    
    public init(user: User, token: String) {
        self.user = user
        self.token = token
    }
} 