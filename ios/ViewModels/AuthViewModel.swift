import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    
    private var apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService = APIService()) {
        self.apiService = apiService
        checkToken()
    }
    
    func login(email: String, password: String) {
        isLoading = true
        error = nil
        
        let credentials = LoginCredentials(email: email, password: password)
        
        apiService.login(with: credentials)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.currentUser = response.user
                self?.saveToken(token: response.token)
                self?.isAuthenticated = true
            }
            .store(in: &cancellables)
    }
    
    func logout() {
        // Clear token from UserDefaults
        UserDefaults.standard.removeObject(forKey: "authToken")
        
        // Reset state
        isAuthenticated = false
        currentUser = nil
    }
    
    private func saveToken(token: String) {
        UserDefaults.standard.set(token, forKey: "authToken")
    }
    
    private func checkToken() {
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            // TODO: Validate token with backend
            // For now, just set as authenticated if token exists
            isAuthenticated = true
        }
    }
} 