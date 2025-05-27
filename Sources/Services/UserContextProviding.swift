import Foundation
import Combine // For ObservableObject and potentially @Published if needed in protocol

/// Protocol to provide user context information needed by services.
public protocol UserContextProviding: ObservableObject {
    var selectedPropertyId: String? { get }
    var selectedUnitId: String? { get }
    // Add other properties from UserContextViewModel that DeviceService specifically needs, e.g.:
    // var selectedPortfolioId: String? { get }
    // var selectedRole: Models.User.Role? { get }
} 