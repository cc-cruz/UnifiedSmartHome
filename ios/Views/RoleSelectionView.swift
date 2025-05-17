import SwiftUI
import Sources.Models

struct RoleSelectionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var userContext: UserContextViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Who are you managing as today?")
                .font(.title)
                .padding(.top, 40)
            
            ForEach(Array(availableRoles), id: \ .self) { role in
                Button(action: {
                    userContext.selectedRole = role
                }) {
                    HStack {
                        Image(systemName: icon(for: role))
                            .foregroundColor(.blue)
                        Text(displayName(for: role))
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    var availableRoles: Set<User.Role> {
        Set(authViewModel.currentUser?.roleAssociations?.map { $0.roleWithinEntity } ?? [])
    }
    
    func displayName(for role: User.Role) -> String {
        switch role {
        case .owner: return "Homeowner"
        case .propertyManager: return "Property Manager"
        case .tenant: return "Tenant"
        case .guest: return "Guest"
        case .portfolioAdmin: return "Portfolio Admin"
        }
    }
    
    func icon(for role: User.Role) -> String {
        switch role {
        case .owner: return "house.fill"
        case .propertyManager: return "person.2.fill"
        case .tenant: return "person.fill"
        case .guest: return "person.crop.circle.badge.questionmark"
        case .portfolioAdmin: return "briefcase.fill"
        }
    }
}

struct RoleSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        RoleSelectionView()
            .environmentObject(AuthViewModel())
            .environmentObject(UserContextViewModel())
    }
} 