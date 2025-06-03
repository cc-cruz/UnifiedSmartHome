import Foundation
import StoreKit
import Combine

@MainActor
class IAPViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingPurchaseSuccess = false
    @Published var showingPurchaseError = false
    
    // MARK: - Dependencies
    private let iapManager: IAPManager
    private let userManager: UserManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var compliancePackProduct: SKProduct? {
        iapManager.compliancePackProduct
    }
    
    var hasCompliancePack: Bool {
        // Check both IAP manager and user manager for consistency
        return iapManager.hasCompliancePack || (userManager.currentUser?.hasCompliancePack ?? false)
    }
    
    var compliancePackPrice: String {
        guard let product = compliancePackProduct else { return "$0.99" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "$0.99"
    }
    
    var compliancePackTitle: String {
        compliancePackProduct?.localizedTitle ?? "Compliance Pack"
    }
    
    var compliancePackDescription: String {
        compliancePackProduct?.localizedDescription ?? "Advanced compliance reporting and analytics for your smart home devices."
    }
    
    // MARK: - Initialization
    init(iapManager: IAPManager = .shared, userManager: UserManager = .shared) {
        self.iapManager = iapManager
        self.userManager = userManager
        
        setupBindings()
        
        // Fetch products when initialized
        Task {
            await fetchProducts()
        }
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Observe IAP manager loading state
        iapManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        // Observe IAP manager errors
        iapManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                self?.errorMessage = errorMessage
                self?.showingPurchaseError = errorMessage != nil
            }
            .store(in: &cancellables)
        
        // Observe successful purchases
        iapManager.$purchasedProducts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] purchasedProducts in
                if purchasedProducts.contains(IAPManager.compliancePackProductID) {
                    self?.showingPurchaseSuccess = true
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func fetchProducts() async {
        iapManager.fetchProducts()
    }
    
    func purchaseCompliancePack() {
        guard let product = compliancePackProduct else {
            errorMessage = "Product not available. Please try again later."
            showingPurchaseError = true
            return
        }
        
        iapManager.purchaseProduct(product)
    }
    
    func restorePurchases() {
        iapManager.restorePurchases()
    }
    
    func dismissError() {
        errorMessage = nil
        showingPurchaseError = false
    }
    
    func dismissSuccess() {
        showingPurchaseSuccess = false
    }
    
    // MARK: - Compliance Feature Access
    
    /// Check if user can access compliance features
    var canAccessComplianceFeatures: Bool {
        return hasCompliancePack
    }
    
    /// Get compliance feature status message
    var complianceFeatureStatusMessage: String {
        if hasCompliancePack {
            return "Compliance Pack Active"
        } else {
            return "Upgrade to access compliance features"
        }
    }
} 