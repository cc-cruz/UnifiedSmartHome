import SwiftUI

struct AutomationsView: View {
    @State private var automations = [
        Automation(id: "1", name: "Morning Routine", triggers: ["6:00 AM"], isEnabled: true),
        Automation(id: "2", name: "Leaving Home", triggers: ["Location"], isEnabled: true),
        Automation(id: "3", name: "Movie Night", triggers: ["Manual"], isEnabled: false),
        Automation(id: "4", name: "Bedtime", triggers: ["10:00 PM"], isEnabled: true)
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(automations) { automation in
                        AutomationRow(automation: automation)
                    }
                } header: {
                    Text("My Routines")
                }
                
                Section {
                    NavigationLink(destination: Text("Add new automation")) {
                        Label("Create new automation", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Automations")
        }
    }
}

struct Automation: Identifiable {
    let id: String
    let name: String
    let triggers: [String]
    var isEnabled: Bool
}

struct AutomationRow: View {
    @State var automation: Automation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(automation.name)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(automation.triggers.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $automation.isEnabled)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Navigate to automation detail view
        }
    }
}

struct AutomationsView_Previews: PreviewProvider {
    static var previews: some View {
        AutomationsView()
    }
} 