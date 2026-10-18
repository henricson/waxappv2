//
//  AboutView.swift
//  waxappv2
//

import StoreKit
import SwiftUI

struct AboutView: View {
  @Environment(StoreManager.self) private var storeManager
  @Environment(RecommendationStore.self) private var recStore
  @Environment(WaxSelectionStore.self) private var waxStore
  @Environment(\.requestReview) private var requestReview
  @Environment(\.dismiss) private var dismiss

  @State private var showPaywall = false
  @State private var temperatureUnit = TemperaturePreference.currentUnit()

  private var appVersion: String {
    let version =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    return "\(version) (\(build))"
  }

  var body: some View {
    NavigationStack {
      List {
        subscriptionSection
        waxSection
        preferencesSection
        dataSection
        developerSection
        legalSection
      }
      .navigationTitle("Settings")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .sheet(isPresented: $showPaywall) { PaywallView() }
    }
  }

  // MARK: - Subscription

  @ViewBuilder
  private var subscriptionSection: some View {
    Section("Subscription status") {
      switch storeManager.accessState {
      case .loading:
        Label("Checking subscription…", systemImage: "clock")
          .foregroundStyle(.secondary)
      case .trialActive(let daysLeft):
        Label("Free Trial Active", systemImage: "clock")
          .foregroundStyle(.green)
        Text("\(daysLeft) days left in trial")
          .font(.subheadline)
          .foregroundStyle(daysLeft <= 4 ? .red : .green)
          .accessibilityLabel("\(daysLeft) days left in trial")
      case .subscribed:
        Label("Subscription active", systemImage: "checkmark.seal.fill")
          .foregroundStyle(.green)
      case .lifetime:
        Label("Lifetime access", systemImage: "infinity.circle.fill")
          .foregroundStyle(.green)
        if storeManager.hasRedundantSubscription {
          Text("You also have a subscription that is still renewing. Cancel it in Manage Subscription to avoid paying twice.")
            .font(.footnote)
            .foregroundStyle(.orange)
        }
      case .gracePeriod:
        Label("Subscription in grace period", systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
      case .billingRetry:
        Label("Payment issue", systemImage: "creditcard.trianglebadge.exclamationmark")
          .foregroundStyle(.orange)
      case .expired, .revoked, .notSubscribed:
        Label("No active subscription", systemImage: "lock")
          .foregroundStyle(.secondary)

        Button {
          showPaywall = true
        } label: {
          Label("Start free trial", systemImage: "arrow.up.circle")
        }
      }

      if storeManager.hasAccess
        && (storeManager.accessState != .lifetime || storeManager.hasRedundantSubscription)
      {
        Button {
          Task { await showManageSubscriptions() }
        } label: {
          Label("Manage Subscription", systemImage: "gearshape")
        }
      }
    }
  }

  // MARK: - Wax

  private var waxSection: some View {
    Section {
      NavigationLink {
        WaxSelectionView()
      } label: {
        LabeledContent {
          Text("\(waxStore.visibleProducts.count)")
            .foregroundStyle(.secondary)
        } label: {
          Label("Wax library", systemImage: "square.stack.3d.up")
        }
      }

      Button {
        waxStore.resetToDefaults()
      } label: {
        Label("Reset to recommended kit", systemImage: "arrow.counterclockwise")
      }

      Button {
        // Close Settings first: the introduction is a full-screen cover on
        // the root, and can't appear while this sheet is still up.
        Task {
          dismiss()
          try? await Task.sleep(for: .milliseconds(450))
          waxStore.resetOnboarding()
        }
      } label: {
        Label("Show introduction again", systemImage: "sparkles")
      }
      .accessibilityIdentifier("showOnboardingAgain")
    } header: {
      Text("Your waxes")
    } footer: {
      Text("Choose which brands and series appear in recommendations and on the chart.")
    }
  }

  // MARK: - Preferences

  private var preferencesSection: some View {
    Section {
      Toggle(isOn: advancedBinding) {
        Label("Explain recommendations", systemImage: "text.magnifyingglass")
      }

      Picker(selection: unitBinding) {
        ForEach(TemperatureUnit.allCases) { unit in
          Text(unit.symbol).tag(unit)
        }
      } label: {
        Label("Temperature unit", systemImage: "thermometer.medium")
      }
      .pickerStyle(.menu)
    } header: {
      Text("Preferences")
    } footer: {
      Text(
        "Turn on explanations to see the temperature, snow and weather factors behind each pick."
      )
    }
  }

  private var advancedBinding: Binding<Bool> {
    Binding(
      get: { recStore.isAdvancedMode },
      set: { recStore.isAdvancedMode = $0 }
    )
  }

  private var unitBinding: Binding<TemperatureUnit> {
    Binding(
      get: { temperatureUnit },
      set: { newValue in
        temperatureUnit = newValue
        TemperaturePreference.setUnit(newValue)
      }
    )
  }

  // MARK: - Data

  private var dataSection: some View {
    Section {
      LabeledContent("Weather", value: "Apple Weather")
      LabeledContent("Wax data", value: "Swix, Rode")
    } header: {
      Text("Data sources")
    } footer: {
      Text(
        "Temperature ranges follow each manufacturer's published charts. Always test on snow — local conditions vary."
      )
    }
  }

  // MARK: - Developer

  private var developerSection: some View {
    Section("Developer") {
      // Lets a tester read why a widget shows no weather, without a cable.
      if let diagnostics = WidgetDiagnostics.load() {
        DisclosureGroup("Widget status") {
          LabeledContent("Last refresh", value: diagnostics.date.formatted(date: .abbreviated, time: .shortened))
          LabeledContent("Place", value: [diagnostics.placeName, diagnostics.placeSource].compactMap { $0 }.joined(separator: " · "))
          LabeledContent("Result", value: diagnostics.result)
          if let error = diagnostics.weatherError {
            Text(error)
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }
        }
      }
      Link(destination: URL(string: "https://www.squarewave.no")!) {
        Text("Square Wave AS")
      }

      Button {
        requestReview()
      } label: {
        Label("Rate GetGrip", systemImage: "star")
      }

      LabeledContent("Version", value: appVersion)
    }
  }

  // MARK: - Legal

  private var legalSection: some View {
    Section("Legal") {
      Link(destination: URL(string: "https://www.squarewave.no/apps/getgrip/terms")!) {
        Text("Terms of Service")
      }
      Link(destination: URL(string: "https://www.squarewave.no/apps/getgrip/privacy")!) {
        Text("Privacy Policy")
      }
    }
  }

  // MARK: - Actions

  @MainActor
  private func showManageSubscriptions() async {
    #if os(iOS)
      guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
      else { return }
      try? await AppStore.showManageSubscriptions(in: windowScene)
    #else
      try? await AppStore.showManageSubscriptions()
    #endif
  }
}

#Preview {
  let app = AppState()

  AboutView()
    .environment(app.storeManager)
    .environment(app.recommendation)
    .environment(app.waxSelection)
}
