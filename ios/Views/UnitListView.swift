import SwiftUI
import Sources.Models

struct UnitListView: View {
    @ObservedObject var viewModel: UnitViewModel
    @EnvironmentObject var userContext: UserContextViewModel

    var body: some View {
        VStack {
            Text("Select a Unit")
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
                List(viewModel.units, id: \.id) { unit in
                    Button(action: {
                        viewModel.selectUnit(unit.id)
                        userContext.selectedUnitId = unit.id
                    }) {
                        HStack {
                            Text(unit.name)
                            Spacer()
                            if userContext.selectedUnitId == unit.id {
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
            if let propertyId = userContext.selectedPropertyId, viewModel.units.isEmpty {
                viewModel.fetchUnits(forProperty: propertyId)
            }
        }
    }
} 