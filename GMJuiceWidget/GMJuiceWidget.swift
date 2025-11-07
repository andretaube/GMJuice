//
//  GMJuiceWidget.swift
//  GMJuiceWidget
//
//  Created by Andre Taube on 11/6/25.
//

import WidgetKit
import SwiftUI

@main
struct GMJuiceWidgetBundle: WidgetBundle {
    var body: some Widget {
        GMJuiceWidget()
    }
}

struct GMJuiceWidget: Widget {
    let kind: String = "GMJuiceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PerformanceProvider()) { entry in
            PerformanceWidgetView(entry: entry)
                .containerBackground(Color.black, for: .widget)
        }
        .configurationDisplayName("Steel Challenge Progress")
        .description("Track your classification progress and recent performance")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
