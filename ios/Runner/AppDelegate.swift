import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private let widgetChannelName = "com.example.dienstlog/widget"
  private let appGroupName = "group.com.logworks.tourlog"
  private let widgetKind = "TourLogWidget"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: widgetChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "APP_DELEGATE_UNAVAILABLE", message: "AppDelegate ist nicht verfügbar.", details: nil))
        return
      }

      switch call.method {
      case "updateWidget":
        self.updateWidget(call: call, result: result)
      case "getPendingWorkStart":
        self.getPendingWorkStart(result: result)
      case "ackPendingWorkStart":
        self.ackPendingWorkStart(call: call, result: result)
      case "getPendingWidgetActions":
        self.getPendingWidgetActions(result: result)
      case "ackPendingWidgetAction":
        self.ackPendingWidgetAction(call: call, result: result)
      case "clearWidget":
        self.clearWidget(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func getPendingWorkStart(result: @escaping FlutterResult) {
    guard let defaults = UserDefaults(suiteName: appGroupName) else {
      result(FlutterError(code: "APP_GROUP_UNAVAILABLE", message: "App Group fehlt.", details: nil))
      return
    }
    result(pendingItems(defaults: defaults, prefixes: ["tourlog.pending.workStart."]))
  }

  private func getPendingWidgetActions(result: @escaping FlutterResult) {
    guard let defaults = UserDefaults(suiteName: appGroupName) else {
      result(FlutterError(code: "APP_GROUP_UNAVAILABLE", message: "App Group fehlt.", details: nil))
      return
    }
    result(pendingItems(defaults: defaults, prefixes: ["tourlog.pending.deliveryEnd.", "tourlog.pending.workEnd."]))
  }

  private func pendingItems(defaults: UserDefaults, prefixes: [String]) -> [[String: Any]] {
    let keys = defaults.dictionaryRepresentation().keys.filter { key in
      prefixes.contains { key.hasPrefix($0) }
    }.sorted()
    return keys.compactMap { key in
      guard let timestamp = defaults.object(forKey: key) as? NSNumber else { return nil }
      return ["key": key, "timestamp": timestamp.int64Value]
    }
  }

  private func ackPendingWorkStart(call: FlutterMethodCall, result: @escaping FlutterResult) {
    acknowledge(call: call, result: result, allowedPrefixes: ["tourlog.pending.workStart."])
  }

  private func ackPendingWidgetAction(call: FlutterMethodCall, result: @escaping FlutterResult) {
    acknowledge(call: call, result: result, allowedPrefixes: ["tourlog.pending.deliveryEnd.", "tourlog.pending.workEnd."])
  }

  private func acknowledge(
    call: FlutterMethodCall,
    result: @escaping FlutterResult,
    allowedPrefixes: [String]
  ) {
    guard let defaults = UserDefaults(suiteName: appGroupName),
          let args = call.arguments as? [String: Any],
          let key = args["key"] as? String,
          let timestamp = args["timestamp"] as? NSNumber,
          allowedPrefixes.contains(where: { key.hasPrefix($0) }) else {
      result(FlutterError(code: "INVALID_ACK", message: "Ungueltige Bestaetigung.", details: nil))
      return
    }
    if let current = defaults.object(forKey: key) as? NSNumber,
       current.int64Value == timestamp.int64Value {
      defaults.removeObject(forKey: key)
    }
    result(nil)
  }

  // Ein Widget-Zeitwert mit ausstehender Buchung darf nicht durch einen
  // veralteten SQLite-Snapshot aus Flutter geloescht/ueberschrieben werden.
  private func updateWidget(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let day = arguments["date"] as? String,
          !day.isEmpty else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Widget-Daten konnten nicht gelesen werden.", details: nil))
      return
    }
    guard let defaults = UserDefaults(suiteName: appGroupName) else {
      result(FlutterError(code: "APP_GROUP_UNAVAILABLE", message: "Die App Group konnte nicht geöffnet werden.", details: appGroupName))
      return
    }

    // Aeltere asynchrone Updates duerfen die Anzeige eines anderen Tages
    // nicht mehr veraendern.
    guard day == todayString() else {
      result(nil)
      return
    }

    let displayedDay = defaults.string(forKey: "workDayDate")
    let fields: [(field: String, pendingKind: String)] = [
      ("workStart", "workStart"),
      ("deliveryStart", "deliveryStart"),
      ("deliveryEnd", "deliveryEnd"),
      ("workEnd", "workEnd")
    ]

    for field in fields {
      let pendingKey = "tourlog.pending.\(field.pendingKind).\(day)"
      let hasPending = defaults.object(forKey: pendingKey) != nil
      if hasPending && displayedDay == day {
        // Der AppIntent hat bereits den korrekten Zeitpunkt angezeigt.
        continue
      }
      setOptionalString(arguments[field.field], key: field.field, defaults: defaults)
    }

    defaults.set(day, forKey: "workDayDate")
    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    result(nil)
  }

  private func clearWidget(result: @escaping FlutterResult) {
    guard let defaults = UserDefaults(suiteName: appGroupName) else {
      result(FlutterError(code: "APP_GROUP_UNAVAILABLE", message: "Die App Group konnte nicht geöffnet werden.", details: appGroupName))
      return
    }

    let day = todayString()
    let displayedDay = defaults.string(forKey: "workDayDate")
    let fields: [(field: String, pendingKind: String)] = [
      ("workStart", "workStart"),
      ("deliveryStart", "deliveryStart"),
      ("deliveryEnd", "deliveryEnd"),
      ("workEnd", "workEnd")
    ]

    var preservedPending = false
    for field in fields {
      let pendingKey = "tourlog.pending.\(field.pendingKind).\(day)"
      if displayedDay == day && defaults.object(forKey: pendingKey) != nil {
        preservedPending = true
      } else {
        defaults.removeObject(forKey: field.field)
      }
    }

    if preservedPending {
      defaults.set(day, forKey: "workDayDate")
    } else {
      defaults.removeObject(forKey: "workDayDate")
    }

    // Ausstehende Buchungen werden niemals durch clearWidget geloescht.
    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    result(nil)
  }

  private func todayString() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }

  private func setOptionalString(_ value: Any?, key: String, defaults: UserDefaults) {
    if let stringValue = value as? String, !stringValue.isEmpty {
      defaults.set(stringValue, forKey: key)
    } else {
      defaults.removeObject(forKey: key)
    }
  }
}
