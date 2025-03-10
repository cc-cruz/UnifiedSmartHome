import SwiftUI

struct DevicesView: View {
    @State private var searchText = ""
    @State private var selectedFilter: DeviceFilter = .all
    
    enum DeviceFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case lights = "Lights"
        case thermostats = "Thermostats"
        case locks = "Locks"
        case cameras = "Cameras"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Filter by category
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(DeviceFilter.allCases) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Main device list
                List {
                    // Room section
                    Section(header: Text("Living Room")) {
                        DeviceListItem(name: "Smart TV", type: "TV", isOnline: true)
                        DeviceListItem(name: "Ceiling Light", type: "Light", isOnline: true)
                        DeviceListItem(name: "Air Conditioner", type: "Thermostat", isOnline: true)
                    }
                    
                    Section(header: Text("Kitchen")) {
                        DeviceListItem(name: "Refrigerator", type: "Appliance", isOnline: true)
                        DeviceListItem(name: "Microwave", type: "Appliance", isOnline: false)
                        DeviceListItem(name: "Coffee Maker", type: "Appliance", isOnline: true)
                    }
                    
                    Section(header: Text("Bedroom")) {
                        DeviceListItem(name: "Ceiling Fan", type: "Fan", isOnline: true)
                        DeviceListItem(name: "Bedside Lamp", type: "Light", isOnline: true)
                        DeviceListItem(name: "Smart Speaker", type: "Speaker", isOnline: true)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Devices")
            .searchable(text: $searchText, prompt: "Search devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Add device action
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct DeviceListItem: View {
    let name: String
    let type: String
    let isOnline: Bool
    
    var body: some View {
        HStack {
            Image(systemName: iconForType(type))
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                
                Text(type)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack {
                Circle()
                    .fill(isOnline ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                
                Text(isOnline ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundColor(isOnline ? .green : .red)
            }
        }
        .padding(.vertical, 8)
    }
    
    func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "light": return "lightbulb.fill"
        case "thermostat": return "thermometer"
        case "lock": return "lock.fill"
        case "camera": return "video.fill"
        case "speaker": return "speaker.wave.2.fill"
        case "tv": return "tv.fill"
        case "appliance": return "button.programmable"
        case "fan": return "fan.ceiling.fill"
        default: return "square.fill"
        }
    }
}

struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        DevicesView()
    }
} 