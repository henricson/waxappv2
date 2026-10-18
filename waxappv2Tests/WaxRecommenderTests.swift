import Foundation
import Testing

@testable import waxappv2

@Suite("WaxRecommender")
struct WaxRecommenderTests {

  // MARK: - Helpers

  private func product(
    _ code: String,
    kind: WaxKind = .hardwax,
    ranges: [SnowType: [TempRangeC]],
    affinity: [SnowType: Double] = [:]
  ) -> WaxProduct {
    WaxProduct(
      brand: .swix, code: code, nameKey: code, seriesCode: "TEST", kind: kind,
      ranges: ranges, snowAffinity: affinity
    )
  }

  // MARK: - Temperature curve

  @Test("Centre of a range scores higher than its edge")
  func centreBeatsEdge() {
    let range = TempRangeC(-10, -2)
    let centre = WaxRecommender.temperatureScore(for: -6, in: range)
    let edge = WaxRecommender.temperatureScore(for: -2, in: range)
    #expect(centre > edge)
    #expect(centre == 1.0)
  }

  @Test("A wax stays strong across most of its band")
  func flatTopped() {
    // The whole point of the quartic curve: don't punish a wax for being
    // used two degrees off centre.
    let range = TempRangeC(-10, -2)
    for temperature in -9...(-3) {
      let score = WaxRecommender.temperatureScore(for: temperature, in: range)
      #expect(score >= 0.75)
    }
  }

  @Test("Edges of a range still score at least 0.75")
  func edgesUsable() {
    let range = TempRangeC(-10, -2)
    #expect(WaxRecommender.temperatureScore(for: -10, in: range) >= 0.74)
    #expect(WaxRecommender.temperatureScore(for: -2, in: range) >= 0.74)
  }

  @Test("Outside the range the score decays with distance")
  func decaysOutside() {
    let range = TempRangeC(-10, -2)
    let one = WaxRecommender.temperatureScore(for: -1, in: range)
    let three = WaxRecommender.temperatureScore(for: 1, in: range)
    #expect(one > three)
    #expect(three >= 0)
  }

  @Test("Far outside the range the score reaches zero")
  func zeroFarOutside() {
    let range = TempRangeC(-10, -2)
    #expect(WaxRecommender.temperatureScore(for: 20, in: range) == 0)
  }

  // MARK: - Single-point ranges

  @Test("A single-point range scores 1.0 on its exact temperature")
  func pinpointExact() {
    // Swix publishes V50 as "0 °C" only.
    let range = TempRangeC(0, 0)
    #expect(WaxRecommender.temperatureScore(for: 0, in: range) == 1.0)
  }

  @Test("A single-point range still scores nearby")
  func pinpointNearby() {
    let range = TempRangeC(0, 0)
    let one = WaxRecommender.temperatureScore(for: -1, in: range)
    #expect(one > 0)
    #expect(one < 1.0)
  }

  // MARK: - Multiple sub-ranges

  @Test("All sub-ranges for a snow type are considered, not just the first")
  func usesBestSubRange() {
    // The first range is far away; the second is a direct hit. The old
    // implementation only ever looked at `.first`.
    let wax = product(
      "MULTI",
      ranges: [.fineGrained: [TempRangeC(-30, -25), TempRangeC(-8, -4)]]
    )
    let conditions = WaxConditions(temperatureC: -6, snowType: .fineGrained)
    let result = WaxRecommender.score(wax, conditions: conditions)

    #expect(result != nil)
    #expect(result?.matchedRange == TempRangeC(-8, -4))
    #expect((result?.score ?? 0) > 0.8)
  }

  // MARK: - Ranking

  @Test("A direct hit outranks a neighbouring wax")
  func directHitWins() {
    let onTarget = product("ON", ranges: [.fineGrained: [TempRangeC(-8, -4)]])
    let offTarget = product("OFF", ranges: [.fineGrained: [TempRangeC(-20, -12)]])
    let conditions = WaxConditions(temperatureC: -6, snowType: .fineGrained)

    let ranked = WaxRecommender.rank(products: [offTarget, onTarget], conditions: conditions)
    #expect(ranked.first?.product.code == "ON")
  }

  @Test("A wax with no range for the snow type is excluded")
  func excludesWrongSnowType() {
    let wax = product("DRY", ranges: [.fineGrained: [TempRangeC(-8, -4)]])
    let conditions = WaxConditions(temperatureC: -6, snowType: .wetCorn)
    #expect(WaxRecommender.score(wax, conditions: conditions) == nil)
  }

