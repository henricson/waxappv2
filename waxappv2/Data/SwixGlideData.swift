//
//  SwixGlideData.swift
//  waxappv2
//
//  Swix glide wax catalogue (Pro by Swix, fluor-free).
//
//  Swix publishes one air-temperature band per glide product regardless of
//  snow type, so each product carries the same band across every snow class
//  it is plausible for. Snow-type preference is expressed through
//  `snowAffinity` instead: graphite-loaded TS Black and Marathon score higher
//  on transformed, abrasive and dirty snow; powders and liquids are weighted
//  toward race-day conditions.
//
//  Sources:
//  - https://swixsport.com/us/article/wax/pro-by-swix-what-is-the-difference-between-ps-hs-and-ts
//  - https://swixsport.com/eu/article/wax-manual/pro-series
//  - https://swixsport.com/eu/article/wax/fluorine-free-ski-waxing-swix
//  - Per-product pages for the HS liquid line (HS6L/HS7L/HS8L/HS10L).
//

import Foundation

// MARK: - Series

nonisolated let swixGlideSeries: [WaxSeries] = [
  WaxSeries(
    brand: .swix, code: "PS", domain: .glide,
    nameKey: "Series_Swix_PS_Name", blurbKey: "Series_Swix_PS_Blurb",
    isDefaultOn: true, isAdvanced: false
  ),
  WaxSeries(
    brand: .swix, code: "HS", domain: .glide,
    nameKey: "Series_Swix_HS_Name", blurbKey: "Series_Swix_HS_Blurb",
    isDefaultOn: false, isAdvanced: true
  ),
  WaxSeries(
    brand: .swix, code: "HSL", domain: .glide,
    nameKey: "Series_Swix_HSL_Name", blurbKey: "Series_Swix_HSL_Blurb",
    isDefaultOn: false, isAdvanced: false
  ),
  WaxSeries(
    brand: .swix, code: "TS", domain: .glide,
    nameKey: "Series_Swix_TS_Name", blurbKey: "Series_Swix_TS_Blurb",
    isDefaultOn: false, isAdvanced: true
  ),
  WaxSeries(
    brand: .swix, code: "TSP", domain: .glide,
    nameKey: "Series_Swix_TSP_Name", blurbKey: "Series_Swix_TSP_Blurb",
    isDefaultOn: false, isAdvanced: true
  ),
  WaxSeries(
    brand: .swix, code: "BP", domain: .glide,
    nameKey: "Series_Swix_BP_Name", blurbKey: "Series_Swix_BP_Blurb",
    isDefaultOn: false, isAdvanced: false
  ),
]

// MARK: - Shared helpers

/// Graphite / black products: at their best on transformed, dirty, abrasive and
/// very cold dry snow, where static and grain abrasion dominate.
private nonisolated let graphiteAffinity: [SnowType: Double] = [
  .newFallen: 1.05,
  .moistNewFallen: 0.90,
  .fineGrained: 1.00,
  .moistFineGrained: 0.95,
  .oldGrained: 1.15,
  .transformedMoistFine: 1.25,
  .frozenCorn: 1.30,
  .wetCorn: 1.15,
  .veryWetCorn: 1.10,
]

/// Plain hydrocarbon hot wax: the neutral baseline, slightly preferred on
/// clean new and fine-grained snow.
private nonisolated let hydrocarbonAffinity: [SnowType: Double] = [
  .newFallen: 1.10,
  .moistNewFallen: 1.05,
  .fineGrained: 1.10,
  .moistFineGrained: 1.05,
  .oldGrained: 1.00,
  .transformedMoistFine: 0.92,
  .frozenCorn: 0.85,
  .wetCorn: 0.95,
  .veryWetCorn: 0.95,
]

/// Liquids: fast to apply, strongest on wet and transformed snow where a
/// surface layer matters more than deep saturation.
private nonisolated let liquidAffinity: [SnowType: Double] = [
  .newFallen: 0.92,
  .moistNewFallen: 1.00,
  .fineGrained: 0.95,
  .moistFineGrained: 1.05,
  .oldGrained: 1.00,
  .transformedMoistFine: 1.12,
  .frozenCorn: 1.05,
  .wetCorn: 1.15,
  .veryWetCorn: 1.15,
]

// MARK: - Products

