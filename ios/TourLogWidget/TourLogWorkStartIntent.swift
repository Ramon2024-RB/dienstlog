import AppIntents
import Foundation
import WidgetKit

/// Erfasst den Dienstbeginn ohne die Flutter-App zu starten.
/// Die eigentliche Übernahme in SQLite erfolgt später durch die Flutter-App.
@available(iOS 17.0, *)
struct TourLogWorkStartIntent: AppIntent {
    static var title: LocalizedStringResource = "Dienst beginnen"
    static var description = IntentDescription("Erfasst den Dienstbeginn in TourLog.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: "group.com.logworks.tourlog") else {
            throw TourLogWidgetIntentError.appGroupUnavailable
        }

        let now = Date()
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: now)

        let pendingKey = "tourlog.pending.workStart.\(date)"
        let displayedDate = defaults.string(forKey: "workDayDate")

        // Ein bereits erfasster Dienstbeginn von heute darf nicht überschrieben werden.
        if displayedDate == date,
           defaults.string(forKey: "workStart") != nil {
            return .result()
        }
        if defaults.object(forKey: pendingKey) != nil {
            return .result()
        }

        // Beim ersten Dienstbeginn eines neuen Tages nur die ANZEIGEWERTE
        // des Vortages entfernen. Pending-Buchungen anderer Tage und die
        // SQLite-Datenbank bleiben vollständig unangetastet.
        if displayedDate != date {
            for key in ["workStart", "deliveryStart", "deliveryEnd", "workEnd"] {
                defaults.removeObject(forKey: key)
            }
        }

        // Unixzeit in Millisekunden: Der ursprüngliche Tipp-Zeitpunkt
        // bleibt erhalten, auch wenn die App erst später geöffnet wird.
        let timestamp = Int64(now.timeIntervalSince1970 * 1000)
        defaults.set(timestamp, forKey: pendingKey)

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "de_DE")
        timeFormatter.timeZone = .current
        timeFormatter.dateFormat = "HH:mm"

        defaults.set(date, forKey: "workDayDate")
        defaults.set(timeFormatter.string(from: now), forKey: "workStart")
        WidgetCenter.shared.reloadTimelines(ofKind: "TourLogWidget")
        return .result()
    }
}

enum TourLogWidgetIntentError: Error {
    case appGroupUnavailable
}