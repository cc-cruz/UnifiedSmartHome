import Foundation
import Combine
import SwiftUI // Required for EnvironmentObject
import Sources.Models // Ensure models are accessible

// Assuming LoadingState is defined globally or accessible. If not, redefine here.
// TODO: This LoadingState enum is also used by LockViewModel.swift.
// Ensure it's defined in a shared location (e.g., Utils.swift or a shared ViewModels module) to avoid duplication if not already.
// enum LoadingState<T> { ... } 

class DevicesViewModel: ObservableObject {
    // Published properties
    @Published var devicesState: LoadingState<[AbstractDevice]> = .idle
    @Published var currentContextDebugDescription: String = "Context: N/A"

    // Dependencies
    private let deviceService: DeviceService
    private let userManager: UserManager
    private let userContextViewModel: UserContextViewModel
    private let analyticsService: AnalyticsService // Assuming it's needed, like in LockViewModel
    
    private var cancellables = Set<AnyCancellable>()

    // Computed property for current context name
    var currentContextName: String {
        if let unitId = userContextViewModel.selectedUnitId {
            // Placeholder: Fetch unit name.
            return "Unit: \(unitId)"
        } else if let propertyId = userContextViewModel.selectedPropertyId {
            // Placeholder: Fetch property name.
            return "Property: \(propertyId)"
        } else if let portfolioId = userContextViewModel.selectedPortfolioId {
            // Placeholder: Fetch portfolio name.
            return "Portfolio: \(portfolioId)"
        }
        return "All Accessible Devices"
    }

    // Computed property for permission to add devices in current context
    var canAddDeviceInCurrentContext: Bool {
        guard let currentUser = userManager.currentUser else { return false }

        if let unitId = userContextViewModel.selectedUnitId {
            // To add a device to a specific unit, the user must have rights to the parent property.
            // We rely on UserContextViewModel.selectedPropertyId being the parent of selectedUnitId.
            guard let parentPropertyId = userContextViewModel.selectedPropertyId else {
                 print("Warning: selectedUnitId (\\(unitId)) is present, but selectedPropertyId is nil. Cannot determine add permission for device.")
                return false
            }
            return currentUser.isManager(ofPropertyId: parentPropertyId) || 
                   currentUser.isOwner(ofPortfolioId: userManager.getPortfolioIdForProperty(propertyId: parentPropertyId) ?? "") ||
                   currentUser.isPortfolioAdmin(ofPortfolioId: userManager.getPortfolioIdForProperty(propertyId: parentPropertyId) ?? "")

        } else if let propertyId = userContextViewModel.selectedPropertyId {
            return currentUser.isManager(ofPropertyId: propertyId) || 
                   currentUser.isOwner(ofPortfolioId: userManager.getPortfolioIdForProperty(propertyId: propertyId) ?? "") ||
                   currentUser.isPortfolioAdmin(ofPortfolioId: userManager.getPortfolioIdForProperty(propertyId: propertyId) ?? "")
        }
        // Adding device generally requires at least a Property context
        return false
    }
    