  @Test("Preparation layers are kept out of the main ranking")
  func preparationExcluded() {
    let binder = product("BIND", kind: .binder, ranges: [.frozenCorn: [TempRangeC(-12, 10)]])
    let klister = product("KL", kind: .klister, ranges: [.frozenCorn: [TempRangeC(-5, 0)]])
    let conditions = WaxConditions(temperatureC: -3, snowType: .frozenCorn)

    let ranked = WaxRecommender.rank(products: [binder, klister], conditions: conditions)
    #expect(ranked.allSatisfy { $0.product.kind != .binder })

    let prep = WaxRecommender.preparation(from: [binder, klister], for: conditions)
    #expect(prep?.product.code == "BIND")
  }

  @Test("A narrow range edges out a very wide one at equal temperature fit")
  func specificityBreaksTies() {
    let narrow = product("NARROW", ranges: [.fineGrained: [TempRangeC(-7, -5)]])
    let wide = product("WIDE", ranges: [.fineGrained: [TempRangeC(-18, 2)]])
    let conditions = WaxConditions(temperatureC: -6, snowType: .fineGrained)

    let ranked = WaxRecommender.rank(products: [wide, narrow], conditions: conditions)
    #expect(ranked.first?.product.code == "NARROW")
  }

  // MARK: - Condition modifiers

  @Test("Rain pushes klister ahead of hard wax")
  func rainFavoursKlister() {
    let hardwax = product("HW", kind: .hardwax, ranges: [.transformedMoistFine: [TempRangeC(-3, 1)]])
    let klister = product("KL", kind: .klister, ranges: [.transformedMoistFine: [TempRangeC(-3, 1)]])

    let dry = WaxConditions(temperatureC: -1, snowType: .transformedMoistFine)
    let wet = WaxConditions(
      temperatureC: -1, snowType: .transformedMoistFine, recentRainMM: 8)

    let dryRanked = WaxRecommender.rank(products: [hardwax, klister], conditions: dry)
    let wetRanked = WaxRecommender.rank(products: [hardwax, klister], conditions: wet)

    // Equal on a dry day; klister clearly ahead once it has rained.
    #expect(dryRanked.first?.score == dryRanked.last?.score)
    #expect(wetRanked.first?.product.code == "KL")
  }

  @Test("Falling snow pushes hard wax ahead of klister")
  func freshSnowFavoursHardwax() {
    let hardwax = product("HW", kind: .hardwax, ranges: [.moistNewFallen: [TempRangeC(-3, 1)]])
    let klister = product("KL", kind: .klister, ranges: [.moistNewFallen: [TempRangeC(-3, 1)]])

    let snowing = WaxConditions(
      temperatureC: -1, snowType: .moistNewFallen, recentSnowMM: 8, isSnowing: true)

    let ranked = WaxRecommender.rank(products: [hardwax, klister], conditions: snowing)
    #expect(ranked.first?.product.code == "HW")
  }

  @Test("Snow affinity separates two gliders with the same band")
  func affinitySeparatesGliders() {
    let plain = product(
      "PLAIN", kind: .glideHot,
      ranges: [.frozenCorn: [TempRangeC(-8, -2)]],
      affinity: [.frozenCorn: 0.85]
    )
    let graphite = product(
      "GRAPHITE", kind: .glideHot,
      ranges: [.frozenCorn: [TempRangeC(-8, -2)]],
      affinity: [.frozenCorn: 1.30]
    )
    let conditions = WaxConditions(temperatureC: -5, snowType: .frozenCorn)

    let ranked = WaxRecommender.rank(products: [plain, graphite], conditions: conditions)
    #expect(ranked.first?.product.code == "GRAPHITE")
  }

  @Test("Factors are reported for advanced mode")
  func reportsFactors() {
    let klister = product("KL", kind: .klister, ranges: [.wetCorn: [TempRangeC(-2, 4)]])
    let conditions = WaxConditions(temperatureC: 1, snowType: .wetCorn, recentRainMM: 5)
    let result = WaxRecommender.score(klister, conditions: conditions)

    #expect(result?.factors.contains { $0.kind == .temperature } == true)
    #expect(result?.factors.contains { $0.kind == .rain } == true)
  }

  // MARK: - Nearest useful temperature

  @Test("Nearest useful temperature finds the closest covered degree")
  func nearestTemperature() {
    let cold = product("COLD", ranges: [.fineGrained: [TempRangeC(-18, -10)]])
    let warm = product("WARM", ranges: [.fineGrained: [TempRangeC(-4, 0)]])

    let target = WaxRecommender.nearestUsefulTemperature(
      from: -7, products: [cold, warm], snowType: .fineGrained)

    // -7 is 3° from -10 and 3° from -4; either is acceptable, but it must
    // land on a covered edge rather than returning the input unchanged.
    #expect(target == -10 || target == -4)
  }

  @Test("Nearest useful temperature returns nil with no candidates")
  func nearestTemperatureEmpty() {
    let target = WaxRecommender.nearestUsefulTemperature(
      from: -7, products: [], snowType: .fineGrained)
    #expect(target == nil)
  }
}

// MARK: - Catalogue integrity

