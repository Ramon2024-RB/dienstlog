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
        guard let defaults = UserDefaults(suiteName: "group.com.example.dienstlog") else {
            throw TourLogWidgetIntentError.appGroupUnavailable
        }

        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: now)

        // Keine zweite Buchung anlegen, solange ein Dienstbeginn
        // für denselben Tag bereits erfasst oder angezeigt wird.
        if defaults.string(forKey: "workDayDate") == date,
           defaults.string(forKey: "workStart") != nil {
            return .result()
        }

        let pendingKey = "tourlog.pending.workStart.\(date)"
        if defaults.object(forKey: pendingKey) != nil {
            return .result()
        }

        // Unixzeit in Millisekunden: der ursprüngliche Tipp-Zeitpunkt
        // bleibt erhalten, auch wenn die App erst später geöffnet wird.
        let timestamp = Int64(now.timeIntervalSince1970 * 1000)
        defaults.set(timestamp, forKey: pendingKey)

        // Sichtbar als vorläufig erfasste Uhrzeit; SQLite wird erst
        // nach der Übernahme in der App zur Quelle der Wahrheit.
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
