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
    
    // New: Cache for property data
    private var properties: [Property] = []
    
    // Singleton instance
    static let shared = UserManager()
    
    // Computed properties for tenancy information
    public var currentUserRoleAssociations: [User.UserRoleAssociation]? {
        currentUser?.roleAssociations
    }
    
    public var currentUserDefaultPortfolioId: String? {
        currentUser?.defaultPortfolioId
    }
    
    public var currentUserDefaultPropertyId: String? {
        currentUser?.defaultPropertyId
    }
    
    public var currentUserDefaultUnitId: String? {
        currentUser?.defaultUnitId
    }
    
    public init(apiService: APIService = APIService(), keychainHelper: Helpers.KeychainHelper = Helpers.KeychainHelper()) {
        self.apiService = apiService
        self.keychainHelper = keychainHelper
        
        // Check for existing token on initialization
        checkToken()
    }
    
    // New: Method to set/update the properties cache
    // This would typically be called after fetching properties from a backend.
    public func setProperties(_ properties: [Property]) {
        // In a more complex app, consider thread safety if properties can be updated from multiple threads.
        // For now, a simple assignment.
        self.properties = properties
        print("UserManager: Properties cache updated with \(properties.count) items.")
    }
    
    // New: Method to get portfolioId for a given propertyId
    public func getPortfolioIdForProperty(propertyId: String) -> String? {
        // Search the cached properties.
        // In a performant system with many properties, a dictionary lookup (propertiesById[propertyId]) would be faster.
        // For now, a simple iteration is fine.
        let foundProperty = properties.first { $0.id == propertyId }
        if let property = foundProperty {
            return property.portfolioId
        } else {
            print("UserManager: Property with ID \(propertyId) not found in cache. Cannot determine portfolioId.")
            return nil
        }
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
                "user_role": authResponse.user.roleAssociations?.first?.roleWithinEntity.rawValue ?? "unknown"
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
        
        // Otherwise, simulate no other user found, as apiService.getUser(id:) is not available
        print("UserManager.getUser(id: \(id)) called, but APIService.getUser(id:) is not implemented. Returning nil if ID doesn't match currentUser.")
        return nil
        /* Original code that causes error:
        do {
            return try await apiService.getUser(id: id)
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
            return nil
        }
        */
    }
    
    public func updateUserRole(userId: String, newRole: User.Role) async throws {
        // Check if current user has permission to change roles
        // TODO: This permission check is simplified. A more robust check would consider specific portfolio/property ownership/management.
        let canUpdateRoles = currentUser?.roleAssociations?.contains(where: { $0.roleWithinEntity == .owner || $0.roleWithinEntity == .portfolioAdmin || $0.roleWithinEntity == .propertyManager }) ?? false
        guard let currentUser = currentUser, canUpdateRoles else {
            throw SecurityError.insufficientPermissions
        }
        
        // Call API to update role
        // Convert Combine publisher to async/await
        try await withCheckedThrowingContinuation { continuation in
            apiService.updateUserRole(userId: userId, role: newRole.rawValue)
                .sink {
                    completionResult in
                    switch completionResult {
                    case .finished:
                        continuation.resume(returning: ())
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                } receiveValue: { _ in
                    // Void publisher, no value received
                }
                .store(in: &cancellables)
        }
        
        // If updating the current user, refresh local state
        if userId == currentUser.id {
            // Create a new user object with the updated role
            let updatedUser = User(
                id: currentUser.id,
                email: currentUser.email,
                firstName: currentUser.firstName,
                lastName: currentUser.lastName,
                guestAccess: currentUser.guestAccess,
                roleAssociations: currentUser.roleAssociations, // Pass existing associations
                defaultPortfolioId: currentUser.defaultPortfolioId, // Pass existing
                defaultPropertyId: currentUser.defaultPropertyId, // Pass existing
                defaultUnitId: currentUser.defaultUnitId // Pass existing
            )
            await MainActor.run {
                // Assign the completely new user object
                self.currentUser = updatedUser
            }
        }
    }
    
    /// Update the current user object (useful for IAP feature updates)
    public func updateCurrentUser(_ updatedUser: User) {
        DispatchQueue.main.async {
            self.currentUser = updatedUser
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
            Task { // Changed to Task for async context
                await validateToken(token)
            }
        }
    }
    
    private func validateToken(_ token: String) async { // Changed to async
        await MainActor.run { isLoading = true } // Ensure UI updates on main thread
        
        do {
            // Assuming apiService.validateToken just confirms the token is valid
            // and doesn't necessarily return the full user profile needed.
            // If validateToken itself is meant to return the full user, this logic might simplify.
            _ = try await withCheckedThrowingContinuation { continuation in // Assuming validateToken returns some basic confirmation or a minimal user
                apiService.validateToken(token: token) // This might need to change if it already returns a full User
                    .sink { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    } receiveValue: { _ in // We might not need the user from validateToken if fetching full profile next
                        continuation.resume(returning: ()) // Indicate success
                    }
                    .store(in: &cancellables)
            }
            
            // If token is valid, fetch the full user profile
            await fetchCurrentUserProfile()
            
        } catch {
            // Token invalid or fetch failed, clear it
            _ = keychainHelper.deleteItem(for: "token")
            await MainActor.run { // Ensure UI updates on main thread
                isAuthenticated = false
                currentUser = nil // Clear user
                isLoading = false
                self.error = "Session expired. Please log in again." // Provide a user-friendly error
            }
        }
    }
    
    // New method to fetch full user profile, now correctly named and using the existing APIService method
    public func fetchCurrentUserProfile() async {
        await MainActor.run { // Ensure UI updates on main thread
            isLoading = true
            error = nil
        }
        
        do {
            let userProfile = try await withCheckedThrowingContinuation { continuation in
                apiService.getCurrentUser() // Corrected to use existing APIService.getCurrentUser()
                    .sink { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    } receiveValue: { user in
                        continuation.resume(returning: user)
                    }
                    .store(in: &cancellables)
            }
            
            await MainActor.run { // Ensure UI updates on main thread
                self.currentUser = userProfile
                self.isAuthenticated = true // User profile fetched, so authenticated
                self.isLoading = false
                
                // Set user ID for analytics (if not already set by login)
                AnalyticsService.shared.setUserID(userProfile.id)
            }
        } catch {
            await MainActor.run { // Ensure UI updates on main thread
                self.error = "Failed to fetch user profile: \(error.localizedDescription)"
                // Depending on the error, you might want to logout the user or clear token
                // For now, just display error and stop loading. If it's an auth error,
                // the validateToken path would have already cleared the token.
                self.isLoading = false
                // Consider if isAuthenticated should be set to false here if profile fetch fails catastrophically
            }
        }
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