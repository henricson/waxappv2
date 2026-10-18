//
//  RodeData.swift
//  waxappv2
//
//  Rode kick wax and klister catalogue.
//
//  Rode publishes two columns for most hard waxes: a drier "Southern Europe"
//  band and a wetter "Northern Europe" band. As with Swix, the same wax covers
//  a colder, wider band once the snow has transformed, so the dry column maps
//  to falling/new snow and the wet column to fine-grained and old snow.
//
//  Sources:
//  - https://www.webcyclery.com/product/rode-kick-waxes-1444.htm
//  - https://www.webcyclery.com/product/rode-klisters-1449.htm
//  - https://www.skiwax.eu (per-product confirmation for the Multigrade line)
//  - https://skiwax.ca/collections/rode-standard-klisters (klister tube colours)
//

import Foundation

// MARK: - Series

nonisolated let rodeSeries: [WaxSeries] = [
  WaxSeries(
    brand: .rode, code: "P", domain: .grip,
    nameKey: "Series_Rode_P_Name", blurbKey: "Series_Rode_P_Blurb",
    isDefaultOn: false, isAdvanced: false
  ),
  WaxSeries(
    brand: .rode, code: "PMG", domain: .grip,
    nameKey: "Series_Rode_PMG_Name", blurbKey: "Series_Rode_PMG_Blurb",
    isDefaultOn: false, isAdvanced: false
  ),
  WaxSeries(
    brand: .rode, code: "K", domain: .grip,
    nameKey: "Series_Rode_K_Name", blurbKey: "Series_Rode_K_Blurb",
    isDefaultOn: false, isAdvanced: false
  ),
]

// MARK: - Hard waxes

