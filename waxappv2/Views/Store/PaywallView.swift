import StoreKit
import SwiftUI

/// The paywall: a night-blue alpine backdrop, a shelf of the real products
/// drifting gently and changing grade, what you get, and three plans.
struct PaywallView: View {
  @Environment(StoreManager.self) private var storeManager: StoreManager
  @Environment(\.dismiss) private var dismiss

  private enum Plan: String, CaseIterable { case yearly, monthly, lifetime }
  @State private var selectedPlan: Plan = .yearly

  private let privacyPolicyURL = URL(string: "https://www.squarewave.no/apps/getgrip/privacy")
  private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
  private let manageSubsURL = URL(string: "https://apps.apple.com/account/subscriptions")

  private var yearlyProduct: Product? { storeManager.yearlyProduct }
  private var monthlyProduct: Product? { storeManager.monthlyProduct }
  private var lifetimeProduct: Product? { storeManager.lifetimeProduct }
  private var selectedProduct: Product? {
    switch selectedPlan {
    case .yearly: return yearlyProduct
    case .monthly: return monthlyProduct
    case .lifetime: return lifetimeProduct
    }
  }
  private var isLifetimeSelected: Bool { selectedPlan == .lifetime }

  private var isSelectedPlanTrialEligible: Bool { selectedPlan == .yearly && storeManager.isEligibleForIntroOffer }

  private var pricePerSelectedPeriod: String {
    guard let product = selectedProduct else { return "—" }
    if isLifetimeSelected { return product.displayPrice }
    let period = storeManager.subscriptionPeriodText(for: product) ?? String(localized: selectedPlan == .yearly ? "year" : "month")
    return "\(product.displayPrice) / \(period)"
  }

