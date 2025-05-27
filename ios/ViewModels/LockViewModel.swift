import Foundation
import Combine
import SwiftUI // Required for EnvironmentObject
import Sources.Models // Ensure models are accessible

// Generic async data loading state
// TODO: This LoadingState enum is also used by DevicesViewModel.swift.
// Consider moving it to a shared file (e.g., Utils.swift or a shared ViewModels module) to avoid duplication.
enum LoadingState<T> {
    case idle
    case loading(previous: T?)
    case success(T)
    case failure(Error, previous: T?)
    
    var data: T? {
        switch self {
        case .idle: return nil
        case .loading(let previous): return previous
        case .success(let data): return data
        case .failure(_, let previous): return previous
        }
    }
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var error: Error? {
        if case .failure(let error, _) = self { return error }
        return nil
    }
}

class LockViewModel: ObservableObject {
    // Published properties
    @Published var locksState: LoadingState<[LockDevice]> = .idle
    @Published var groupByRooms: Bool = true // Consider if this should be groupByUnit or property
    @Published var currentContextDebugDescription: String = "Context: N/A"

    // Dependencies
    // private let lockAdapter: LockAdapter // Replaced by deviceService
    private let deviceService: DeviceService // New dependency
    private let lockDAL: LockDALProtocol
    private let userManager: UserManager
    private let userContextViewModel: UserContextViewModel // New dependency
    private let analyticsService: AnalyticsService
    
    // Cancellables for Combine
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties
    var roomsWithLocks: [Room] { // This might need to be updated for Unit/Property grouping
        // Get all rooms that have locks
        let roomIds = Set(locksState.data?.compactMap { $0.roomId } ?? [])
        return RoomService.shared.getRooms().filter { roomIds.contains($0.id) }
    }

    // New computed property for current context name
    var currentContextName: String {
        if let unitId = userContextViewModel.selectedUnitId {
            // Placeholder: Fetch unit name. In a real app, this would involve a lookup.
            // For now, just using the ID.
            return "Unit: \\(unitId)"
        } else if let propertyId = userContextViewModel.selectedPropertyId {
            // Placeholder: Fetch property name.
            return "Property: \\(propertyId)"
        } else if let portfolioId = userContextViewModel.selectedPortfolioId {
            // Placeholder: Fetch portfolio name.
            return "Portfolio: \\(portfolioId)"
        }
        return "All Accessible"
    }

    // New computed property for permission to add locks in current context
    var canAddLockInCurrentContext: Bool {
        guard let currentUser = userManager.currentUser else { return false }

        if let unitId = userContextViewModel.selectedUnitId {
            // To add a lock to a specific unit, the user must have rights to the parent property.
            // We rely on UserContextViewModel.selectedPropertyId being the parent of selectedUnitId.
            guard let parentPropertyId = userContextViewModel.selectedPropertyId else {
                // This case should ideally not happen if the context selection flow is P -> P -> U.
                // If only unitId is present without its parent propertyId in context, deny permission.
                print("Warning: selectedUnitId (\\(unitId)) is present, but selectedPropertyId is nil. Cannot determine add permission.")
                return false
            }
            return currentUser.isManager(ofPropertyId: parentPropertyId) || 
                   currentUser.isOwner(ofPortfolioId: userManager.getPortfolioIdForProperty(propertyId: parentPropertyId) ?? "") || 
                   currentUser.isPortfolioAdmin(ofPortfolioId: userManager.getPortfolioIdForProperty(propertyId: parentPropertyId) ?? "")

        } else if let propertyId = userContextViewModel.selectedPropertyId {
            // Requires being a manager of this property or owner/admin of its portfolio
            return currentUser.isManager(ofPropertyId: propertyId) || currentUser.isOwner(ofPortfolioId: userManager.getPortfolioIdForProperty(propertyId: propertyId) ?? "") || currentUser.isPortfolioAdmin(ofPortfolioId: userManager.getPortfolioIdForProperty(propertyId: propertyId) ?? "")
        }
        // If only portfolio is selected, or no context, disallow adding directly (user must select property/unit)
        return false
    }
    
