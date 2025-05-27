import Foundation
import Combine
import Sources.Models
import Models

public class UserContextViewModel: ObservableObject, UserContextInterface {
    @Published public var selectedRole: Models.User.Role? = nil
    @Published public var selectedPortfolioId: String? = nil
    @Published public var selectedPropertyId: String? = nil
    @Published public var selectedUnitId: String? = nil
    
    public func reset() {
        selectedRole = nil
        selectedPortfolioId = nil
        selectedPropertyId = nil
        selectedUnitId = nil
    }
} 