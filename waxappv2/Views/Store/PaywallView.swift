import Observation
import StoreKit
import SwiftUI

struct PaywallView: View {
  @Environment(StoreManager.self) private var storeManager: StoreManager
  @Environment(\.dismiss) private var dismiss

  // MARK: - Constants (App Review-friendly, explicit)

  private let heroMaxWidth: CGFloat = 170
  private let horizontalPadding: CGFloat = 24

  // From your ASC / config:
  private let subscriptionDisplayNameFallback = "Annual subscription"
  private let subscriptionDurationFallback = "1 year"

  // Required links (in-app)
  private let privacyPolicyURL = URL(string: "https://www.squarewave.no/apps/getgrip/privacy")
  private let appleStandardEULAURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
  private let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")

  // MARK: - Computed

  private var product: Product? { storeManager.primaryProduct }

  private var durationText: String {
    if let p = product, let t = storeManager.subscriptionPeriodText(for: p), !t.isEmpty {
      return t
    }
    return subscriptionDurationFallback
  }

  private var priceText: String {
    product?.displayPrice ?? "—"
  }

  private var titleText: String {
    // App Review wants the subscription title; this is best as Product.displayName.
    // Fallback keeps the UI explicit even if products fail to load.
    product?.displayName ?? subscriptionDisplayNameFallback
  }

  private var pricePerPeriodLine: String {
    "\(priceText) / \(durationText)"
  }

  private var primaryButtonTitle: String {
    storeManager.hasAccess ? "Continue" : "Subscribe"
  }

  private var unlocksHeaderText: String {
    storeManager.hasAccess ? "Included in your subscription" : "Subscribe to unlock"
  }

  private var renewalDisclosureText: String {
    // Keep clear and consistent with Apple guidance.
    "Payment will be charged to your Apple ID at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period."
  }

  private var cancelDisclosureText: String {
    "You can manage or cancel your subscription in Apple ID Settings at any time."
  }

  // MARK: - View

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          hero

          header

          unlocksSection

          purchaseSection

          legalLinksSection
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 18)
      }
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar { closeButtonIfEligible }
      .interactiveDismissDisabled(!storeManager.hasAccess)
      .onChange(of: storeManager.hasAccess) { _, hasAccess in
        if hasAccess { dismiss() }
      }
    }
  }

  // MARK: - Subviews

  private var hero: some View {
    Image("post-introduction-background")
      .resizable()
      .scaledToFit()
      .frame(maxWidth: heroMaxWidth)
      .accessibilityHidden(true)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 2)
  }

  private var header: some View {
    VStack(spacing: 8) {
      Text("Unlock GetGrip")
        .font(.largeTitle.bold())
        .multilineTextAlignment(.center)

      Text(storeManager.hasAccess
           ? "Your subscription is active."
           : "Get full access with an auto-renewable annual subscription. Cancel anytime.")
      .font(.body)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)

      // Explicit subscription “what/price/length” line (App Review requirement)
      VStack(spacing: 4) {
        Text("\(titleText) • \(pricePerPeriodLine)")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)

        Text("Auto-renews until canceled.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.top, 2)
    }
    .frame(maxWidth: .infinity)
  }

  private var unlocksSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(unlocksHeaderText)
        .font(.headline)

      VStack(alignment: .leading, spacing: 8) {
        Label("Unlimited wax & klister recommendations", systemImage: "checkmark.circle.fill")
        Label("Snow + temperature guidance", systemImage: "checkmark.circle.fill")
        Label("Forecast planning tools", systemImage: "checkmark.circle.fill")
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .symbolRenderingMode(.hierarchical)

      // A very explicit “this is what you receive for the price” sentence
      Text("This subscription unlocks the features listed above for the duration of your subscription.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 4)
  }

  private var purchaseSection: some View {
    VStack(spacing: 12) {
      if let error = storeManager.productsError {
        VStack(spacing: 8) {
          Text("Unable to Load Subscription")
            .font(.headline)

          Text(error)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

          Button("Try Again") {
            Task { await storeManager.retryFetchProducts() }
          }
          .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)

        // Even if products fail to load, keep required disclosures + links visible.
        disclosuresBlock
      } else if let product {
        Button {
          Task {
            guard !storeManager.hasAccess else {
              dismiss()
              return
            }
            await storeManager.purchase(product)
          }
        } label: {
          HStack(spacing: 10) {
            if storeManager.isPurchasing {
              ProgressView()
              Text("Processing…")
            } else {
              Text(primaryButtonTitle)
              Spacer(minLength: 8)
              Text(pricePerPeriodLine)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
          }
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(storeManager.isPurchasing || storeManager.hasAccess)

        if let purchaseError = storeManager.purchaseError {
          Text(purchaseError)
            .font(.footnote)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }

        Button("Restore Purchases") {
          Task { await storeManager.restorePurchases() }
        }
        .font(.footnote)

        if let manageSubscriptionsURL {
          Link("Manage Subscriptions", destination: manageSubscriptionsURL)
            .font(.footnote)
        }

        disclosuresBlock
      } else {
        ProgressView("Loading…")
          .padding(.vertical, 8)

        disclosuresBlock
      }
    }
    .padding(.top, 2)
  }

  private var disclosuresBlock: some View {
    VStack(spacing: 8) {
      Text(renewalDisclosureText)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      Text(cancelDisclosureText)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.top, 4)
  }

  private var legalLinksSection: some View {
    VStack(spacing: 8) {
      HStack(spacing: 12) {
        if let appleStandardEULAURL {
          Link("Terms of Use", destination: appleStandardEULAURL)
        }
        if let privacyPolicyURL {
          Link("Privacy Policy", destination: privacyPolicyURL)
        }
      }
      .font(.caption2)

      Text("By continuing, you agree to the Terms of Use and Privacy Policy.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.top, 6)
  }

  @ToolbarContentBuilder
  private var closeButtonIfEligible: some ToolbarContent {
    if storeManager.hasAccess {
      #if os(iOS)
      ToolbarItem(placement: .topBarTrailing) {
        Button { dismiss() } label: {
          Image(systemName: "xmark")
            .symbolRenderingMode(.hierarchical)
        }
        .accessibilityLabel("Close")
      }
      #else
      ToolbarItem(placement: .primaryAction) {
        Button { dismiss() } label: {
          Image(systemName: "xmark")
            .symbolRenderingMode(.hierarchical)
        }
        .accessibilityLabel("Close")
      }
      #endif
    }
  }
}

#Preview {
  PaywallView()
    .environment(StoreManager())
}