    // Initialization
    init(deviceService: DeviceService, lockDAL: LockDALProtocol, userManager: UserManager = .shared, userContextViewModel: UserContextViewModel, analyticsService: AnalyticsService = .shared) {
        // self.lockAdapter = lockAdapter // Removed
        self.deviceService = deviceService
        self.lockDAL = lockDAL
        self.userManager = userManager
        self.userContextViewModel = userContextViewModel // Store dependency
        self.analyticsService = analyticsService
        
        // Monitor authentication changes
        userManager.$isAuthenticated
            .dropFirst()
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task {
                        await self?.fetchLocks()
                    }
                } else {
                    self?.locksState = .idle
                }
            }
            .store(in: &cancellables)

        // Monitor context changes from UserContextViewModel
        userContextViewModel.$selectedPortfolioId.combineLatest(userContextViewModel.$selectedPropertyId, userContextViewModel.$selectedUnitId)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main) // Debounce to avoid rapid refetches
            .sink { [weak self] _, _, _ in
                guard let self = self else { return }
                Task {
                    print("LockViewModel: Context changed, fetching locks.")
                    await self.fetchLocks()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func fetchLocks() async {
        await MainActor.run {
            locksState = .loading(previous: locksState.data)
            self.currentContextDebugDescription = "Context: P:\\(self.userContextViewModel.selectedPortfolioId ?? "nil") Pr:\\(self.userContextViewModel.selectedPropertyId ?? "nil") U:\\(self.userContextViewModel.selectedUnitId ?? "nil")"

        }
        
        do {
            // Fetch locks using DeviceService and current context from UserContextViewModel
            let locks = try await deviceService.fetchDevices(
                propertyId: userContextViewModel.selectedPropertyId,
                unitId: userContextViewModel.selectedUnitId
            )
            
            // Filter for LockDevice type, as fetchDevices can return AbstractDevice
            let lockDevices = locks.compactMap { $0 as? LockDevice }
            
            analyticsService.logEvent("locks_fetched", parameters: [
                "count": lockDevices.count,
                "portfolio_id": userContextViewModel.selectedPortfolioId ?? "nil",
                "property_id": userContextViewModel.selectedPropertyId ?? "nil",
                "unit_id": userContextViewModel.selectedUnitId ?? "nil"
            ])
            
            await MainActor.run {
                locksState = .success(lockDevices)
            }
        } catch {
            analyticsService.logError(error, parameters: [
                "operation": "fetch_locks"
            ])
            
            await MainActor.run {
                locksState = .failure(error, previous: locksState.data)
            }
        }
    }
    
    func toggleLock(_ lock: LockDevice) async {
        guard let userId = userManager.currentUser?.id else {
            // Not authenticated
            return
        }
        
        // Determine operation based on current state
        let operation: LockDevice.LockOperation = lock.currentState == .locked ? .unlock : .lock
        
        do {
            // Perform operation via DAL
            let newState = try await (operation == .lock ?
                                     lockDAL.lock(deviceId: lock.id, userId: userId) :
                                     lockDAL.unlock(deviceId: lock.id, userId: userId))
            
            // Log analytics
            analyticsService.logEvent("lock_toggled", parameters: [
                "lock_id": lock.id,
                "operation": operation.rawValue,
                "success": true
            ])
            
            // Update local state
            await updateLockState(lockId: lock.id, newState: newState)
            
        } catch {
            // Log error
            analyticsService.logError(error, parameters: [
                "operation": "toggle_lock",
                "lock_id": lock.id,
                "attempted_operation": operation.rawValue
            ])
            
            // Handle error (UI will be updated by the published property)
            await MainActor.run {
                self.locksState = .failure(error, previous: self.locksState.data)
            }
        }
    }
    
    func locksInRoom(_ roomId: String) -> [LockDevice] {
        return locksState.data?.filter { $0.roomId == roomId } ?? []
    }
    
    func navigateToLockDetail(_ lock: LockDevice) {
        // In a real implementation, this would handle navigation
        // For now, just log the event
        analyticsService.logEvent("view_lock_detail", parameters: [
            "lock_id": lock.id,
            "lock_name": lock.name
        ])
    }
    
    // MARK: - Private Helper Methods
    
    private func updateLockState(lockId: String, newState: LockDevice.LockState) async {
        await MainActor.run {
            // Find the lock in our current state
            guard var locks = locksState.data,
                  let index = locks.firstIndex(where: { $0.id == lockId }) else {
                return
            }
            
            // Update the lock state
            locks[index].currentState = newState
            locks[index].lastStateChange = Date()
            
            // Update the published state
            locksState = .success(locks)
        }
    }
    
    // Factory method to create related view models
    func makeAddLockViewModel() -> AddLockViewModel {
        // AddLockViewModel might also need context awareness or DeviceService
        return AddLockViewModel(deviceService: deviceService, userContextViewModel: userContextViewModel)
    }
    
    func makeLockDetailViewModel(for lock: LockDevice) -> LockDetailViewModel {
        return LockDetailViewModel(lock: lock, lockDAL: lockDAL, userManager: userManager, userContextViewModel: userContextViewModel)
    }
}

// Placeholder for AddLockViewModel
// AddLockViewModel should be updated to handle tenancy context for adding locks
class AddLockViewModel: ObservableObject {
    // private let lockAdapter: LockAdapter // Replaced
    private let deviceService: DeviceService
    private let userContextViewModel: UserContextViewModel
    @Published var newLockName: String = ""
    @Published var selectedPropertyIdForNewLock: String? // User might need to pick if context is broad
    @Published var selectedUnitIdForNewLock: String?   // User might need to pick

    // TODO: Add properties for available properties/units to pick from, based on user's rights & current context
    
    init(deviceService: DeviceService, userContextViewModel: UserContextViewModel) {
        self.deviceService = deviceService
        self.userContextViewModel = userContextViewModel
        // Initialize selectedPropertyIdForNewLock / selectedUnitIdForNewLock based on userContextViewModel
        self.selectedPropertyIdForNewLock = userContextViewModel.selectedPropertyId
        self.selectedUnitIdForNewLock = userContextViewModel.selectedUnitId

    }
    
    func addLock() async {
        // Implementation would involve:
        // 1. Validating newLockName, selectedPropertyIdForNewLock/selectedUnitIdForNewLock
        // 2. Calling a method on DeviceService or APIService to create/register the new lock
        //    This backend endpoint would associate it with the property/unit
        // 3. Handling success/failure
        print("Attempting to add lock: \\(newLockName) to P: \\(selectedPropertyIdForNewLock ?? "N/A") U: \\(selectedUnitIdForNewLock ?? "N/A")")
        // Example:
        // guard let propertyId = selectedPropertyIdForNewLock, !newLockName.isEmpty else { return }
        // try await deviceService.createLock(name: newLockName, propertyId: propertyId, unitId: selectedUnitIdForNewLock)
    }
}

// Placeholder for LockDetailViewModel
class LockDetailViewModel: ObservableObject {
    @Published var lock: LockDevice
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var accessHistory: [LockDevice.LockAccessRecord] = []
    @Published var showAllHistory = false
    @Published var showRenameDialog = false
    @Published var showRemoveDialog = false
    @Published var newLockName = ""
    @Published var allowRemoteControl: Bool
    @Published var autoLockEnabled: Bool = false // This seems like a device-specific setting, not general P0
    
    private let lockDAL: LockDALProtocol
    private let userManager: UserManager
    private let userContextViewModel: UserContextViewModel // Added

    // Updated permission check based on roles and device's context
    var userCanManageAccess: Bool {
        guard let currentUser = userManager.currentUser,
              let associations = currentUser.roleAssociations else { return false }
        
        // Check for unit-level tenant or property-level manager/portfolio admin/owner
        if let unitId = lock.unitId, associations.contains(where: { $0.associatedEntityType == .unit && $0.associatedEntityId == unitId && $0.roleWithinEntity == .tenant }) {
             // Tenants usually cannot manage access for others, but can use the lock.
             // For "Manage Access" screen, tenant role is likely false.
             // This depends on exact requirements for "Manage Access". Let's assume tenants cannot.
            return false // Or true if tenants can manage their own guest keys, adjust as needed.
        }

        if let propertyId = lock.propertyId {
            if associations.contains(where: { $0.associatedEntityType == .property && $0.associatedEntityId == propertyId && $0.roleWithinEntity == .propertyManager }) {
                return true
            }
            // Check portfolio level access for the property's portfolio
            if let portfolioId = userManager.getPortfolioIdForProperty(propertyId: propertyId) {
                 if associations.contains(where: { $0.associatedEntityType == .portfolio && $0.associatedEntityId == portfolioId && ($0.roleWithinEntity == .portfolioAdmin || $0.roleWithinEntity == .owner) }) {
                    return true
                }
            }
        }
        return false
    }
    
    // Permission to modify lock settings (rename, remove, toggle remote control)
    // Usually Property Manager or Portfolio Admin/Owner
    var canModifyLockSettings: Bool {
        guard let currentUser = userManager.currentUser,
              let associations = currentUser.roleAssociations else { return false }

        if let propertyId = lock.propertyId {
            if associations.contains(where: { $0.associatedEntityType == .property && $0.associatedEntityId == propertyId && $0.roleWithinEntity == .propertyManager }) {
                return true
            }
            if let portfolioId = userManager.getPortfolioIdForProperty(propertyId: propertyId) {
                 if associations.contains(where: { $0.associatedEntityType == .portfolio && $0.associatedEntityId == portfolioId && ($0.roleWithinEntity == .portfolioAdmin || $0.roleWithinEntity == .owner) }) {
                    return true
                }
            }
        }
        return false
    }


    init(lock: LockDevice, lockDAL: LockDALProtocol, userManager: UserManager, userContextViewModel: UserContextViewModel) {
        self.lock = lock
        self.lockDAL = lockDAL
        self.userManager = userManager // Store
        self.userContextViewModel = userContextViewModel // Store
        self.allowRemoteControl = lock.isRemoteOperationEnabled // This should be true if user CAN enable it, not just current state
        self.accessHistory = lock.accessHistory // Initial short list
        self.newLockName = lock.name
        
        // Load full history
        Task {
            await fetchAccessHistory()
        }
    }
    
    func refreshLockStatus() {
        Task {
            isLoading = true
            
            do {
                let updatedLock = try await lockDAL.getStatus(deviceId: lock.id)
                
                await MainActor.run {
                    self.lock = updatedLock
                    self.accessHistory = updatedLock.accessHistory
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    func performLockOperation(_ operation: LockDevice.LockOperation) async {
        guard let userId = UserManager.shared.currentUser?.id else {
            errorMessage = "You must be logged in to perform this operation"
            showError = true
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let newState = try await (operation == .lock ?
                                     lockDAL.lock(deviceId: lock.id, userId: userId) :
                                     lockDAL.unlock(deviceId: lock.id, userId: userId))
            
            await MainActor.run {
                lock.currentState = newState
                lock.lastStateChange = Date()
                isLoading = false
                
                // Refresh access history
                Task {
                    await fetchAccessHistory()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
    
    private func fetchAccessHistory() async {
        do {
            let history = try await lockDAL.getAccessHistory(deviceId: lock.id, limit: 50)
            
            await MainActor.run {
                self.accessHistory = history
            }
        } catch {
            print("Error fetching access history: \(error.localizedDescription)")
        }
    }
    
    func renameLock() {
        // In a real implementation, this would call an API
        // For now, just update the local state
        if !newLockName.isEmpty {
            lock.name = newLockName
            newLockName = ""
        }
        showRenameDialog = false
    }
    
    func removeLock() {
        // In a real implementation, this would call an API
        // For now, just close the dialog
        showRemoveDialog = false
    }
    
    func updateRemoteControlSetting(enabled: Bool) {
        // In a real implementation, this would call an API
        // For now, just update the local state
        allowRemoteControl = enabled
    }
    
    func updateAutoLockSetting(enabled: Bool) {
        // In a real implementation, this would call an API
        // For now, just update the local state
        autoLockEnabled = enabled
    }
} 