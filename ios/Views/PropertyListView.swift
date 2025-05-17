import SwiftUI
import Sources.Models

struct PropertyListView: View {
    @ObservedObject var viewModel: PropertyViewModel
    @EnvironmentObject var userContext: UserContextViewModel

    var body: some View {
        VStack {
            Text("Select a Property")
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
                List(viewModel.properties, id: \.id) { property in
                    Button(action: {
                        viewModel.selectProperty(property.id)
                        userContext.selectedPropertyId = property.id
                    }) {
                        HStack {
                            Text(property.name)
                            Spacer()
                            if userContext.selectedPropertyId == property.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .onAppear {
            if let portfolioId = userContext.selectedPortfolioId, viewModel.properties.isEmpty {
                viewModel.fetchProperties(forPortfolio: portfolioId)
            }
        }
    }
} 