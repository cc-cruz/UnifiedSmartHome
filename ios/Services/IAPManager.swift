import Foundation
import StoreKit
import Combine

@MainActor
class IAPManager: NSObject, ObservableObject {
    static let shared = IAPManager()
    
    // MARK: - Published Properties
    @Published var products: [SKProduct] = []
    @Published var purchasedProducts: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Product Identifiers
    static let compliancePackProductID = "com.unifiedsmarthome.compliancepack1"
    
    // MARK: - Computed Properties
    var compliancePackProduct: SKProduct? {
        products.first { $0.productIdentifier == Self.compliancePackProductID }
    }
    
    var hasCompliancePack: Bool {
        purchasedProducts.contains(Self.compliancePackProductID)
    }
    
    // MARK: - Dependencies
    private let userManager: UserManager
    private let apiService: APIService
    
    // MARK: - Private Properties
    private var productsRequest: SKProductsRequest?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        self.userManager = UserManager.shared
        self.apiService = APIService()
        super.init()
        
        SKPaymentQueue.default().add(self)
        loadPurchasedProducts()
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    // MARK: - Public Methods
    
    func fetchProducts() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        let productIdentifiers: Set<String> = [Self.compliancePackProductID]
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest?.delegate = self
        productsRequest?.start()
    }
    
    func purchaseProduct(_ product: SKProduct) {
        guard SKPaymentQueue.canMakePayments() else {
            errorMessage = "In-App Purchases are not allowed on this device."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    func restorePurchases() {
        isLoading = true
        errorMessage = nil
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    // MARK: - Private Methods
    
    private func loadPurchasedProducts() {
        // Load from UserDefaults as a backup
        if let savedPurchases = UserDefaults.standard.object(forKey: "PurchasedProducts") as? [String] {
            purchasedProducts = Set(savedPurchases)
        }
        
        // Also check user's backend status if available
        if let currentUser = userManager.currentUser, currentUser.hasCompliancePack {
            purchasedProducts.insert(Self.compliancePackProductID)
        }
    }
    
    private func savePurchasedProducts() {
        UserDefaults.standard.set(Array(purchasedProducts), forKey: "PurchasedProducts")
    }
    
    private func handleSuccessfulPurchase(productIdentifier: String, transaction: SKPaymentTransaction) {
        // Add to purchased products
        purchasedProducts.insert(productIdentifier)
        savePurchasedProducts()
        
        // Validate receipt with backend
        Task {
            await validateReceiptWithBackend(productIdentifier: productIdentifier)
        }
        
        // Finish the transaction
        SKPaymentQueue.default().finishTransaction(transaction)
        isLoading = false
    }
    
    private func validateReceiptWithBackend(productIdentifier: String) async {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            print("Could not load receipt data")
            return
        }
        
        let receiptString = receiptData.base64EncodedString()
        
        do {
            // Call backend validation endpoint (to be implemented)
            let response = try await apiService.validateReceipt(
                receiptData: receiptString,
                productId: productIdentifier
            )
            
            // Update user's compliance pack status
            if let updatedUser = response.user {
                await MainActor.run {
                    userManager.updateCurrentUser(updatedUser)
                }
            }
            
            print("Receipt validation successful")
        } catch {
            print("Receipt validation failed: \(error)")
            // For now, we'll still allow the feature locally
            // In production, you might want to be more strict
        }
    }
}

// MARK: - SKProductsRequestDelegate
extension IAPManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.products = response.products
            self.isLoading = false
            
            if !response.invalidProductIdentifiers.isEmpty {
                print("Invalid product identifiers: \(response.invalidProductIdentifiers)")
                self.errorMessage = "Some products could not be loaded."
            }
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }
}

// MARK: - SKPaymentTransactionObserver
extension IAPManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                handleSuccessfulPurchase(
                    productIdentifier: transaction.payment.productIdentifier,
                    transaction: transaction
                )
                
            case .restored:
                purchasedProducts.insert(transaction.payment.productIdentifier)
                savePurchasedProducts()
                SKPaymentQueue.default().finishTransaction(transaction)
                
            case .failed:
                if let error = transaction.error as? SKError {
                    if error.code != .paymentCancelled {
                        DispatchQueue.main.async {
                            self.errorMessage = "Purchase failed: \(error.localizedDescription)"
                        }
                    }
                }
                SKPaymentQueue.default().finishTransaction(transaction)
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                
            case .purchasing:
                // Transaction is being processed
                break
                
            case .deferred:
                // Transaction is in the queue, but its final status is pending external action
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                
            @unknown default:
                break
            }
        }
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Receipt Validation Response
struct ReceiptValidationResponse: Codable {
    let status: String
    let message: String
    let user: User?
} 