    init(deviceService: DeviceService, userManager: UserManager, userContextViewModel: UserContextViewModel, analyticsService: AnalyticsService = .shared) {
        self.deviceService = deviceService
        self.userManager = userManager
        self.userContextViewModel = userContextViewModel
        self.analyticsService = analyticsService
        
        userManager.$isAuthenticated
            .dropFirst()
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task { await self?.fetchDevices() }
                } else {
                    self?.devicesState = .idle
                }
            }
            .store(in: &cancellables)

        userContextViewModel.$selectedPortfolioId.combineLatest(userContextViewModel.$selectedPropertyId, userContextViewModel.$selectedUnitId)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _ in
                guard let self = self else { return }
                Task {
                    print("DevicesViewModel: Context changed, fetching devices.")
                    await self.fetchDevices()
                }
            }
            .store(in: &cancellables)
    }
    
    func fetchDevices() async {
        await MainActor.run {
            devicesState = .loading(previous: devicesState.data)
            self.currentContextDebugDescription = "Context: P:\(self.userContextViewModel.selectedPortfolioId ?? "nil") Pr:\(self.userContextViewModel.selectedPropertyId ?? "nil") U:\(self.userContextViewModel.selectedUnitId ?? "nil")"
        }
        
        do {
            let fetchedDevices = try await deviceService.fetchDevices(
                propertyId: userContextViewModel.selectedPropertyId,
                unitId: userContextViewModel.selectedUnitId
            )
            
            analyticsService.logEvent("all_devices_fetched", parameters: [
                "count": fetchedDevices.count,
                "portfolio_id": userContextViewModel.selectedPortfolioId ?? "nil",
                "property_id": userContextViewModel.selectedPropertyId ?? "nil",
                "unit_id": userContextViewModel.selectedUnitId ?? "nil"
            ])
            
            await MainActor.run {
                devicesState = .success(fetchedDevices)
            }
        } catch {
            analyticsService.logError(error, parameters: ["operation": "fetch_all_devices"])
            await MainActor.run {
                devicesState = .failure(error, previous: devicesState.data)
            }
        }
    }

    // Helper to get unit name (placeholder)
    func unitName(for unitId: String?) -> String? {
        guard let unitId = unitId else { return nil }
        // In real app, fetch from a UnitService or cache
        return "Unit \(unitId.suffix(4))" 
    }

    // Helper to get property name (placeholder)
    func propertyName(for propertyId: String?) -> String? {
        guard let propertyId = propertyId else { return nil }
        // In real app, fetch from a PropertyService or cache
        return "Property \(propertyId.suffix(4))"
    }
    
    // Grouped devices for the view
    var groupedDevices: [DeviceGroup] {
        guard let devices = devicesState.data else { return [] }
        
        if userContextViewModel.selectedUnitId != nil {
            // If a unit is selected, all devices are for this unit. No further grouping needed unless by type.
            // For now, return a single group.
            return [DeviceGroup(name: currentContextName, devices: devices)]
        } else if let propertyId = userContextViewModel.selectedPropertyId {
            // If a property is selected, group devices by their unitId within this property
            let devicesByUnitId = Dictionary(grouping: devices, by: { $0.unitId })
            return devicesByUnitId.map { unitId, unitDevices in
                let unitDisplayName = unitName(for: unitId) ?? "Devices without specific unit"
                return DeviceGroup(name: unitDisplayName, devices: unitDevices)
            }.sorted(by: { $0.name < $1.name })
        } else if userContextViewModel.selectedPortfolioId != nil {
            // If a portfolio is selected, group by propertyId
            let devicesByPropertyId = Dictionary(grouping: devices, by: { $0.propertyId })
            return devicesByPropertyId.map { propertyId, propDevices in
                let propertyDisplayName = propertyName(for: propertyId) ?? "Devices without specific property"
                return DeviceGroup(name: propertyDisplayName, devices: propDevices)
            }.sorted(by: { $0.name < $1.name })
        }
        
        // Fallback: No specific context or broad context, group by property then unit.
        // This might be too complex for a flat list view, consider if needed.
        // For now, if no P/P/U selected, could group by property.
        let devicesByPropertyId = Dictionary(grouping: devices, by: { $0.propertyId })
        return devicesByPropertyId.map { propertyId, propDevices in
            let propertyDisplayName = propertyName(for: propertyId) ?? "Unassigned Property"
            return DeviceGroup(name: propertyDisplayName, devices: propDevices)
        }.sorted(by: { $0.name < $1.name })
    }
}

struct DeviceGroup: Identifiable {
    let id = UUID()
    let name: String
    let devices: [AbstractDevice]
}

// TODO: Ensure User model (`User.swift` or `User+Permissions.swift`) has robust implementations for:
// - isManager(ofPropertyId: String) -> Bool
// - isOwner(ofPortfolioId: String) -> Bool
// - isPortfolioAdmin(ofPortfolioId: String) -> Bool
// These methods should correctly interpret `roleAssociations` for permission checks.
// Also, ensure `UserManager.getPortfolioIdForProperty(propertyId: String) -> String?` is correctly implemented.

// Ensure User model has isManager, isOwner, isPortfolioAdmin methods as used in LockViewModel
/* // Commenting out placeholder extension
extension User {
    func isManager(ofPropertyId propertyId: String) -> Bool { 
        // Placeholder - replace with actual logic using self.roleAssociations
        // e.g., self.roleAssociations?.contains { $0.associatedEntityType == .property && $0.associatedEntityId == propertyId && $0.roleWithinEntity == .propertyManager } ?? false
        return false 
    }
    func isOwner(ofPortfolioId portfolioId: String) -> Bool { 
        // Placeholder
        return false 
    }
    func isPortfolioAdmin(ofPortfolioId portfolioId: String) -> Bool { 
        // Placeholder
        return false 
    }
}
*/ 