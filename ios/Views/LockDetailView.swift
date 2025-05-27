import SwiftUI

struct LockDetailView: View {
    @ObservedObject var viewModel: LockDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var userContextViewModel: UserContextViewModel // For completeness, though VM handles context logic
    
    // For biometric confirmation
    @State private var isAuthenticating = false
    @State private var isConfirmingOperation = false
    @State private var pendingOperation: LockDevice.LockOperation?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with lock animation
                LockStatusView(lock: viewModel.lock, isOperationInProgress: viewModel.isLoading)
                
                // Lock/unlock controls
                controlsSection
                
                // Battery status
                batterySection
                
                // Access history
                historySection
                
                // Settings
                settingsSection
            }
            .padding()
        }
        .navigationTitle(viewModel.lock.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { viewModel.refreshLockStatus() }) {
                        Label("Refresh Status", systemImage: "arrow.clockwise")
                    }
                    
                    // Conditionally show Rename and Remove options
                    if viewModel.canModifyLockSettings {
                        Divider()
                        
                        Button(action: { viewModel.showRenameDialog = true }) {
                            Label("Rename", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: { viewModel.showRemoveDialog = true }) {
                            Label("Remove Lock", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Lock", isPresented: $viewModel.showRenameDialog) {
            TextField("Lock Name", text: $viewModel.newLockName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { viewModel.renameLock() }
        }
        .alert("Remove Lock", isPresented: $viewModel.showRemoveDialog) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { viewModel.removeLock() }
        } message: {
            Text("Are you sure you want to remove this lock? You will lose access to it.")
        }
        .overlay(
            ZStack {
                if viewModel.isLoading {
                    Color.black.opacity(0.2)
                        .edgesIgnoringSafeArea(.all)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
            }
        )
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "An error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $isConfirmingOperation) {
            if let operation = pendingOperation {
                lockConfirmationView(for: operation)
            }
        }
    }
    
    // Lock/unlock controls with security confirmation
    private var controlsSection: some View {
        VStack(spacing: 16) {
            Text("Controls")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                // Lock button
                Button(action: {
                    pendingOperation = .lock
                    confirmOperation(.lock)
                }) {
                    VStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 30))
                            .padding()
                            .background(Circle().fill(Color.green.opacity(0.2)))
                        Text("Lock")
                    }
                }
                .disabled(viewModel.lock.currentState == .locked || viewModel.isLoading)
                .frame(maxWidth: .infinity)
                
                // Unlock button
                Button(action: {
                    pendingOperation = .unlock
                    confirmOperation(.unlock)
                }) {
                    VStack {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 30))
                            .padding()
                            .background(Circle().fill(Color.orange.opacity(0.2)))
                        Text("Unlock")
                    }
                }
                .disabled(viewModel.lock.currentState != .locked || viewModel.isLoading)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // Battery status view
    private var batterySection: some View {
        VStack(spacing: 12) {
            Text("Battery Status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                batteryIcon
                    .font(.system(size: 24))
                    .foregroundColor(batteryColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.lock.batteryLevel)%")
                        .font(.title3)
                        .foregroundColor(batteryColor)
                    
                    Text(batteryStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("Last Updated: \(dateFormatter.string(from: Date()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            )
        }
        .padding(.horizontal)
    }
    
    // Access history section
    private var historySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                
                Spacer()
                
                Button("See All") {
                    viewModel.showAllHistory = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if viewModel.accessHistory.isEmpty {
                Text("No recent activity")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.accessHistory.prefix(3)) { record in
                    AccessHistoryRow(record: record)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .sheet(isPresented: $viewModel.showAllHistory) {
            NavigationView {
                List {
                    ForEach(viewModel.accessHistory) { record in
                        AccessHistoryRow(record: record)
                    }
                }
                .navigationTitle("Access History")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            viewModel.showAllHistory = false
                        }
                    }
                }
            }
        }
    }
    
    // Lock settings section
    private var settingsSection: some View {
        VStack(spacing: 16) {
            Text("Settings")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Conditionally enable settings toggles
            Toggle("Allow Remote Control", isOn: $viewModel.allowRemoteControl)
                .onChange(of: viewModel.allowRemoteControl) { newValue in
                    viewModel.updateRemoteControlSetting(enabled: newValue)
                }
                .disabled(!viewModel.canModifyLockSettings) // Disable if user cannot modify
            
            Toggle("Auto-Lock After 30 Seconds", isOn: $viewModel.autoLockEnabled)
                .onChange(of: viewModel.autoLockEnabled) { newValue in
                    viewModel.updateAutoLockSetting(enabled: newValue)
                }
                .disabled(!viewModel.canModifyLockSettings) // Disable if user cannot modify
            
            // Conditionally show Manage Access link
            if viewModel.userCanManageAccess {
                NavigationLink(destination: LockAccessManagementView(lockId: viewModel.lock.id)) {
                    HStack {
                        Text("Manage Access")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // Helper function to handle operation confirmation with biometrics
    private func confirmOperation(_ operation: LockDevice.LockOperation) {
        if UserManager.shared.requiresBiometricConfirmation {
            isAuthenticating = true
            
            BiometricAuthManager.shared.authenticate(reason: "Confirm \(operation.rawValue) operation") { success, error in
                DispatchQueue.main.async {
                    isAuthenticating = false
                    
                    if success {
                        executeOperation(operation)
                    } else if let error = error {
                        viewModel.errorMessage = "Authentication failed: \(error.localizedDescription)"
                        viewModel.showError = true
                    }
                }
            }
        } else if operation == .unlock && UserManager.shared.requiresBiometricConfirmationForUnlock {
            // Show confirmation dialog for unlock
            isConfirmingOperation = true
        } else {
            // No special confirmation needed
            executeOperation(operation)
        }
    }
    
    // Execute the actual lock/unlock operation
    private func executeOperation(_ operation: LockDevice.LockOperation) {
        Task {
            await viewModel.performLockOperation(operation)
        }
    }
    
    // Confirmation view for sensitive operations
    private func lockConfirmationView(for operation: LockDevice.LockOperation) -> some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: operation == .lock ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 60))
                    .foregroundColor(operation == .lock ? .green : .orange)
                    .padding()
                
                Text("Confirm \(operation == .lock ? "Lock" : "Unlock")")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Are you sure you want to \(operation == .lock ? "lock" : "unlock") \(viewModel.lock.name)?")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button("Cancel") {
                        isConfirmingOperation = false
                    }
                    .buttonStyle(.bordered)
                    .frame(minWidth: 120)
                    
                    Button("Confirm") {
                        isConfirmingOperation = false
                        executeOperation(operation)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minWidth: 120)
                }
                .padding(.top)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isConfirmingOperation = false
                    }
                }
            }
        }
    }
    
    // Helper computed properties
    private var batteryIcon: some View {
        Group {
            if viewModel.lock.batteryLevel > 75 {
                Image(systemName: "battery.100")
            } else if viewModel.lock.batteryLevel > 50 {
                Image(systemName: "battery.75")
            } else if viewModel.lock.batteryLevel > 25 {
                Image(systemName: "battery.50")
            } else if viewModel.lock.batteryLevel > 10 {
                Image(systemName: "battery.25")
            } else {
                Image(systemName: "battery.0")
            }
        }
    }
    
    private var batteryColor: Color {
        if viewModel.lock.batteryLevel > 20 {
            return .green
        } else if viewModel.lock.batteryLevel > 10 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var batteryStatusText: String {
        if viewModel.lock.batteryLevel > 20 {
            return "Battery Good"
        } else if viewModel.lock.batteryLevel > 10 {
            return "Battery Low"
        } else {
            return "Replace Battery Soon"
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

// Lock status view with animation
struct LockStatusView: View {
    let lock: LockDevice
    let isOperationInProgress: Bool
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Lock icon with animation
            ZStack {
                Circle()
                    .fill(backgroundColorForState)
                    .frame(width: 100, height: 100)
                
                Image(systemName: imageNameForState)
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isAnimating ? 30 : 0))
                    .animation(
                        Animation.spring(response: 0.3, dampingFraction: 0.6).repeatCount(1),
                        value: isAnimating
                    )
            }
            .overlay(
                Group {
                    if isOperationInProgress {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
            )
            
            // Lock status text
            Text(stateText)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(stateTextColor)
            
            // Last changed time
            if let lastChange = lock.lastStateChange {
                Text("Last changed: \(timeAgoString(from: lastChange))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            // Trigger animation when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAnimating = true
            }
        }
    }
    
    // Helper computed properties
    private var backgroundColorForState: Color {
        switch lock.currentState {
        case .locked:
            return .green
        case .unlocked:
            return .orange
        case .jammed:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    private var imageNameForState: String {
        switch lock.currentState {
        case .locked:
            return "lock.fill"
        case .unlocked:
            return "lock.open.fill"
        case .jammed:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark"
        }
    }
    
    private var stateText: String {
        switch lock.currentState {
        case .locked:
            return "Locked"
        case .unlocked:
            return "Unlocked"
        case .jammed:
            return "Jammed"
        case .unknown:
            return "Unknown"
        }
    }
    
    private var stateTextColor: Color {
        switch lock.currentState {
        case .locked:
            return .green
        case .unlocked:
            return .orange
        case .jammed:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    // Format time ago string
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Access history row
struct AccessHistoryRow: View {
    let record: LockDevice.LockAccessRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // Operation icon
            Image(systemName: record.operation == .lock ? "lock.fill" : "lock.open.fill")
                .foregroundColor(record.operation == .lock ? .green : .orange)
                .font(.system(size: 18))
                .frame(width: 30, height: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                // Operation text
                Text(record.operation == .lock ? "Locked" : "Unlocked")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Time and user
                Text("\(timeString(from: record.timestamp)) by \(userNameFromId(record.userId))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Success/failure indicator
            if record.success {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
    
    // Format time string
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Get user name from ID (in a real app, this would fetch from a user service)
    private func userNameFromId(_ userId: String) -> String {
        // In a real implementation, this would look up the user name
        // For now, just return a placeholder
        return "User \(userId.prefix(4))"
    }
}

// Placeholder for LockAccessManagementView
struct LockAccessManagementView: View {
    let lockId: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("This is a placeholder for the Lock Access Management screen")
                .multilineTextAlignment(.center)
                .padding()
            
            Text("Lock ID: \(lockId)")
                .font(.caption)
        }
        .navigationTitle("Manage Access")
    }
}

// Placeholder for BiometricAuthManager
class BiometricAuthManager {
    static let shared = BiometricAuthManager()
    
    private init() {}
    
    func authenticate(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        // In a real implementation, this would use LocalAuthentication framework
        // For now, just simulate success
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(true, nil)
        }
    }
} 