@Suite("WaxCatalog")
struct WaxCatalogTests {

  @Test("Product IDs are unique across brands")
  func uniqueIDs() {
    let ids = WaxCatalog.all.map(\.id)
    #expect(Set(ids).count == ids.count)
  }

  @Test("Every product belongs to a declared series")
  func seriesExist() {
    let seriesIDs = Set(WaxCatalog.series.map(\.id))
    for product in WaxCatalog.all {
      #expect(seriesIDs.contains(product.seriesID), "orphaned: \(product.id)")
    }
  }

  @Test("Every series has at least one product")
  func seriesPopulated() {
    for series in WaxCatalog.series {
      #expect(!WaxCatalog.products(inSeries: series.id).isEmpty, "empty: \(series.id)")
    }
  }

  @Test("Temperature ranges are ordered and physically plausible")
  func rangesSane() {
    // Read through `ranges(for:)`, not the stored dictionary: glide products
    // declare a single `band` instead of a per-snow-type map.
    for product in WaxCatalog.all {
      for snowType in SnowType.allCases {
        for range in product.ranges(for: snowType) {
          #expect(range.min <= range.max, "\(product.id) \(snowType)")
          #expect(range.min >= -40, "\(product.id) \(snowType)")
          #expect(range.max <= 20, "\(product.id) \(snowType)")
        }
      }
    }
  }

  @Test("A reversed range is normalised on construction")
  func reversedRangeNormalised() {
    // Several manufacturer charts print the warm end first.
    let range = TempRangeC(1, -7)
    #expect(range.min == -7)
    #expect(range.max == 1)
  }

  @Test("Glide products expose their published band on every snow type")
  func glideBandApplies() {
    let glide = WaxCatalog.all.filter { $0.domain == .glide && !$0.kind.isPreparation }
    #expect(!glide.isEmpty)

    for product in glide {
      // One published band, stored once rather than copied nine times.
      #expect(product.band != nil, "\(product.id) has no band")
      #expect(product.ranges.isEmpty, "\(product.id) duplicates its band into ranges")

      for snowType in SnowType.allCases {
        #expect(product.ranges(for: snowType) == [product.band!])
      }
    }
  }

  @Test("Grip products keep per-snow-type ranges and declare no band")
  func gripUsesRanges() {
    for product in WaxCatalog.all where product.domain == .grip {
      #expect(product.band == nil, "\(product.id) should not carry a band")
      #expect(!product.ranges.isEmpty, "\(product.id) has no ranges")
    }
  }

  @Test("Both brands and both domains are represented")
  func coverage() {
    #expect(WaxCatalog.all.contains { $0.brand == .swix })
    #expect(WaxCatalog.all.contains { $0.brand == .rode })
    #expect(WaxCatalog.all.contains { $0.domain == .grip })
    #expect(WaxCatalog.all.contains { $0.domain == .glide })
  }

  @Test("The default kit covers grip and glide without being overwhelming")
  func defaultsAreSane() {
    let defaults = WaxCatalog.defaultProductIDs
    let products = WaxCatalog.all.filter { defaults.contains($0.id) }

    #expect(products.contains { $0.domain == .grip })
    #expect(products.contains { $0.domain == .glide })
    #expect(products.count < WaxCatalog.all.count)
  }

  @Test("Every regional kit is Swix-based, covers both domains and avoids pro lines")
  func regionalKits() {
    let regions: [RegionalWaxKit.Region] = [.norway, .sweden, .finland, .iceland, .international]
    for region in regions {
      let ids = RegionalWaxKit.seriesIDs(for: region)
      let series = WaxCatalog.series.filter { ids.contains($0.id) }
      #expect(series.count == ids.count, "\(region) names an unknown series")
      #expect(series.contains { $0.domain == .grip && $0.brand == .swix })
      #expect(series.contains { $0.domain == .glide })
      #expect(series.allSatisfy { !$0.isAdvanced }, "\(region) turns on a pro line")
    }
    #expect(RegionalWaxKit.seriesIDs(for: .norway).contains("rode.P"))
    #expect(RegionalWaxKit.Region(regionCode: "no") == .norway)
    #expect(RegionalWaxKit.Region(regionCode: "US") == .international)
  }

  @Test("Every non-preparation product can be recommended somewhere")
  func everyProductIsReachable() {
    for product in WaxCatalog.all where !product.kind.isPreparation {
      var reachable = false
      for snowType in SnowType.allCases {
        for range in product.ranges(for: snowType) {
          let conditions = WaxConditions(
            temperatureC: (range.min + range.max) / 2, snowType: snowType)
          if let scored = WaxRecommender.score(product, conditions: conditions),
            scored.score >= WaxRecommender.cutoff
          {
            reachable = true
          }
        }
      }
      #expect(reachable, "unreachable: \(product.id)")
    }
  }
}
