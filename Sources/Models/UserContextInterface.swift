import Foundation
import Combine // For ObservableObject if the protocol itself needs to be an ObservableObject

/// Protocol defining the interface for providing user context information.
/// This allows services to depend on an abstraction rather than a concrete ViewModel type.
public protocol UserContextInterface: AnyObject, ObservableObject { // Explicitly add AnyObject
    var selectedPropertyId: String? { get }
    var selectedUnitId: String? { get }
    // Add any other properties from UserContextViewModel that DeviceService needs access to.
    // For example:
    // var selectedPortfolioId: String? { get }
    // var selectedRole: User.Role? { get }
} 