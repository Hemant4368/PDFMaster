import StoreKit
import SwiftUI

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 106, height: 106)
                        .background(AppTheme.redGradient)
                        .clipShape(Circle())
                    Text("PDF Master AI Premium")
                        .font(.system(.title, design: .rounded, weight: .heavy))
                    Text("Unlimited scans, OCR export, unlimited merge, watermark tools, and AI-ready document workflows.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 12) {
                    premiumRow("Unlimited scans", "viewfinder")
                    premiumRow("OCR export", "text.viewfinder")
                    premiumRow("Watermark control", "stamp")
                    premiumRow("Unlimited merge", "square.stack.3d.down.forward")
                    premiumRow("AI OCR summary ready", "sparkles")
                }
                .premiumCard()

                if subscriptionManager.products.isEmpty {
                    Text("StoreKit products are not loaded. Configure pdfmasterai.monthly and pdfmasterai.yearly in App Store Connect or a StoreKit configuration file.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .premiumCard()
                } else {
                    ForEach(subscriptionManager.products, id: \.id) { product in
                        Button {
                            Task {
                                do { try await subscriptionManager.purchase(product) }
                                catch { errorMessage = error.localizedDescription }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(product.displayName).font(.headline)
                                    Text(product.description).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(product.displayPrice).bold()
                            }
                            .premiumCard()
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button("Restore Purchases") {
                    Task { await subscriptionManager.refreshEntitlements() }
                }
                .foregroundStyle(AppTheme.primary)
            }
            .padding(20)
        }
        .navigationTitle("Premium")
        .toolbar { Button("Done") { dismiss() } }
        .task { await subscriptionManager.loadProducts() }
        .alert("Subscription", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func premiumRow(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}
