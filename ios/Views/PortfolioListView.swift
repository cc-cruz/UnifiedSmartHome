import SwiftUI
import Sources.Models

struct PortfolioListView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @EnvironmentObject var userContext: UserContextViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack {
            Text("Select a Property Group")
                .font(.title2)
                .padding(.top, 32)

            if viewModel.isLoading {
                ProgressView("Loading...")
                    .padding()
            } else if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                List(viewModel.portfolios, id: \.id) { portfolio in
                    Button(action: {
                        viewModel.selectPortfolio(portfolio.id)
                        userContext.selectedPortfolioId = portfolio.id
                    }) {
                        HStack {
                            Text(portfolio.name)
                            Spacer()
                            if userContext.selectedPortfolioId == portfolio.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .onAppear {
            if viewModel.portfolios.isEmpty, let user = authViewModel.currentUser, let role = userContext.selectedRole {
                viewModel.fetchPortfolios(for: user, role: role)
            }
        }
        .padding(.horizontal, 16)
    }
} 