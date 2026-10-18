//
//  SwixGripData.swift
//  waxappv2
//
//  Swix kick (grip) wax catalogue.
//
//  Ranges follow Swix's own product pages and wax manual. Where Swix publishes
//  separate figures for new/falling snow and old/transformed snow, the colder
//  and wider old-snow band is applied to the transformed snow classes — a
//  given wax covers a colder band once the snow has rounded off.
//
//  Sources:
//  - https://swixsport.com/us/category/ski-wax/kick-wax (per-product ranges)
//  - https://swixsport.com/eu/article/wax-manual/factors-influencing-ski-waxing
//  - https://swixsport.com/eu/article/wax/fluorine-free-ski-waxing-swix (KN line)
//

import Foundation

// MARK: - Series

nonisolated let swixGripSeries: [WaxSeries] = [
  WaxSeries(
    brand: .swix, code: "V", domain: .grip,
    nameKey: "Series_Swix_V_Name", blurbKey: "Series_Swix_V_Blurb",
    isDefaultOn: true, isAdvanced: false
  ),
  WaxSeries(
    brand: .swix, code: "VP", domain: .grip,
    nameKey: "Series_Swix_VP_Name", blurbKey: "Series_Swix_VP_Blurb",
    isDefaultOn: false, isAdvanced: true
  ),
  WaxSeries(
    brand: .swix, code: "K", domain: .grip,
    nameKey: "Series_Swix_K_Name", blurbKey: "Series_Swix_K_Blurb",
    isDefaultOn: true, isAdvanced: false
  ),
  WaxSeries(
    brand: .swix, code: "KX", domain: .grip,
    nameKey: "Series_Swix_KX_Name", blurbKey: "Series_Swix_KX_Blurb",
    isDefaultOn: true, isAdvanced: false
  ),
  WaxSeries(
    brand: .swix, code: "KN", domain: .grip,
    nameKey: "Series_Swix_KN_Name", blurbKey: "Series_Swix_KN_Blurb",
    isDefaultOn: false, isAdvanced: true
  ),
]

// MARK: - Products

