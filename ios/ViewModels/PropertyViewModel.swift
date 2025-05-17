import Foundation
import Combine
import Sources.Models

class PropertyViewModel: ObservableObject {
    @Published var properties: [Property] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var selectedPropertyId: String? = nil

    private var cancellables = Set<AnyCancellable>()
    private let apiService: APIService

    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }

    func fetchProperties(forPortfolio portfolioId: String) {
        isLoading = true
        error = nil
        apiService.getProperties(portfolioId: portfolioId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.error = err.localizedDescription
                }
            } receiveValue: { [weak self] props in
                self?.properties = props
            }
            .store(in: &cancellables)
    }

    func selectProperty(_ id: String) {
        selectedPropertyId = id
    }
} 