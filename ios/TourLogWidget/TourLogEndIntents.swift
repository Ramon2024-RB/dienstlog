import AppIntents
import Foundation
import WidgetKit

// Diese Aktionen speichern die Uhrzeit in der App Group.
// Die Flutter-App übernimmt sie beim nächsten Öffnen in SQLite.
@available(iOS 17.0, *)
struct TourLogDeliveryEndIntent: AppIntent {
    static var title: LocalizedStringResource = "Zustellung beenden"
    static var description = IntentDescription("Erfasst das Zustellungsende in TourLog.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        try TourLogPendingAction.record(kind: "deliveryEnd")
        return .result()
    }
}

@available(iOS 17.0, *)
struct TourLogWorkEndIntent: AppIntent {
    static var title: LocalizedStringResource = "Dienst beenden"
    static var description = IntentDescription("Erfasst den Feierabend in TourLog.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        try TourLogPendingAction.record(kind: "workEnd")
        return .result()
    }
}

private enum TourLogPendingAction {
    static func record(kind: String) throws {
        guard let defaults = UserDefaults(suiteName: "group.com.logworks.tourlog") else {
            throw TourLogWidgetIntentError.appGroupUnavailable
        }
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let day = dateFormatter.string(from: now)
        let pendingKey = "tourlog.pending.\(kind).\(day)"
        let storedDay = defaults.string(forKey: "workDayDate")
        if storedDay == day && defaults.string(forKey: kind) != nil { return }
        if defaults.object(forKey: pendingKey) != nil { return }

        // Endzeiten dürfen erst nach einem tatsächlichen Start gesetzt werden.
        let prerequisite = kind == "deliveryEnd" ? "deliveryStart" : "workStart"
        guard storedDay == day, defaults.string(forKey: prerequisite) != nil else {
            throw TourLogPendingError.missingStart
        }
        if kind == "workEnd", defaults.string(forKey: "deliveryStart") != nil,
           defaults.string(forKey: "deliveryEnd") == nil {
            throw TourLogPendingError.deliveryStillRunning
        }
        let timestamp = Int64(now.timeIntervalSince1970 * 1000)
        defaults.set(timestamp, forKey: pendingKey)
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "de_DE")
        timeFormatter.timeZone = .current
        timeFormatter.dateFormat = "HH:mm"
        defaults.set(timeFormatter.string(from: now), forKey: kind)
        defaults.set(day, forKey: "workDayDate")
        WidgetCenter.shared.reloadTimelines(ofKind: "TourLogWidget")
    }
}

private enum TourLogPendingError: Error {
    case missingStart
    case deliveryStillRunning
}