nonisolated let swixGripWaxes: [WaxProduct] = [

  // ===== V line — classic hardwax, recreational & training =====

  WaxProduct(
    brand: .swix, code: "V05", nameKey: "Wax_V05_Name", seriesCode: "V", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-25, -12)],
      .fineGrained: [TempRangeC(-25, -15)],
      .oldGrained: [TempRangeC(-25, -15)],
    ],
    notesKey: "Wax_V05_Notes",
    primaryColor: "#FFFFFF", secondaryColor: "#C7D2DA"
  ),

  WaxProduct(
    brand: .swix, code: "V20", nameKey: "Wax_V20_Name", seriesCode: "V", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-15, -8)],
      .fineGrained: [TempRangeC(-18, -10)],
      .oldGrained: [TempRangeC(-18, -10)],
    ],
    primaryColor: "#70A14D", secondaryColor: "#C8DCBA"
  ),

  WaxProduct(
    brand: .swix, code: "V30", nameKey: "Wax_V30_Name", seriesCode: "V", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-10, -2)],
      .fineGrained: [TempRangeC(-15, -5)],
      .oldGrained: [TempRangeC(-15, -5)],
    ],
    primaryColor: "#3D78E5", secondaryColor: "#AECCF4"
  ),

  WaxProduct(
    brand: .swix, code: "V40", nameKey: "Wax_V40_Name", seriesCode: "V", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-7, -1)],
      .fineGrained: [TempRangeC(-10, -3)],
      .oldGrained: [TempRangeC(-10, -3)],
    ],
    primaryColor: "#3D78E5", secondaryColor: "#A9C8F6"
  ),

  WaxProduct(
    brand: .swix, code: "V45", nameKey: "Wax_V45_Name", seriesCode: "V", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(-3, 0)],
      .moistFineGrained: [TempRangeC(-6, -2)],
      .oldGrained: [TempRangeC(-6, -2)],
    ],
    primaryColor: "#A9276B", secondaryColor: "#D8A6C4"
  ),

  // Swix publishes V50 as "0 °C" only — a genuine single-point range.
  WaxProduct(
    brand: .swix, code: "V50", nameKey: "Wax_V50_Name", seriesCode: "V", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 0)],
      .fineGrained: [TempRangeC(-3, -1)],
      .moistFineGrained: [TempRangeC(-3, -1)],
    ],
    notesKey: "Wax_V50_Notes",
    primaryColor: "#704D7B", secondaryColor: "#C3B2C9"
  ),

  WaxProduct(
    brand: .swix, code: "V55", nameKey: "Wax_V55_Name", seriesCode: "V", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 1)],
      .moistFineGrained: [TempRangeC(-2, 0)],
      .oldGrained: [TempRangeC(-2, 0)],
    ],
    primaryColor: "#B53149", secondaryColor: "#E7A8B2"
  ),

  WaxProduct(
    brand: .swix, code: "V60", nameKey: "Wax_V60_Name", seriesCode: "V", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 3)],
      .moistFineGrained: [TempRangeC(-1, 1)],
      .transformedMoistFine: [TempRangeC(-1, 1)],
    ],
    notesKey: "Wax_V60_Notes",
    primaryColor: "#B5332B", secondaryColor: "#C9CBD0"
  ),

  // ===== VP line — Pro hardwax =====

  WaxProduct(
    brand: .swix, code: "VP30", nameKey: "Wax_VP30_Name", seriesCode: "VP", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-16, -8)],
      .fineGrained: [TempRangeC(-16, -8)],
      .oldGrained: [TempRangeC(-20, -12)],
    ],
    notesKey: "Wax_VP30_Notes",
    primaryColor: "#1A1A1A", secondaryColor: "#9CC9DF"
  ),

  WaxProduct(
    brand: .swix, code: "VP40", nameKey: "Wax_VP40_Name", seriesCode: "VP", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-10, -4)],
      .fineGrained: [TempRangeC(-10, -4)],
      .oldGrained: [TempRangeC(-14, -5)],
    ],
    primaryColor: "#1A1A1A", secondaryColor: "#7FA0E8"
  ),

  WaxProduct(
    brand: .swix, code: "VP45", nameKey: "Wax_VP45_Name", seriesCode: "VP", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-5, -1)],
      .fineGrained: [TempRangeC(-5, -1)],
      .oldGrained: [TempRangeC(-8, -3)],
    ],
    primaryColor: "#1A1A1A", secondaryColor: "#9B8FDD"
  ),

  WaxProduct(
    brand: .swix, code: "VP50", nameKey: "Wax_VP50_Name", seriesCode: "VP", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-3, 0)],
      .fineGrained: [TempRangeC(-3, 0)],
      .oldGrained: [TempRangeC(-6, -1)],
    ],
    primaryColor: "#1A1A1A", secondaryColor: "#C09AC9"
  ),

  WaxProduct(
    brand: .swix, code: "VP55", nameKey: "Wax_VP55_Name", seriesCode: "VP", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(-2, 1)],
      .moistFineGrained: [TempRangeC(0, 1)],
      .oldGrained: [TempRangeC(-5, 0)],
    ],
    primaryColor: "#1A1A1A", secondaryColor: "#A48BC4"
  ),

  WaxProduct(
    brand: .swix, code: "VP60", nameKey: "Wax_VP60_Name", seriesCode: "VP", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(-1, 2)],
      .moistFineGrained: [TempRangeC(-1, 2)],
      .oldGrained: [TempRangeC(-4, -1)],
    ],
    primaryColor: "#1A1A1A", secondaryColor: "#9C5BA8"
  ),

  WaxProduct(
    brand: .swix, code: "VP65", nameKey: "Wax_VP65_Name", seriesCode: "VP", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 2)],
      .oldGrained: [TempRangeC(-4, 0)],
      .transformedMoistFine: [TempRangeC(0, 0)],
    ],
    notesKey: "Wax_VP65_Notes",
    primaryColor: "#1A1A1A", secondaryColor: "#A33029"
  ),

  WaxProduct(
    brand: .swix, code: "VP70", nameKey: "Wax_VP70_Name", seriesCode: "VP", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 3)],
      .transformedMoistFine: [TempRangeC(-1, 2)],
    ],
    notesKey: "Wax_VP70_Notes",
    primaryColor: "#1A1A1A", secondaryColor: "#F0D98A"
  ),

  // ===== Universal klister (K) =====

  WaxProduct(
    brand: .swix, code: "K21S", nameKey: "Wax_K21S_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-5, 3)],
      .wetCorn: [TempRangeC(-5, 3)],
    ],
    notesKey: "Wax_K21S_Notes",
    primaryColor: "#BDBDBD", secondaryColor: "#8FA6CF"
  ),

  WaxProduct(
    brand: .swix, code: "K22", nameKey: "Wax_K22_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .frozenCorn: [TempRangeC(-3, 10)],
      .wetCorn: [TempRangeC(-3, 10)],
    ],
    notesKey: "Wax_K22_Notes",
    primaryColor: "#CCCECB", secondaryColor: "#D98C80"
  ),

  // ===== KX klister =====

  WaxProduct(
    brand: .swix, code: "KX20", nameKey: "Wax_KX20_Name", seriesCode: "KX", kind: .binder,
    // A binder is laid down under klister rather than chosen for the day, so it
    // carries the broad window in which klister work is plausible at all.
    ranges: [
      .transformedMoistFine: [TempRangeC(-12, 10)],
      .frozenCorn: [TempRangeC(-12, 10)],
      .wetCorn: [TempRangeC(-12, 10)],
      .veryWetCorn: [TempRangeC(-12, 15)],
    ],
    notesKey: "Wax_KX20_Notes",
    primaryColor: "#6AAC45", secondaryColor: "#A7CE8F"
  ),

  WaxProduct(
    brand: .swix, code: "KX30", nameKey: "Wax_KX30_Name", seriesCode: "KX", kind: .klister,
    ranges: [
      .frozenCorn: [TempRangeC(-12, 0)]
    ],
    notesKey: "Wax_KX30_Notes",
    primaryColor: "#509CD6", secondaryColor: "#9CCAEC"
  ),

  WaxProduct(
    brand: .swix, code: "KX35N", nameKey: "Wax_KX35N_Name", seriesCode: "KX", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-8, 0)],
      .frozenCorn: [TempRangeC(-8, -1)],
    ],
    notesKey: "Wax_KX35N_Notes",
    primaryColor: "#2C68BD", secondaryColor: "#8F7CC4"
  ),

  WaxProduct(
    brand: .swix, code: "KX40S", nameKey: "Wax_KX40S_Name", seriesCode: "KX", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-4, 2)],
      .wetCorn: [TempRangeC(-4, 2)],
    ],
    notesKey: "Wax_KX40S_Notes",
    primaryColor: "#95989E", secondaryColor: "#9B76A6"
  ),

  WaxProduct(
    brand: .swix, code: "KX45N", nameKey: "Wax_KX45N_Name", seriesCode: "KX", kind: .klister,
    ranges: [
      .frozenCorn: [TempRangeC(-2, 4)],
      .wetCorn: [TempRangeC(-2, 4)],
    ],
    notesKey: "Wax_KX45N_Notes",
    primaryColor: "#773C89", secondaryColor: "#8FBDE4"
  ),

  WaxProduct(
    brand: .swix, code: "KX55", nameKey: "Wax_KX55_Name", seriesCode: "KX", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-6, 4)],
      .wetCorn: [TempRangeC(-6, 4)],
    ],
    notesKey: "Wax_KX55_Notes",
    primaryColor: "#C63B66", secondaryColor: "#E2BE86"
  ),

  WaxProduct(
    brand: .swix, code: "KX65", nameKey: "Wax_KX65_Name", seriesCode: "KX", kind: .klister,
    ranges: [
      .wetCorn: [TempRangeC(1, 5)],
      .veryWetCorn: [TempRangeC(1, 5)],
    ],
    notesKey: "Wax_KX65_Notes",
    primaryColor: "#D23A2B", secondaryColor: "#E5968B"
  ),

  WaxProduct(
    brand: .swix, code: "KX75", nameKey: "Wax_KX75_Name", seriesCode: "KX", kind: .klister,
    ranges: [
      .veryWetCorn: [TempRangeC(2, 15)]
    ],
    notesKey: "Wax_KX75_Notes",
    primaryColor: "#D5452F", secondaryColor: "#EDCE86"
  ),

  // ===== KN — Nero, fluor-free pro klister =====

  WaxProduct(
    brand: .swix, code: "KN33", nameKey: "Wax_KN33_Name", seriesCode: "KN", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-7, 1)],
      .frozenCorn: [TempRangeC(-7, -1)],
      .wetCorn: [TempRangeC(-7, 1)],
    ],
    notesKey: "Wax_KN33_Notes",
    primaryColor: "#1A1A1A", secondaryColor: "#D5A3D6"
  ),

  WaxProduct(
    brand: .swix, code: "KN44", nameKey: "Wax_KN44_Name", seriesCode: "KN", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-3, 4)],
      .wetCorn: [TempRangeC(-3, 4)],
      .veryWetCorn: [TempRangeC(0, 4)],
    ],
    notesKey: "Wax_KN44_Notes",
    primaryColor: "#1A1A1A", secondaryColor: "#C27C76"
  ),
]
