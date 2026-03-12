import StoreKit
import SwiftUI

struct PaywallView: View {
  @Environment(StoreManager.self) private var storeManager: StoreManager
  @Environment(\.dismiss) private var dismiss

  private enum Plan: String, CaseIterable { case yearly, monthly }
  @State private var selectedPlan: Plan = .yearly

  private let privacyPolicyURL = URL(string: "https://www.squarewave.no/apps/getgrip/privacy")
  private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
  private let manageSubsURL = URL(string: "https://apps.apple.com/account/subscriptions")

  private var yearlyProduct: Product? { storeManager.yearlyProduct }
  private var monthlyProduct: Product? { storeManager.monthlyProduct }
  private var selectedProduct: Product? { selectedPlan == .yearly ? yearlyProduct : monthlyProduct }

  private var isSelectedPlanTrialEligible: Bool { selectedPlan == .yearly && storeManager.isEligibleForIntroOffer }

  private var pricePerSelectedPeriod: String {
    guard let product = selectedProduct else { return "—" }
    let period = storeManager.subscriptionPeriodText(for: product) ?? String(localized: selectedPlan == .yearly ? "year" : "month")
    return "\(product.displayPrice) / \(period)"
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          hero
          header
          planSelector
          featureList
          purchaseSection
          footer
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
      }
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar { closeButton }
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
      .frame(maxWidth: 170)
      .accessibilityHidden(true)
      .frame(maxWidth: .infinity)
  }

  private var header: some View {
    VStack(spacing: 6) {
      Text("Unlock GetGrip")
        .font(.largeTitle.bold())

      if storeManager.hasAccess {
        Text("Your subscription is active.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else if isSelectedPlanTrialEligible {
        Text("Start your 14-day free trial")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Text("Then \(pricePerSelectedPeriod)")
          .font(.caption)
          .foregroundStyle(.primary.opacity(0.7))
      } else {
        Text("\(pricePerSelectedPeriod) · Auto-renews \(selectedPlan == .yearly ? "yearly" : "monthly")")
          .font(.subheadline)
          .foregroundStyle(.primary.opacity(0.7))
      }
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
  }

  private var planSelector: some View {
    HStack(spacing: 12) {
      planButton(title: "Yearly", subtitle: (yearlyProduct?.displayPrice as? [String])?.joined(separator: " ").appending("/yr") ?? (yearlyProduct?.displayPrice as? String).map { "\($0)/yr" } ?? "—", isSelected: selectedPlan == .yearly) { selectedPlan = .yearly }
      planButton(title: "Monthly", subtitle: (monthlyProduct?.displayPrice as? [String])?.joined(separator: " ").appending("/mo") ?? (monthlyProduct?.displayPrice as? String).map { "\($0)/mo" } ?? "—", isSelected: selectedPlan == .monthly) { selectedPlan = .monthly }
    }
    .padding(.vertical, 4)
  }

  private func planButton(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 4) {
        HStack {
          Text(title).font(.headline)
          if isSelected { Image(systemName: "checkmark.circle.fill").symbolRenderingMode(.hierarchical) }
          Spacer(minLength: 0)
        }
        HStack {
          Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
          Spacer(minLength: 0)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var featureList: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Unlimited wax & klister recommendations", systemImage: "checkmark.circle.fill")
      Label("Advanced snow type classifier", systemImage: "checkmark.circle.fill")
      Label("See recommendations for any location", systemImage: "checkmark.circle.fill")
    }
    .font(.subheadline)
    .foregroundStyle(.secondary)
    .symbolRenderingMode(.hierarchical)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var purchaseSection: some View {
    VStack(spacing: 10) {
      if let error = storeManager.productsError {
        VStack(spacing: 8) {
          Text("Unable to load subscription")
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
      } else if let product = selectedProduct {
        Button {
          Task {
            guard !storeManager.hasAccess else { dismiss(); return }
            await storeManager.purchase(product)
          }
        } label: {
          HStack(spacing: 10) {
            if storeManager.isPurchasing {
              ProgressView()
              Text("Processing...")
            } else {
              Text(storeManager.hasAccess ? "Continue" : isSelectedPlanTrialEligible ? "Start Free Trial" : "Subscribe")
              if !isSelectedPlanTrialEligible {
                Spacer(minLength: 8)
                Text(pricePerSelectedPeriod)
                  .lineLimit(1)
                  .minimumScaleFactor(0.8)
              }
            }
          }
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(storeManager.isPurchasing || storeManager.hasAccess)
        .accessibilityIdentifier("subscribeButton")

        if let purchaseError = storeManager.purchaseError {
          Text(purchaseError)
            .font(.footnote)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
        }

        Button("Restore Purchases") {
          Task { await storeManager.restorePurchases() }
        }
        .font(.footnote)
        .accessibilityIdentifier("restorePurchasesButton")
      } else {
        ProgressView("Loading...")
          .padding(.vertical, 8)
      }
    }
  }

  private var footer: some View {
    VStack(spacing: 6) {
      if let manageSubsURL {
        Link("Manage Subscriptions", destination: manageSubsURL)
          .font(.caption)
      }

      HStack(spacing: 12) {
        if let eulaURL {
          Link("Terms of Use", destination: eulaURL)
        }
        if let privacyPolicyURL {
          Link("Privacy Policy", destination: privacyPolicyURL)
        }
      }
      .font(.caption)

      Text("Auto-renews until canceled. Cancel anytime in Settings.")
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .padding(.top, 4)
  }

  @ToolbarContentBuilder
  private var closeButton: some ToolbarContent {
    if storeManager.hasAccess {
      ToolbarItem(placement: .confirmationAction) {
        Button { dismiss() } label: {
          Image(systemName: "xmark")
            .symbolRenderingMode(.hierarchical)
        }
        .accessibilityLabel("Close")
      }
    }
  }
}

#Preview {
  PaywallView()
    .environment(StoreManager())
}

