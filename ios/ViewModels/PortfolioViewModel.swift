import Foundation
import Combine
import Sources.Models

class PortfolioViewModel: ObservableObject {
    @Published var portfolios: [Portfolio] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var selectedPortfolioId: String? = nil

    private var cancellables = Set<AnyCancellable>()
    private let apiService: APIService

    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }

    func fetchPortfolios(for user: User, role: User.Role) {
        isLoading = true
        error = nil
        apiService.getPortfolios()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.error = err.localizedDescription
                }
            } receiveValue: { [weak self] portfolios in
                // Optionally filter portfolios by role/association
                let filtered = portfolios.filter { p in
                    user.roleAssociations?.contains(where: { $0.associatedEntityType == .portfolio && $0.associatedEntityId == p.id && $0.roleWithinEntity == role }) ?? false
                }
                self?.portfolios = filtered
            }
            .store(in: &cancellables)
    }

    func selectPortfolio(_ id: String) {
        selectedPortfolioId = id
    }
} 