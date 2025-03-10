import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var notificationsEnabled = true
    @State private var locationServicesEnabled = true
    @State private var darkModeEnabled = false
    @State private var autoLockTime = 5
    
    let autoLockOptions = [1, 5, 10, 15, 30, 60]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Account")) {
                    NavigationLink(destination: AccountDetailsView()) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("John Smith")
                                    .font(.headline)
                                
                                Text("Property Manager")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                Section(header: Text("Properties")) {
                    NavigationLink(destination: PropertyManagementView()) {
                        Label("Property Management", systemImage: "building.2.fill")
                    }
                    
                    NavigationLink(destination: Text("User Access Management")) {
                        Label("User Access", systemImage: "person.2.fill")
                    }
                }
                
                Section(header: Text("Connected Services")) {
                    ForEach(connectedServices) { service in
                        Label {
                            HStack {
                                Text(service.name)
                                Spacer()
                                Text(service.status)
                                    .font(.caption)
                                    .foregroundColor(service.isConnected ? .green : .red)
                            }
                        } icon: {
                            Image(systemName: service.icon)
                                .foregroundColor(service.color)
                        }
                    }
                    
                    NavigationLink(destination: Text("Connect New Service")) {
                        Label("Connect New Service", systemImage: "plus.circle")
                            .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("App Settings")) {
                    Toggle("Notifications", isOn: $notificationsEnabled)
                    
                    Toggle("Location Services", isOn: $locationServicesEnabled)
                    
                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                    
                    Picker("Auto-Lock After", selection: $autoLockTime) {
                        ForEach(autoLockOptions, id: \.self) { minute in
                            Text(minute == 1 ? "1 minute" : "\(minute) minutes")
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        authViewModel.logout()
                    }) {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    struct ConnectedService: Identifiable {
        let id = UUID()
        let name: String
        let status: String
        let icon: String
        let isConnected: Bool
        let color: Color
    }
    
    let connectedServices = [
        ConnectedService(name: "Samsung SmartThings", status: "Connected", icon: "checkmark.circle.fill", isConnected: true, color: .blue),
        ConnectedService(name: "Google Nest", status: "Connected", icon: "checkmark.circle.fill", isConnected: true, color: .blue),
        ConnectedService(name: "Philips Hue", status: "Connected", icon: "checkmark.circle.fill", isConnected: true, color: .blue),
        ConnectedService(name: "Amazon Alexa", status: "Disconnected", icon: "xmark.circle.fill", isConnected: false, color: .red),
        ConnectedService(name: "Apple HomeKit", status: "Connected", icon: "checkmark.circle.fill", isConnected: true, color: .blue)
    ]
}

struct AccountDetailsView: View {
    @State private var firstName = "John"
    @State private var lastName = "Smith"
    @State private var email = "john.smith@example.com"
    @State private var phone = "(555) 123-4567"
    
    var body: some View {
        Form {
            Section(header: Text("Personal Information")) {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
            }
            
            Section {
                Button("Change Password") {
                    // Show change password screen
                }
                .foregroundColor(.blue)
            }
            
            Section {
                Button("Save Changes") {
                    // Save changes
                }
                .foregroundColor(.blue)
            }
        }
        .navigationTitle("Account Details")
    }
}

struct PropertyManagementView: View {
    let properties = [
        "Main Residence",
        "Beach House",
        "Mountain Cabin",
        "Downtown Apartment"
    ]
    
    var body: some View {
        List {
            ForEach(properties, id: \.self) { property in
                NavigationLink(destination: Text("Property Details for \(property)")) {
                    Text(property)
                }
            }
            
            Button(action: {
                // Add new property
            }) {
                Label("Add New Property", systemImage: "plus.circle")
                    .foregroundColor(.blue)
            }
        }
        .navigationTitle("Properties")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthViewModel())
    }
} 