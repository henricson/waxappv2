//
//  GetGripWidgetBundle.swift
//  GetGripWidget
//

import SwiftUI
import WidgetKit

@main
struct GetGripWidgetBundle: WidgetBundle {
  var body: some Widget {
    WaxWidget()
  }
}

struct WaxWidget: Widget {
  let kind = "WaxWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: WaxWidgetIntent.self, provider: WaxWidgetProvider()) { entry in
      WaxWidgetView(entry: entry)
    }
    .configurationDisplayName("Wax of the Day")
    .description("Widget_Description")
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge,
      .accessoryInline, .accessoryCircular, .accessoryRectangular,
    ])
  }
}

#Preview("Small", as: .systemSmall) {
  WaxWidget()
} timeline: {
  WaxEntry.sample(choice: .automatic)
  WaxEntry.sample(choice: .both)
}

#Preview("Medium", as: .systemMedium) {
  WaxWidget()
} timeline: {
  WaxEntry.sample(choice: .automatic)
  WaxEntry.sample(choice: .grip)
}

#Preview("Large", as: .systemLarge) {
  WaxWidget()
} timeline: {
  WaxEntry.sample(choice: .automatic)
  WaxEntry.sample(choice: .glide)
}
