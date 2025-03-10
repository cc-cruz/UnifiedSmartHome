import SwiftUI

struct ActivityView: View {
    @State private var selectedTimeFilter: TimeFilter = .today
    
    enum TimeFilter: String, CaseIterable {
        case today = "Today"
        case yesterday = "Yesterday"
        case week = "This Week"
        case month = "This Month"
        
        var id: String { self.rawValue }
    }
    
    let activities = [
        Activity(id: "1", deviceName: "Front Door Lock", action: "Unlocked", timestamp: Date(), by: "John Smith"),
        Activity(id: "2", deviceName: "Living Room Lights", action: "Turned On", timestamp: Date().addingTimeInterval(-3600), by: "System"),
        Activity(id: "3", deviceName: "Thermostat", action: "Temperature set to 72°F", timestamp: Date().addingTimeInterval(-7200), by: "Jane Doe"),
        Activity(id: "4", deviceName: "Kitchen Camera", action: "Motion Detected", timestamp: Date().addingTimeInterval(-10800), by: "System"),
        Activity(id: "5", deviceName: "Garage Door", action: "Opened", timestamp: Date().addingTimeInterval(-18000), by: "John Smith"),
        Activity(id: "6", deviceName: "Backyard Lights", action: "Turned Off", timestamp: Date().addingTimeInterval(-21600), by: "System")
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Time filter picker
                Picker("Time Range", selection: $selectedTimeFilter) {
                    ForEach(TimeFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                List {
                    ForEach(activities) { activity in
                        ActivityRow(activity: activity)
                    }
                }
            }
            .navigationTitle("Activity")
        }
    }
}

struct Activity: Identifiable {
    let id: String
    let deviceName: String
    let action: String
    let timestamp: Date
    let by: String
}

struct ActivityRow: View {
    let activity: Activity
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 15) {
            // Activity icon based on device/action
            Image(systemName: iconForActivity(activity))
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(colorForActivity(activity))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text("\(activity.deviceName) - \(activity.action)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("By \(activity.by) at \(dateFormatter.string(from: activity.timestamp))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    func iconForActivity(_ activity: Activity) -> String {
        if activity.deviceName.contains("Lock") {
            return activity.action.contains("Unlock") ? "lock.open.fill" : "lock.fill"
        } else if activity.deviceName.contains("Light") {
            return activity.action.contains("On") ? "lightbulb.fill" : "lightbulb.slash"
        } else if activity.deviceName.contains("Thermostat") {
            return "thermometer"
        } else if activity.deviceName.contains("Camera") {
            return "video.fill"
        } else if activity.deviceName.contains("Door") {
            return activity.action.contains("Open") ? "door.right.hand.open" : "door.right.hand.closed"
        }
        return "circle.fill"
    }
    
    func colorForActivity(_ activity: Activity) -> Color {
        if activity.deviceName.contains("Lock") {
            return .blue
        } else if activity.deviceName.contains("Light") {
            return .yellow
        } else if activity.deviceName.contains("Thermostat") {
            return .red
        } else if activity.deviceName.contains("Camera") {
            return .purple
        } else if activity.deviceName.contains("Door") {
            return .green
        }
        return .gray
    }
}

struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView()
    }
} 