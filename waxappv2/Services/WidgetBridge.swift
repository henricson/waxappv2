//
//  WidgetBridge.swift
//  waxappv2
//
//  Publishes what the widgets need into the App Group and asks WidgetKit
//  to redraw, but only when something they show has actually changed.
//

import WidgetKit

@MainActor
enum WidgetBridge {
  static func publish(
    selection: WaxSelectionStore,
    storeManager: StoreManager,
    location: LocationStore,
    recommendation: RecommendationStore
  ) {
    // Before StoreKit has answered, access is unknown; publishing "no access"
    // then would flash a locked widget at every subscriber on launch.
    guard storeManager.isInitialized else { return }

    let place = location.location.map {
      SharedPlace(
        latitude: $0.lat, longitude: $0.lon,
        name: $0.placeName ?? String(localized: "Widget_UnnamedPlace"))
    }

    let state = SharedAppState(
      selectedSeriesIDs: selection.selectedSeriesIDs,
      hiddenProductIDs: selection.hiddenProductIDs,
      hasAccess: storeManager.hasAccess,
      lastPlace: place,
      activeDomain: recommendation.activeDomain,
      usesFahrenheit: TemperaturePreference.currentUnit() == .fahrenheit
    )

    if state.save() {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}
