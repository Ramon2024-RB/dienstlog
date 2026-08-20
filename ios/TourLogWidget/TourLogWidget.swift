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

    private let appGroupName = "group.com.example.dienstlog"

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
        if context.isPreview {
            completion(
                TourLogEntry(
                    date: Date(),
                    workStart: "07:03",
                    deliveryStart: "08:16",
                    deliveryEnd: nil,
                    workEnd: nil
                )
            )

            return
        }

        completion(
            makeCurrentEntry()
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<TourLogEntry>) -> Void
    ) {
        let entry = makeCurrentEntry()

        let nextMidnight =
            Calendar.current.nextDate(
                after: Date(),
                matching: DateComponents(
                    hour: 0,
                    minute: 0,
                    second: 5
                ),
                matchingPolicy: .nextTime
            )

        let timeline = Timeline(
            entries: [entry],
            policy: nextMidnight.map {
                .after($0)
            } ?? .never
        )

        completion(timeline)
    }

    private func makeCurrentEntry() -> TourLogEntry {

        guard
            let defaults = UserDefaults(
                suiteName: appGroupName
            )
        else {
            return emptyEntry()
        }

        guard
            let storedDate = defaults.string(
                forKey: "workDayDate"
            ),
            storedDate == todayString()
        else {
            return emptyEntry()
        }

        return TourLogEntry(
            date: Date(),
            workStart: defaults.string(
                forKey: "workStart"
            ),
            deliveryStart: defaults.string(
                forKey: "deliveryStart"
            ),
            deliveryEnd: defaults.string(
                forKey: "deliveryEnd"
            ),
            workEnd: defaults.string(
                forKey: "workEnd"
            )
        )
    }

    private func emptyEntry() -> TourLogEntry {
        TourLogEntry(
            date: Date(),
            workStart: nil,
            deliveryStart: nil,
            deliveryEnd: nil,
            workEnd: nil
        )
    }

    private func todayString() -> String {
        let calendar = Calendar.current

        let components = calendar.dateComponents(
            [
                .year,
                .month,
                .day
            ],
            from: Date()
        )

        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0

        return String(
            format: "%04d-%02d-%02d",
            year,
            month,
            day
        )
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
                Image(
                    systemName: "shippingbox.fill"
                )
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

                Link(
                    destination: URL(
                        string:
                            "tourlog://quick/work-start"
                    )!
                ) {
                    TourLogAction(
                        icon: "clock.fill",
                        title: "Dienst",
                        time: entry.workStart
                    )
                }
                .buttonStyle(.plain)

                Link(
                    destination: URL(
                        string:
                            "tourlog://quick/delivery-start"
                    )!
                ) {
                    TourLogAction(
                        icon: "truck.box.fill",
                        title: "Start",
                        time: entry.deliveryStart
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {

                Link(
                    destination: URL(
                        string:
                            "tourlog://quick/delivery-end"
                    )!
                ) {
                    TourLogAction(
                        icon: "shippingbox.fill",
                        title: "Ende",
                        time: entry.deliveryEnd
                    )
                }
                .buttonStyle(.plain)

                Link(
                    destination: URL(
                        string:
                            "tourlog://quick/work-end"
                    )!
                ) {
                    TourLogAction(
                        icon: "flag.checkered",
                        title: "Feierabend",
                        time: entry.workEnd
                    )
                }
                .buttonStyle(.plain)
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
                systemName:
                    time == nil
                        ? icon
                        : "checkmark.circle.fill"
            )
            .font(
                .system(
                    size: 15
                )
            )
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

                Text(
                    time ?? "Tippen"
                )
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

            Spacer(
                minLength: 0
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(
            .horizontal,
            9
        )
        .padding(
            .vertical,
            7
        )
        .background(
            Color.primary.opacity(
                0.06
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 10
            )
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: 10
            )
        )
    }
}

struct TourLogWidget: Widget {

    let kind: String =
        "TourLogWidget"

    var body: some WidgetConfiguration {

        StaticConfiguration(
            kind: kind,
            provider: TourLogProvider()
        ) { entry in

            TourLogWidgetEntryView(
                entry: entry
            )
        }
        .configurationDisplayName(
            "TourLog"
        )
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