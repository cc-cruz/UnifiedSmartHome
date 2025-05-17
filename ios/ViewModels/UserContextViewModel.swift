import Foundation
import Combine
import Sources.Models

class UserContextViewModel: ObservableObject {
    @Published var selectedRole: User.Role? = nil
    @Published var selectedPortfolioId: String? = nil
    @Published var selectedPropertyId: String? = nil
    @Published var selectedUnitId: String? = nil
    
    func reset() {
        selectedRole = nil
        selectedPortfolioId = nil
        selectedPropertyId = nil
        selectedUnitId = nil
    }
} 