nonisolated let swixGlideWaxes: [WaxProduct] = [

  // ===== PS — Performance Speed (hot wax; recreational & training) =====

  WaxProduct(
    brand: .swix, code: "PSP", nameKey: "Wax_PSP_Name", seriesCode: "PS", kind: .glideHot,
    band: TempRangeC(-32, -14),
    notesKey: "Wax_PSP_Notes",
    primaryColor: "#E8EEF2", secondaryColor: "#9FB6C4",
    snowAffinity: hydrocarbonAffinity
  ),
  WaxProduct(
    brand: .swix, code: "PS5", nameKey: "Wax_PS5_Name", seriesCode: "PS", kind: .glideHot,
    band: TempRangeC(-18, -10),
    primaryColor: "#3FC1D3", secondaryColor: "#8FDCE7",
    snowAffinity: hydrocarbonAffinity
  ),
  WaxProduct(
    brand: .swix, code: "PS6", nameKey: "Wax_PS6_Name", seriesCode: "PS", kind: .glideHot,
    band: TempRangeC(-12, -6),
    primaryColor: "#2C68BD", secondaryColor: "#6E9CDC",
    snowAffinity: hydrocarbonAffinity
  ),
  WaxProduct(
    brand: .swix, code: "PS7", nameKey: "Wax_PS7_Name", seriesCode: "PS", kind: .glideHot,
    band: TempRangeC(-8, -2),
    primaryColor: "#614AA7", secondaryColor: "#9B87CC",
    snowAffinity: hydrocarbonAffinity
  ),
  WaxProduct(
    brand: .swix, code: "PS8", nameKey: "Wax_PS8_Name", seriesCode: "PS", kind: .glideHot,
    band: TempRangeC(-4, 4),
    primaryColor: "#D23A2B", secondaryColor: "#E58275",
    snowAffinity: hydrocarbonAffinity
  ),
  WaxProduct(
    brand: .swix, code: "PS10", nameKey: "Wax_PS10_Name", seriesCode: "PS", kind: .glideHot,
    band: TempRangeC(0, 10),
    primaryColor: "#EFC32A", secondaryColor: "#F6DC7E",
    snowAffinity: hydrocarbonAffinity
  ),

  // ===== HS — High Speed (hot wax; dedicated skiers & racers) =====

  WaxProduct(
    brand: .swix, code: "HS5", nameKey: "Wax_HS5_Name", seriesCode: "HS", kind: .glideHot,
    band: TempRangeC(-18, -10),
    primaryColor: "#3FC1D3", secondaryColor: "#8FDCE7",
    snowAffinity: hydrocarbonAffinity
  ),
  WaxProduct(
    brand: .swix, code: "HS6", nameKey: "Wax_HS6_Name", seriesCode: "HS", kind: .glideHot,
    band: TempRangeC(-12, -6),
    primaryColor: "#2C68BD", secondaryColor: "#6E9CDC",
    snowAffinity: hydrocarbonAffinity
  ),
  WaxProduct(
    brand: .swix, code: "HS7", nameKey: "Wax_HS7_Name", seriesCode: "HS", kind: .glideHot,
    band: TempRangeC(-8, -2),
    primaryColor: "#614AA7", secondaryColor: "#9B87CC",
    snowAffinity: hydrocarbonAffinity
  ),
  WaxProduct(
    brand: .swix, code: "HS8", nameKey: "Wax_HS8_Name", seriesCode: "HS", kind: .glideHot,
    band: TempRangeC(-4, 4),
    primaryColor: "#D23A2B", secondaryColor: "#E58275",
    snowAffinity: hydrocarbonAffinity
  ),
  WaxProduct(
    brand: .swix, code: "HS10", nameKey: "Wax_HS10_Name", seriesCode: "HS", kind: .glideHot,
    band: TempRangeC(0, 10),
    primaryColor: "#EFC32A", secondaryColor: "#F6DC7E",
    snowAffinity: hydrocarbonAffinity
  ),

  // ===== HSL — High Speed Liquid =====

  WaxProduct(
    brand: .swix, code: "HS6L", nameKey: "Wax_HS6L_Name", seriesCode: "HSL", kind: .glideLiquid,
    band: TempRangeC(-12, -4),
    notesKey: "Wax_Liquid_Notes",
    primaryColor: "#2C68BD", secondaryColor: "#6E9CDC",
    snowAffinity: liquidAffinity
  ),
  WaxProduct(
    brand: .swix, code: "HS7L", nameKey: "Wax_HS7L_Name", seriesCode: "HSL", kind: .glideLiquid,
    band: TempRangeC(-8, -2),
    notesKey: "Wax_Liquid_Notes",
    primaryColor: "#614AA7", secondaryColor: "#9B87CC",
    snowAffinity: liquidAffinity
  ),
  WaxProduct(
    brand: .swix, code: "HS8L", nameKey: "Wax_HS8L_Name", seriesCode: "HSL", kind: .glideLiquid,
    band: TempRangeC(-4, 4),
    notesKey: "Wax_Liquid_Notes",
    primaryColor: "#D23A2B", secondaryColor: "#E58275",
    snowAffinity: liquidAffinity
  ),
  WaxProduct(
    brand: .swix, code: "HS10L", nameKey: "Wax_HS10L_Name", seriesCode: "HSL", kind: .glideLiquid,
    band: TempRangeC(2, 10),
    notesKey: "Wax_Liquid_Notes",
    primaryColor: "#EFC32A", secondaryColor: "#F6DC7E",
    snowAffinity: liquidAffinity
  ),

  // ===== TS Black — Top Speed (hot wax; transformed and dirty snow) =====

  WaxProduct(
    brand: .swix, code: "TS5", nameKey: "Wax_TS5_Name", seriesCode: "TS", kind: .glideHot,
    band: TempRangeC(-18, -10),
    notesKey: "Wax_TSBlack_Notes",
    primaryColor: "#1A1A1A", secondaryColor: "#3FC1D3",
    snowAffinity: graphiteAffinity
  ),
  WaxProduct(
    brand: .swix, code: "TS6", nameKey: "Wax_TS6_Name", seriesCode: "TS", kind: .glideHot,
    band: TempRangeC(-12, -6),
    notesKey: "Wax_TSBlack_Notes",
    primaryColor: "#1A1A1A", secondaryColor: "#2C68BD",
    snowAffinity: graphiteAffinity
  ),
  WaxProduct(
    brand: .swix, code: "TS7", nameKey: "Wax_TS7_Name", seriesCode: "TS", kind: .glideHot,
    band: TempRangeC(-8, -2),
    notesKey: "Wax_TSBlack_Notes",
    primaryColor: "#1A1A1A", secondaryColor: "#614AA7",
    snowAffinity: graphiteAffinity
  ),
  WaxProduct(
    brand: .swix, code: "TS8", nameKey: "Wax_TS8_Name", seriesCode: "TS", kind: .glideHot,
    band: TempRangeC(-4, 4),
    notesKey: "Wax_TSBlack_Notes",
    primaryColor: "#1A1A1A", secondaryColor: "#D23A2B",
    snowAffinity: graphiteAffinity
  ),
  WaxProduct(
    brand: .swix, code: "TS10", nameKey: "Wax_TS10_Name", seriesCode: "TS", kind: .glideHot,
    band: TempRangeC(0, 10),
    notesKey: "Wax_TSBlack_Notes",
    primaryColor: "#1A1A1A", secondaryColor: "#EFC32A",
    snowAffinity: graphiteAffinity
  ),

  // ===== TSP — Top Speed Powder =====

  WaxProduct(
    brand: .swix, code: "TSP5", nameKey: "Wax_TSP5_Name", seriesCode: "TSP", kind: .glidePowder,
    band: TempRangeC(-15, -8),
    notesKey: "Wax_Powder_Notes",
    primaryColor: "#3FC1D3", secondaryColor: "#B9ECF3"
  ),
  WaxProduct(
    brand: .swix, code: "TSP6", nameKey: "Wax_TSP6_Name", seriesCode: "TSP", kind: .glidePowder,
    band: TempRangeC(-10, -5),
    notesKey: "Wax_Powder_Notes",
    primaryColor: "#2C68BD", secondaryColor: "#A8C4EB"
  ),
  WaxProduct(
    brand: .swix, code: "TSP7", nameKey: "Wax_TSP7_Name", seriesCode: "TSP", kind: .glidePowder,
    band: TempRangeC(-7, -2),
    notesKey: "Wax_Powder_Notes",
    primaryColor: "#614AA7", secondaryColor: "#C2B5E3"
  ),
  WaxProduct(
    brand: .swix, code: "TSP8", nameKey: "Wax_TSP8_Name", seriesCode: "TSP", kind: .glidePowder,
    band: TempRangeC(-4, 4),
    notesKey: "Wax_Powder_Notes",
    primaryColor: "#D23A2B", secondaryColor: "#F0B4AC"
  ),
  WaxProduct(
    brand: .swix, code: "TSP10", nameKey: "Wax_TSP10_Name", seriesCode: "TSP", kind: .glidePowder,
    band: TempRangeC(0, 10),
    notesKey: "Wax_Powder_Notes",
    primaryColor: "#EFC32A", secondaryColor: "#F9E9B0"
  ),

  // ===== Base prep =====

  WaxProduct(
    brand: .swix, code: "BP77", nameKey: "Wax_BP77_Name", seriesCode: "BP", kind: .glideBase,
    band: TempRangeC(-30, -8),
    notesKey: "Wax_BasePrep_Notes",
    primaryColor: "#6A3F9E", secondaryColor: "#9B7CC7"
  ),
  WaxProduct(
    brand: .swix, code: "BP88", nameKey: "Wax_BP88_Name", seriesCode: "BP", kind: .glideBase,
    band: TempRangeC(-12, 0),
    notesKey: "Wax_BasePrep_Notes",
    primaryColor: "#D23A2B", secondaryColor: "#E58275"
  ),
  WaxProduct(
    brand: .swix, code: "BP99", nameKey: "Wax_BP99_Name", seriesCode: "BP", kind: .glideBase,
    band: TempRangeC(-4, 10),
    notesKey: "Wax_BasePrep_Notes",
    primaryColor: "#F2C82F", secondaryColor: "#F7DF8E"
  ),
]

nonisolated let swixSeries: [WaxSeries] = swixGripSeries + swixGlideSeries
