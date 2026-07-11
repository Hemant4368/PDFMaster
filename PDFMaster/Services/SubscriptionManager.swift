import Foundation
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published var isLoading = false

    let productIDs = ["pdfmasterai.monthly", "pdfmasterai.yearly"]

    var hasPremium: Bool { !purchasedProductIDs.isEmpty }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: productIDs)
            await refreshEntitlements()
        } catch {
            products = []
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        if case let .success(.verified(transaction)) = result {
            purchasedProductIDs.insert(transaction.productID)
            await transaction.finish()
        }
    }

    func refreshEntitlements() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result, productIDs.contains(transaction.productID) {
                ids.insert(transaction.productID)
            }
        }
        purchasedProductIDs = ids
    }
}
