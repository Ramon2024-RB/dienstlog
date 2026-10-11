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
    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }

  func didInitializeImplicitFlutterEngine(
    _ engineBridge: FlutterImplicitEngineBridge
  ) {
    GeneratedPluginRegistrant.register(
      with: engineBridge.pluginRegistry
    )

    let channel = FlutterMethodChannel(
      name: widgetChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(
          FlutterError(
            code: "APP_DELEGATE_UNAVAILABLE",
            message: "AppDelegate ist nicht verfügbar.",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "updateWidget":
        self.updateWidget(
          call: call,
          result: result
        )

      case "getPendingWorkStart":
        self.getPendingWorkStart(result: result)

      case "ackPendingWorkStart":
        self.ackPendingWorkStart(call: call, result: result)

      case "getPendingWidgetActions":
        self.getPendingWidgetActions(result: result)

      case "ackPendingWidgetAction":
        self.ackPendingWidgetAction(call: call, result: result)

      case "clearWidget":
        self.clearWidget(
          result: result
        )

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // Eine Buchung erst nach erfolgreicher SQLite-Uebernahme bestaetigen.
  private func getPendingWorkStart(result: @escaping FlutterResult) {
    guard let defaults = UserDefaults(suiteName: appGroupName) else {
      result(FlutterError(code: "APP_GROUP_UNAVAILABLE", message: "App Group fehlt.", details: nil))
      return
    }
    let prefix = "tourlog.pending.workStart."
    let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }.sorted()
    let items: [[String: Any]] = keys.compactMap { key in
      guard let number = defaults.object(forKey: key) as? NSNumber else { return nil }
      return ["key": key, "timestamp": number.int64Value]
    }
    result(items)
  }

  private func ackPendingWorkStart(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let defaults = UserDefaults(suiteName: appGroupName),
          let args = call.arguments as? [String: Any],
          let key = args["key"] as? String,
          let timestamp = args["timestamp"] as? NSNumber,
          key.hasPrefix("tourlog.pending.workStart.") else {
      result(FlutterError(code: "INVALID_ACK", message: "Ungueltige Bestaetigung.", details: nil))
      return
    }
    // Nur genau die Buchung entfernen, die Flutter tatsaechlich verarbeitet hat.
    if let current = defaults.object(forKey: key) as? NSNumber,
       current.int64Value == timestamp.int64Value {
      defaults.removeObject(forKey: key)
    }
    result(nil)
  }

  private func getPendingWidgetActions(result: @escaping FlutterResult) {
    guard let defaults = UserDefaults(suiteName: appGroupName) else {
      result(FlutterError(code: "APP_GROUP_UNAVAILABLE", message: "App Group fehlt.", details: nil))
      return
    }
    let prefixes = ["tourlog.pending.deliveryEnd.", "tourlog.pending.workEnd."]
    let keys = defaults.dictionaryRepresentation().keys.filter { key in
      prefixes.contains { key.hasPrefix($0) }
    }.sorted()
    let items: [[String: Any]] = keys.compactMap { key in
      guard let number = defaults.object(forKey: key) as? NSNumber else { return nil }
      return ["key": key, "timestamp": number.int64Value]
    }
    result(items)
  }

  private func ackPendingWidgetAction(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let defaults = UserDefaults(suiteName: appGroupName),
          let args = call.arguments as? [String: Any],
          let key = args["key"] as? String,
          let timestamp = args["timestamp"] as? NSNumber,
          (key.hasPrefix("tourlog.pending.deliveryEnd.") || key.hasPrefix("tourlog.pending.workEnd.")) else {
      result(FlutterError(code: "INVALID_ACK", message: "Ungueltige Bestaetigung.", details: nil))
      return
    }
    if let current = defaults.object(forKey: key) as? NSNumber,
       current.int64Value == timestamp.int64Value {
      defaults.removeObject(forKey: key)
    }
    result(nil)
  }

  private func updateWidget(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard
      let arguments = call.arguments as? [String: Any]
    else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Widget-Daten konnten nicht gelesen werden.",
          details: nil
        )
      )
      return
    }

    guard
      let defaults = UserDefaults(
        suiteName: appGroupName
      )
    else {
      result(
        FlutterError(
          code: "APP_GROUP_UNAVAILABLE",
          message: "Die App Group konnte nicht geöffnet werden.",
          details: appGroupName
        )
      )
      return
    }

    setOptionalString(
      arguments["workStart"],
      key: "workStart",
      defaults: defaults
    )

    setOptionalString(
      arguments["deliveryStart"],
      key: "deliveryStart",
      defaults: defaults
    )

    let currentDay = arguments["date"] as? String ?? ""
    let hasPendingDeliveryEnd = defaults.object(forKey: "tourlog.pending.deliveryEnd.\(currentDay)") != nil
    let hasPendingWorkEnd = defaults.object(forKey: "tourlog.pending.workEnd.\(currentDay)") != nil

    if !hasPendingDeliveryEnd {
    setOptionalString(
      arguments["deliveryEnd"],
      key: "deliveryEnd",
      defaults: defaults
    )

    }
    if !hasPendingWorkEnd {
    setOptionalString(
      arguments["workEnd"],
      key: "workEnd",
      defaults: defaults
    )

    }
    if let date = arguments["date"] as? String {
      defaults.set(
        date,
        forKey: "workDayDate"
      )
    }

    WidgetCenter.shared.reloadTimelines(
      ofKind: widgetKind
    )

    result(nil)
  }

  private func clearWidget(
    result: @escaping FlutterResult
  ) {
    guard
      let defaults = UserDefaults(
        suiteName: appGroupName
      )
    else {
      result(
        FlutterError(
          code: "APP_GROUP_UNAVAILABLE",
          message: "Die App Group konnte nicht geöffnet werden.",
          details: appGroupName
        )
      )
      return
    }

    defaults.removeObject(
      forKey: "workStart"
    )

    defaults.removeObject(
      forKey: "deliveryStart"
    )

    defaults.removeObject(
      forKey: "deliveryEnd"
    )

    defaults.removeObject(
      forKey: "workEnd"
    )

    defaults.removeObject(
      forKey: "workDayDate"
    )

    WidgetCenter.shared.reloadTimelines(
      ofKind: widgetKind
    )

    result(nil)
  }

  private func setOptionalString(
    _ value: Any?,
    key: String,
    defaults: UserDefaults
  ) {
    if let stringValue = value as? String,
       !stringValue.isEmpty {
      defaults.set(
        stringValue,
        forKey: key
      )
    } else {
      defaults.removeObject(
        forKey: key
      )
    }
  }
}