  /// The yearly price as a monthly figure, shown on the yearly card.
  private var yearlyPerMonth: String? {
    guard let yearly = yearlyProduct else { return nil }
    let monthly = yearly.price / 12
    return monthly.formatted(yearly.priceFormatStyle)
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 22) {
          PaywallShelf()
            .frame(height: 180)
            .padding(.top, 4)
          header
          benefits
          plans
          purchaseSection
          footer
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
      }
      .scrollIndicators(.hidden)
      .background { PaywallBackdrop().ignoresSafeArea() }
      .environment(\.colorScheme, .dark)
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar { closeButton }
      .interactiveDismissDisabled(!storeManager.hasAccess)
      .onChange(of: storeManager.hasAccess) { _, hasAccess in
        if hasAccess { dismiss() }
      }
      .sensoryFeedback(.selection, trigger: selectedPlan)
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(spacing: 8) {
      Text("Unlock GetGrip")
        .font(.largeTitle.bold())
        .foregroundStyle(.white)

      Group {
        if storeManager.accessState == .lifetime {
          Text("Lifetime access unlocked.")
        } else if storeManager.hasAccess {
          Text("Your subscription is active.")
        } else if isLifetimeSelected {
          Text("Pay once \(pricePerSelectedPeriod) · No subscription")
        } else if isSelectedPlanTrialEligible {
          Text("Start your 14-day free trial") + Text(verbatim: "\n") + Text("Then \(pricePerSelectedPeriod)")
        } else {
          Text("\(pricePerSelectedPeriod) · Auto-renews \(selectedPlan == .yearly ? "yearly" : "monthly")")
        }
      }
      .font(.subheadline)
      .foregroundStyle(.white.opacity(0.75))
      .contentTransition(.opacity)
      .animation(.smooth(duration: 0.25), value: selectedPlan)
    }
    .multilineTextAlignment(.center)
  }

  // MARK: - Benefits

  private var benefits: some View {
    VStack(alignment: .leading, spacing: 14) {
      BenefitRow(symbol: "checkmark.seal.fill", title: "Paywall_Benefit_Right_Title", detail: "Paywall_Benefit_Right_Detail")
      BenefitRow(symbol: "snowflake", title: "Paywall_Benefit_Snow_Title", detail: "Paywall_Benefit_Snow_Detail")
      BenefitRow(symbol: "rectangle.stack.fill", title: "Paywall_Benefit_Kit_Title", detail: "Paywall_Benefit_Kit_Detail")
      BenefitRow(symbol: "widget.small", title: "Paywall_Benefit_Widget_Title", detail: "Paywall_Benefit_Widget_Detail")
    }
    .padding(.horizontal, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Plans

  private var plans: some View {
    VStack(spacing: 10) {
      PlanCard(
        title: String(localized: "Yearly"),
        price: yearlyProduct.map { $0.displayPrice + String(localized: "/yr") } ?? "—",
        detail: yearlyPerMonth.map { String(localized: "Just \($0) a month") },
        // The yearly plan's real extra is the trial; it isn't the cheapest
        // way in once Lifetime is on offer, so it isn't called "best value".
        badge: storeManager.isEligibleForIntroOffer ? String(localized: "14 days free") : nil,
        isSelected: selectedPlan == .yearly
      ) { selectedPlan = .yearly }

      PlanCard(
        title: String(localized: "Monthly"),
        price: monthlyProduct.map { $0.displayPrice + String(localized: "/mo") } ?? "—",
        detail: nil, badge: nil,
        isSelected: selectedPlan == .monthly
      ) { selectedPlan = .monthly }

      if let lifetimeProduct {
        PlanCard(
          title: String(localized: "Lifetime"),
          price: lifetimeProduct.displayPrice,
          detail: String(localized: "Pay once"),
          badge: nil,
          isSelected: isLifetimeSelected
        ) { selectedPlan = .lifetime }
        .accessibilityIdentifier("lifetimePlanButton")
      }
    }
  }

  // MARK: - Purchase

  private var purchaseSection: some View {
    VStack(spacing: 12) {
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
          .buttonStyle(.glass)
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
              Text(
                storeManager.hasAccess
                  ? "Continue"
                  : isLifetimeSelected
                    ? "Buy Lifetime" : isSelectedPlanTrialEligible ? "Start Free Trial" : "Subscribe")
            }
          }
          .font(.headline)
          .foregroundStyle(Color(red: 0.05, green: 0.12, blue: 0.27))
          .frame(maxWidth: .infinity, minHeight: 54)
          .background(.white, in: .capsule)
          .contentShape(.capsule)
        }
        .buttonStyle(.plain)
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
        .font(.footnote.weight(.medium))
        .foregroundStyle(.white.opacity(0.8))
        .accessibilityIdentifier("restorePurchasesButton")
      } else {
        ProgressView("Loading...")
          .padding(.vertical, 8)
      }
    }
  }

  private var footer: some View {
    VStack(spacing: 6) {
      HStack(spacing: 14) {
        if let manageSubsURL { Link("Manage Subscriptions", destination: manageSubsURL) }
        if let eulaURL { Link("Terms of Use", destination: eulaURL) }
        if let privacyPolicyURL { Link("Privacy Policy", destination: privacyPolicyURL) }
      }
      .font(.caption)
      .foregroundStyle(.white.opacity(0.7))

      Text(
        isLifetimeSelected
          ? "One-time purchase. Restore it on all your devices with the same Apple Account."
          : "Auto-renews until canceled. Cancel anytime in Settings.")
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.5))
        .multilineTextAlignment(.center)
    }
  }

  @ToolbarContentBuilder
  private var closeButton: some ToolbarContent {
    if storeManager.hasAccess {
      ToolbarItem(placement: .confirmationAction) {
        Button { dismiss() } label: {
          Image(systemName: "xmark")
        }
        .accessibilityLabel("Close")
      }
    }
  }
}

// MARK: - Backdrop