nonisolated let rodeGripWaxes: [WaxProduct] = [

  // ===== P line — hard wax =====

  WaxProduct(
    brand: .rode, code: "P10", nameKey: "Wax_RodeP10_Name", seriesCode: "P", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-22, -15)],
      .fineGrained: [TempRangeC(-22, -15)],
      .oldGrained: [TempRangeC(-25, -15)],
    ],
    notesKey: "Wax_RodeP10_Notes",
    primaryColor: "#E6F0F7", secondaryColor: "#7FA8C9"
  ),

  WaxProduct(
    brand: .rode, code: "P15", nameKey: "Wax_RodeP15_Name", seriesCode: "P", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-30, -10)],
      .fineGrained: [TempRangeC(-30, -10)],
      .oldGrained: [TempRangeC(-30, -12)],
    ],
    primaryColor: "#2E7D4F", secondaryColor: "#8CC4A2"
  ),

  WaxProduct(
    brand: .rode, code: "P20", nameKey: "Wax_RodeP20_Name", seriesCode: "P", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-10, -4)],
      .fineGrained: [TempRangeC(-15, -7)],
      .oldGrained: [TempRangeC(-15, -7)],
    ],
    primaryColor: "#3D9A5C", secondaryColor: "#9ED0AE"
  ),

  WaxProduct(
    brand: .rode, code: "P30", nameKey: "Wax_RodeP30_Name", seriesCode: "P", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-6, -2)],
      .fineGrained: [TempRangeC(-8, -3)],
      .oldGrained: [TempRangeC(-8, -3)],
    ],
    primaryColor: "#2C68BD", secondaryColor: "#8FB4E4"
  ),

  WaxProduct(
    brand: .rode, code: "P32", nameKey: "Wax_RodeP32_Name", seriesCode: "P", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-3, -1)],
      .fineGrained: [TempRangeC(-10, -3)],
      .oldGrained: [TempRangeC(-10, -3)],
    ],
    primaryColor: "#2458A8", secondaryColor: "#7FA8DC"
  ),

  WaxProduct(
    brand: .rode, code: "P34", nameKey: "Wax_RodeP34_Name", seriesCode: "P", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-8, -2)],
      .fineGrained: [TempRangeC(-10, -3)],
      .oldGrained: [TempRangeC(-10, -3)],
    ],
    primaryColor: "#1F4C96", secondaryColor: "#7098D0"
  ),

  WaxProduct(
    brand: .rode, code: "P28", nameKey: "Wax_RodeP28_Name", seriesCode: "P", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-4, -1)],
      .fineGrained: [TempRangeC(-7, -3)],
      .oldGrained: [TempRangeC(-7, -3)],
    ],
    primaryColor: "#5B8FD4", secondaryColor: "#FFFFFF"
  ),

  WaxProduct(
    brand: .rode, code: "P40", nameKey: "Wax_RodeP40_Name", seriesCode: "P", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 0)],
      .moistFineGrained: [TempRangeC(-4, -2)],
      .oldGrained: [TempRangeC(-4, -2)],
    ],
    primaryColor: "#7B4C9E", secondaryColor: "#B795D0"
  ),

  WaxProduct(
    brand: .rode, code: "P42", nameKey: "Wax_RodeP42_Name", seriesCode: "P", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 1)],
      .moistFineGrained: [TempRangeC(-3, 0)],
      .transformedMoistFine: [TempRangeC(-3, 0)],
    ],
    primaryColor: "#8A54B0", secondaryColor: "#C4A3DB"
  ),

  WaxProduct(
    brand: .rode, code: "P50", nameKey: "Wax_RodeP50_Name", seriesCode: "P", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 3)],
      .transformedMoistFine: [TempRangeC(0, 2)],
    ],
    primaryColor: "#C9342B", secondaryColor: "#E58B84"
  ),

  WaxProduct(
    brand: .rode, code: "P52", nameKey: "Wax_RodeP52_Name", seriesCode: "P", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 2)],
      .moistFineGrained: [TempRangeC(-1, 1)],
      .transformedMoistFine: [TempRangeC(-1, 1)],
    ],
    primaryColor: "#B82E26", secondaryColor: "#DE8079"
  ),

  WaxProduct(
    brand: .rode, code: "P60", nameKey: "Wax_RodeP60_Name", seriesCode: "P", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(1, 4)],
      .transformedMoistFine: [TempRangeC(1, 4)],
    ],
    primaryColor: "#EFC32A", secondaryColor: "#F7DF8E"
  ),

  WaxProduct(
    brand: .rode, code: "P70", nameKey: "Wax_RodeP70_Name", seriesCode: "P", kind: .binder,
    ranges: [
      .newFallen: [TempRangeC(-20, -2)],
      .fineGrained: [TempRangeC(-20, -2)],
      .oldGrained: [TempRangeC(-20, -2)],
      .moistFineGrained: [TempRangeC(-20, -2)],
    ],
    notesKey: "Wax_RodeP70_Notes",
    primaryColor: "#1A1A1A", secondaryColor: "#5A5A5A"
  ),

  // ===== Multigrade hard waxes =====

  WaxProduct(
    brand: .rode, code: "P36", nameKey: "Wax_RodeP36_Name", seriesCode: "PMG", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-7, -3)],
      .fineGrained: [TempRangeC(-12, -5)],
      .oldGrained: [TempRangeC(-12, -5)],
    ],
    notesKey: "Wax_RodeMultigrade_Notes",
    primaryColor: "#2458A8", secondaryColor: "#A9C6E8"
  ),

  WaxProduct(
    brand: .rode, code: "P38", nameKey: "Wax_RodeP38_Name", seriesCode: "PMG", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-5, -1)],
      .fineGrained: [TempRangeC(-10, -3)],
      .oldGrained: [TempRangeC(-10, -3)],
    ],
    notesKey: "Wax_RodeMultigrade_Notes",
    primaryColor: "#3570C4", secondaryColor: "#B4CDEB"
  ),

  WaxProduct(
    brand: .rode, code: "P46", nameKey: "Wax_RodeP46_Name", seriesCode: "PMG", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(-2, 0)],
      .moistFineGrained: [TempRangeC(-5, -3)],
      .oldGrained: [TempRangeC(-5, -3)],
    ],
    notesKey: "Wax_RodeMultigrade_Notes",
    primaryColor: "#8A54B0", secondaryColor: "#D2BCE4"
  ),

  // ===== K line — klister =====
  // Colours follow the printed 60 g tubes, which are coloured by grade
  // (K50 Silver is teal, K80 Black is a copper tube).

  WaxProduct(
    brand: .rode, code: "K10", nameKey: "Wax_RodeK10_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .frozenCorn: [TempRangeC(-14, -6)]
    ],
    notesKey: "Wax_RodeK10_Notes",
    primaryColor: "#2F6FC9", secondaryColor: "#8FB4E4"
  ),

  WaxProduct(
    brand: .rode, code: "K20", nameKey: "Wax_RodeK20_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .frozenCorn: [TempRangeC(-7, -3)],
      .transformedMoistFine: [TempRangeC(-7, -3)],
    ],
    primaryColor: "#4B3FA8", secondaryColor: "#9C93D8"
  ),

  WaxProduct(
    brand: .rode, code: "K30", nameKey: "Wax_RodeK30_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-3, 1)],
      .frozenCorn: [TempRangeC(-3, -1)],
      .wetCorn: [TempRangeC(-3, 1)],
    ],
    notesKey: "Wax_RodeK30_Notes",
    primaryColor: "#B0328C", secondaryColor: "#D98CC2"
  ),

  WaxProduct(
    brand: .rode, code: "K36", nameKey: "Wax_RodeK36_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .frozenCorn: [TempRangeC(-5, -1)],
      .transformedMoistFine: [TempRangeC(-5, -1)],
    ],
    primaryColor: "#D9467E", secondaryColor: "#EFA2BF"
  ),

  WaxProduct(
    brand: .rode, code: "K40", nameKey: "Wax_RodeK40_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-2, 4)],
      .wetCorn: [TempRangeC(-2, 4)],
      .frozenCorn: [TempRangeC(-2, 0)],
    ],
    notesKey: "Wax_RodeK40_Notes",
    primaryColor: "#C9342B", secondaryColor: "#E58B84"
  ),

  WaxProduct(
    brand: .rode, code: "K46", nameKey: "Wax_RodeK46_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(0, 3)],
      .wetCorn: [TempRangeC(0, 3)],
    ],
    primaryColor: "#B82E26", secondaryColor: "#DE8079"
  ),

  WaxProduct(
    brand: .rode, code: "K50", nameKey: "Wax_RodeK50_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .wetCorn: [TempRangeC(1, 5)],
      .veryWetCorn: [TempRangeC(1, 5)],
    ],
    notesKey: "Wax_RodeK50_Notes",
    primaryColor: "#3F8C84", secondaryColor: "#93C6BF"
  ),

  WaxProduct(
    brand: .rode, code: "K52", nameKey: "Wax_RodeK52_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .wetCorn: [TempRangeC(0, 4)],
      .veryWetCorn: [TempRangeC(0, 4)],
    ],
    primaryColor: "#6FB3DE", secondaryColor: "#B9DCF1"
  ),

  WaxProduct(
    brand: .rode, code: "K60", nameKey: "Wax_RodeK60_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .wetCorn: [TempRangeC(0, 2)],
      .veryWetCorn: [TempRangeC(0, 2)],
    ],
    primaryColor: "#EFC32A", secondaryColor: "#F7DF8E"
  ),

  WaxProduct(
    brand: .rode, code: "K70", nameKey: "Wax_RodeK70_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(0, 0)],
      .frozenCorn: [TempRangeC(0, 0)],
      .wetCorn: [TempRangeC(0, 0)],
    ],
    notesKey: "Wax_RodeK70_Notes",
    primaryColor: "#E5862B", secondaryColor: "#F3C08A"
  ),

  WaxProduct(
    brand: .rode, code: "K76", nameKey: "Wax_RodeK76_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-6, 6)],
      .frozenCorn: [TempRangeC(-6, 0)],
      .wetCorn: [TempRangeC(-6, 6)],
      .veryWetCorn: [TempRangeC(0, 6)],
    ],
    notesKey: "Wax_RodeK76_Notes",
    primaryColor: "#7DB7E3", secondaryColor: "#D23A2B"
  ),

  WaxProduct(
    brand: .rode, code: "K80", nameKey: "Wax_RodeK80_Name", seriesCode: "K", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-2, 5)],
      .wetCorn: [TempRangeC(-2, 5)],
      .veryWetCorn: [TempRangeC(0, 5)],
    ],
    primaryColor: "#C28D5C", secondaryColor: "#E3C29E"
  ),

  WaxProduct(
    brand: .rode, code: "K90", nameKey: "Wax_RodeK90_Name", seriesCode: "K", kind: .binder,
    ranges: [
      .transformedMoistFine: [TempRangeC(-12, 10)],
      .frozenCorn: [TempRangeC(-12, 10)],
      .wetCorn: [TempRangeC(-12, 10)],
      .veryWetCorn: [TempRangeC(-12, 15)],
    ],
    notesKey: "Wax_RodeK90_Notes",
    primaryColor: "#4A3A2A", secondaryColor: "#8A7158"
  ),
]
