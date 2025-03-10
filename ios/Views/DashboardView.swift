import SwiftUI

struct DashboardView: View {
    @State private var selectedProperty: Property?
    
    // Demo properties for preview
    let demoProperties = [
        Property(
            id: "1",
            name: "Main Residence",
            address: Property.Address(
                street: "123 Main St",
                city: "San Francisco",
                state: "CA",
                zipCode: "94105",
                country: "USA"
            ),
            rooms: nil,
            devices: nil
        ),
        Property(
            id: "2",
            name: "Beach House",
            address: Property.Address(
                street: "456 Ocean Ave",
                city: "Malibu",
                state: "CA",
                zipCode: "90265",
                country: "USA"
            ),
            rooms: nil,
            devices: nil
        )
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Property Selector
                    Menu {
                        ForEach(demoProperties) { property in
                            Button(action: {
                                selectedProperty = property
                            }) {
                                Text(property.name)
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedProperty?.name ?? "Select Property")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Device Categories
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        CategoryCard(title: "Lighting", icon: "lightbulb.fill", color: .yellow)
                        CategoryCard(title: "Temperature", icon: "thermometer", color: .red)
                        CategoryCard(title: "Security", icon: "lock.fill", color: .blue)
                        CategoryCard(title: "Cameras", icon: "video.fill", color: .purple)
                    }
                    
                    // Favorites Section
                    Text("Favorites")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            DeviceCard(name: "Living Room Lights", icon: "lightbulb.fill", isOn: true)
                            DeviceCard(name: "Front Door Lock", icon: "lock.fill", isOn: false)
                            DeviceCard(name: "Thermostat", icon: "thermometer", isOn: true)
                            DeviceCard(name: "Kitchen Camera", icon: "video.fill", isOn: true)
                        }
                    }
                    
                    // Recent Activity
                    Text("Recent Activity")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 10) {
                        ActivityItem(title: "Front Door Unlocked", time: "2 mins ago")
                        ActivityItem(title: "Living Room Lights Turned On", time: "15 mins ago")
                        ActivityItem(title: "Thermostat Set to 72°F", time: "1 hour ago")
                    }
                }
                .padding()
            }
            .navigationTitle("Home")
        }
    }
}

struct CategoryCard: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: 100)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DeviceCard: View {
    let name: String
    let icon: String
    let isOn: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isOn ? .blue : .gray)
                
                Spacer()
                
                Circle()
                    .frame(width: 12, height: 12)
                    .foregroundColor(isOn ? .green : .red)
            }
            
            Spacer()
            
            Text(name)
                .font(.subheadline)
                .lineLimit(2)
            
            Text(isOn ? "On" : "Off")
                .font(.caption)
                .foregroundColor(isOn ? .green : .red)
        }
        .frame(width: 120, height: 120)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ActivityItem: View {
    let title: String
    let time: String
    
    var body: some View {
        HStack {
            Circle()
                .frame(width: 10, height: 10)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                
                Text(time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
} 