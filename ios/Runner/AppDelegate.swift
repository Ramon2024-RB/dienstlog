import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private let widgetChannelName = "com.example.dienstlog/widget"
  private let appGroupName = "group.com.example.dienstlog"
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

      case "clearWidget":
        self.clearWidget(
          result: result
        )

      default:
        result(FlutterMethodNotImplemented)
      }
    }
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

    setOptionalString(
      arguments["deliveryEnd"],
      key: "deliveryEnd",
      defaults: defaults
    )

    setOptionalString(
      arguments["workEnd"],
      key: "workEnd",
      defaults: defaults
    )

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