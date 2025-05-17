import Foundation
import Combine
import Sources.Models

class UnitViewModel: ObservableObject {
    @Published var units: [Unit] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var selectedUnitId: String? = nil

    private var cancellables = Set<AnyCancellable>()
    private let apiService: APIService

    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }

    func fetchUnits(forProperty propertyId: String) {
        isLoading = true
        error = nil
        apiService.getUnits(propertyId: propertyId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.error = err.localizedDescription
                }
            } receiveValue: { [weak self] units in
                self?.units = units
            }
            .store(in: &cancellables)
    }

    func selectUnit(_ id: String) {
        selectedUnitId = id
    }
} 