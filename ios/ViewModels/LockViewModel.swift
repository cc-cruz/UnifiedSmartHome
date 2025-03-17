import Foundation
import Combine

// Generic async data loading state
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
    @Published var groupByRooms: Bool = true
    
    // Dependencies
    private let lockAdapter: LockAdapter
    private let lockDAL: LockDALProtocol
    private let userManager: UserManager
    private let analyticsService: AnalyticsService
    
    // Cancellables for Combine
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties
    var roomsWithLocks: [Room] {
        // Get all rooms that have locks
        let roomIds = Set(locksState.data?.compactMap { $0.roomId } ?? [])
        return RoomService.shared.getRooms().filter { roomIds.contains($0.id) }
    }
    
    // Initialization
    init(lockAdapter: LockAdapter, lockDAL: LockDALProtocol, userManager: UserManager = .shared, analyticsService: AnalyticsService = .shared) {
        self.lockAdapter = lockAdapter
        self.lockDAL = lockDAL
        self.userManager = userManager
        self.analyticsService = analyticsService
        
        // Monitor authentication changes
        userManager.$isAuthenticated
            .dropFirst()
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    // User just logged in, fetch locks
                    Task {
                        await self?.fetchLocks()
                    }
                } else {
                    // User logged out, clear locks
                    self?.locksState = .idle
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func fetchLocks() async {
        // Update UI state to loading
        await MainActor.run {
            locksState = .loading(previous: locksState.data)
        }
        
        do {
            // Fetch locks from adapter
            let locks = try await lockAdapter.fetchLocks()
            
            // Log analytics
            analyticsService.logEvent("locks_fetched", parameters: [
                "count": locks.count
            ])
            
            // Update UI state with success
            await MainActor.run {
                locksState = .success(locks)
            }
        } catch {
            // Log error
            analyticsService.logError(error, parameters: [
                "operation": "fetch_locks"
            ])
            
            // Update UI state with error
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
        return AddLockViewModel(lockAdapter: lockAdapter)
    }
    
    func makeLockDetailViewModel(for lock: LockDevice) -> LockDetailViewModel {
        return LockDetailViewModel(lock: lock, lockDAL: lockDAL)
    }
}

// Placeholder for AddLockViewModel
class AddLockViewModel {
    private let lockAdapter: LockAdapter
    
    init(lockAdapter: LockAdapter) {
        self.lockAdapter = lockAdapter
    }
    
    // Implementation would go here
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
    @Published var autoLockEnabled: Bool = false
    
    private let lockDAL: LockDALProtocol
    
    var userCanManageAccess: Bool {
        let role = UserManager.shared.currentUser?.role
        return role == .owner || role == .propertyManager
    }
    
    init(lock: LockDevice, lockDAL: LockDALProtocol) {
        self.lock = lock
        self.lockDAL = lockDAL
        self.allowRemoteControl = lock.isRemoteOperationEnabled
        self.accessHistory = lock.accessHistory
        
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