/// Night-blue sky over two faint mountain ranges, the same ridge printed on
/// the Pro by Swix packs.
private struct PaywallBackdrop: View {
  var body: some View {
    ZStack(alignment: .bottom) {
      LinearGradient(
        colors: [Color(red: 0.05, green: 0.12, blue: 0.27), Color(red: 0.16, green: 0.38, blue: 0.70)],
        startPoint: .top, endPoint: .bottom)
      GeometryReader { geo in
        SwixRidge(top: 0.30, depth: 0.25, isBackdrop: true)
          .fill(.white.opacity(0.035))
          .frame(height: geo.size.height * 0.55)
          .frame(maxHeight: .infinity, alignment: .bottom)
        SwixRidge(top: 0.45, depth: 0.25)
          .fill(.white.opacity(0.05))
          .frame(height: geo.size.height * 0.45)
          .frame(maxHeight: .infinity, alignment: .bottom)
      }
    }
  }
}

// MARK: - Shelf

/// Five containers standing in a row, bobbing out of step with each other.
/// Every few seconds one of them changes to another grade from its range,
/// so the whole catalogue passes through without ever being busy.
private struct PaywallShelf: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// One rotating set of products per slot: hard wax, klister, glide pack,
  /// Rode tin, liquid glide.
  private static let slots: [[String]] = [
    ["swix.V40", "swix.V30", "swix.V50", "swix.V20"],
    ["swix.KX65", "swix.KX45N", "swix.KX30", "swix.KX75"],
    ["swix.PS7", "swix.PS6", "swix.PS8", "swix.PS10"],
    ["rode.P40", "rode.P30", "rode.P50", "rode.P20"],
    ["swix.HS8L", "swix.HS6L", "swix.HS10L", "swix.HS7L"],
  ]

  @State private var tick = 0

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate
      let products = Self.slots.enumerated().compactMap { index, ids in
        WaxCatalog.product(withID: ids[(tick + index) % ids.count])
      }

      WaxShelf(products: products, height: 165)
        .modifier(BobModifier(time: time, enabled: !reduceMotion))
    }
    .task {
      guard !reduceMotion else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(4))
        withAnimation(.easeInOut(duration: 0.8)) { tick += 1 }
      }
    }
    .accessibilityHidden(true)
  }
}

/// A slow float, so the shelf feels alive rather than animated.
private struct BobModifier: ViewModifier {
  let time: TimeInterval
  let enabled: Bool

  func body(content: Content) -> some View {
    content
      .offset(y: enabled ? CGFloat(sin(time * 0.6)) * 1.5 : 0)
  }
}

// MARK: - Pieces

private struct BenefitRow: View {
  let symbol: String
  let title: LocalizedStringKey
  let detail: LocalizedStringKey

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: symbol)
        .font(.system(size: 17, weight: .regular))
        .foregroundStyle(.white.opacity(0.9))
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.white.opacity(0.7))
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

private struct PlanCard: View {
  let title: String
  let price: String
  let detail: String?
  let badge: String?
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.35)))
          .contentTransition(.symbolEffect(.replace))

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 8) {
            Text(title).font(.body.weight(.semibold))
            if let badge {
              Text(badge)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .overlay(Capsule().strokeBorder(.white.opacity(0.55), lineWidth: 1))
            }
          }
          if let detail {
            Text(detail)
              .font(.caption)
              .foregroundStyle(.white.opacity(0.6))
          }
        }

        Spacer(minLength: 8)

        Text(price)
          .font(.body.weight(.medium))
          .monospacedDigit()
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .frame(minHeight: 62)
      .background(
        .white.opacity(isSelected ? 0.14 : 0.06),
        in: .rect(cornerRadius: 16, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(.white.opacity(isSelected ? 0.9 : 0.12), lineWidth: isSelected ? 1.5 : 1)
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .animation(.smooth(duration: 0.2), value: isSelected)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}

#Preview {
  PaywallView()
    .environment(StoreManager())
}
