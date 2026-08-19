//
//  TourLogWidget.swift
//  TourLogWidget
//
//  Created by Nico Albert on 19.08.26.
//

import WidgetKit
import SwiftUI

struct TourLogEntry: TimelineEntry {
    let date: Date

    let workStart: String?
    let deliveryStart: String?
    let deliveryEnd: String?
    let workEnd: String?
}

struct TourLogProvider: TimelineProvider {

    func placeholder(in context: Context) -> TourLogEntry {
        TourLogEntry(
            date: Date(),
            workStart: "07:03",
            deliveryStart: "08:16",
            deliveryEnd: nil,
            workEnd: nil
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (TourLogEntry) -> Void
    ) {
        let entry = TourLogEntry(
            date: Date(),
            workStart: "07:03",
            deliveryStart: "08:16",
            deliveryEnd: nil,
            workEnd: nil
        )

        completion(entry)
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<TourLogEntry>) -> Void
    ) {
        let entry = TourLogEntry(
            date: Date(),
            workStart: nil,
            deliveryStart: nil,
            deliveryEnd: nil,
            workEnd: nil
        )

        let timeline = Timeline(
            entries: [entry],
            policy: .never
        )

        completion(timeline)
    }
}

struct TourLogWidgetEntryView: View {

    let entry: TourLogEntry

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.black)

                Text("TourLog")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Text("Heute")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 8) {

                TourLogAction(
                    icon: "clock.fill",
                    title: "Dienst",
                    time: entry.workStart
                )

                TourLogAction(
                    icon: "truck.box.fill",
                    title: "Start",
                    time: entry.deliveryStart
                )
            }

            HStack(spacing: 8) {

                TourLogAction(
                    icon: "shippingbox.fill",
                    title: "Ende",
                    time: entry.deliveryEnd
                )

                TourLogAction(
                    icon: "flag.checkered",
                    title: "Feierabend",
                    time: entry.workEnd
                )
            }
        }
        .padding()
        .containerBackground(
            Color.yellow.opacity(0.20),
            for: .widget
        )
    }
}

struct TourLogAction: View {

    let icon: String
    let title: String
    let time: String?

    var body: some View {
        HStack(spacing: 7) {

            Image(
                systemName: time == nil
                    ? icon
                    : "checkmark.circle.fill"
            )
            .font(.system(size: 15))
            .foregroundStyle(
                time == nil
                    ? Color.primary
                    : Color.green
            )

            VStack(
                alignment: .leading,
                spacing: 1
            ) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(time ?? "Tippen")
                    .font(.caption)
                    .fontWeight(
                        time == nil
                            ? .regular
                            : .bold
                    )
                    .foregroundStyle(
                        time == nil
                            ? Color.secondary
                            : Color.primary
                    )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            Color.primary.opacity(0.06)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 10
            )
        )
    }
}

struct TourLogWidget: Widget {

    let kind: String = "TourLogWidget"

    var body: some WidgetConfiguration {

        StaticConfiguration(
            kind: kind,
            provider: TourLogProvider()
        ) { entry in

            TourLogWidgetEntryView(
                entry: entry
            )
        }
        .configurationDisplayName("TourLog")
        .description(
            "Dienst- und Zustellzeiten direkt im Blick."
        )
        .supportedFamilies([
            .systemMedium
        ])
    }
}

#Preview(
    as: .systemMedium
) {
    TourLogWidget()
} timeline: {

    TourLogEntry(
        date: .now,
        workStart: "07:03",
        deliveryStart: "08:16",
        deliveryEnd: nil,
        workEnd: nil
    )
}
