import SwiftUI

struct LockListView: View {
    @ObservedObject var viewModel: LockViewModel
    @State private var isPresentingAddLock = false
    
    var body: some View {
        ZStack {
            List {
                // Group by rooms if available
                if viewModel.groupByRooms {
                    ForEach(viewModel.roomsWithLocks) { room in
                        Section(header: Text(room.name)) {
                            ForEach(viewModel.locksInRoom(room.id)) { lock in
                                LockCell(lock: lock) {
                                    viewModel.navigateToLockDetail(lock)
                                }
                            }
                        }
                    }
                } else {
                    // Just show all locks
                    ForEach(viewModel.locksState.data ?? []) { lock in
                        LockCell(lock: lock) {
                            viewModel.navigateToLockDetail(lock)
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.fetchLocks()
            }
            .overlay(emptyState)
            .navigationTitle("Locks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresentingAddLock = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.groupByRooms.toggle() }) {
                        Image(systemName: viewModel.groupByRooms ? "square.grid.2x2" : "list.bullet")
                    }
                }
            }
            
            // Loading overlay
            if viewModel.locksState.isLoading && viewModel.locksState.data == nil {
                VStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        LockCellPlaceholder()
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $isPresentingAddLock) {
            AddLockView(viewModel: viewModel.makeAddLockViewModel())
        }
    }
    
    // Empty state view for when no locks are available
    @ViewBuilder
    var emptyState: some View {
        if let error = viewModel.locksState.error, viewModel.locksState.data == nil {
            VStack(spacing: 16) {
                Image(systemName: "lock.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                
                Text("Could not load locks")
                    .font(.headline)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Try Again") {
                    Task {
                        await viewModel.fetchLocks()
                    }
                }
                .buttonStyle(.bordered)
            }
        } else if viewModel.locksState.data?.isEmpty == true && !viewModel.locksState.isLoading {
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                
                Text("No locks found")
                    .font(.headline)
                
                Text("Connect your first smart lock to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Add Lock") {
                    isPresentingAddLock = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// Individual lock cell with animated lock state
struct LockCell: View {
    let lock: LockDevice
    let onTap: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Lock icon with animation
            ZStack {
                Circle()
                    .fill(backgroundColorForState)
                    .frame(width: 50, height: 50)
                
                Image(systemName: imageNameForState)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isAnimating ? 15 : 0))
                    .animation(
                        lock.currentState == .locked || lock.currentState == .unlocked ?
                            Animation.spring() : .default,
                        value: isAnimating
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lock.name)
                    .font(.headline)
                
                HStack {
                    Text(stateText)
                        .font(.subheadline)
                        .foregroundColor(stateTextColor)
                    
                    // Battery indicator
                    if lock.batteryLevel <= 20 {
                        Image(systemName: "battery.25")
                            .foregroundColor(.red)
                    }
                }
                
                if let lastChange = lock.lastStateChange {
                    Text("Last changed: \(timeAgoString(from: lastChange))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Quick action buttons for property managers
            if UserManager.shared.currentUser?.role == .propertyManager || 
               UserManager.shared.currentUser?.role == .owner {
                HStack(spacing: 12) {
                    Button(action: {
                        // Toggle with animation
                        withAnimation {
                            isAnimating = true
                            // Actual lock toggle would happen here
                        }
                        
                        // Reset animation flag
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isAnimating = false
                        }
                    }) {
                        Image(systemName: lock.currentState == .locked ? "lock.open" : "lock")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
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
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Placeholder view for loading state
struct LockCellPlaceholder: View {
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 20)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 16)
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .redacted(reason: .placeholder)
    }
}

// Placeholder for AddLockView
struct AddLockView: View {
    let viewModel: AddLockViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("This is a placeholder for the Add Lock screen")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered)
            }
            .navigationTitle("Add Lock")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
} 