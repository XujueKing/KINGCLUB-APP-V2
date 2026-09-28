import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var chatPush: AppleChatPush?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    chatPush = AppleChatPush(messenger: engineBridge.applicationRegistrar.messenger())
  }
  override func application(_ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    chatPush?.registered(deviceToken)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(_ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error) {
    chatPush?.registrationFailed()
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // The authenticated realtime receiver owns the foreground in-app banner.
    if notification.request.content.userInfo["kingclub_push"] != nil {
      completionHandler([])
    } else {
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void) {
    if let raw = response.notification.request.content.userInfo["kingclub_push"] as? String {
      AppleChatPush.saveClick(raw)
      chatPush?.clickChanged()
      completionHandler()
    } else {
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }
  }
}

/// No APNs signing key belongs in the application. Only the device token crosses
/// this channel; the authenticated server establishes its owner.
private final class AppleChatPush {
  private let registration: FlutterMethodChannel
  private let clicks: FlutterMethodChannel
  private let notifications: FlutterMethodChannel
  private var waiting: FlutterResult?
  private var timeout: DispatchWorkItem?

  init(messenger: FlutterBinaryMessenger) {
    registration = FlutterMethodChannel(name: "kingclub/push-registration", binaryMessenger: messenger)
    clicks = FlutterMethodChannel(name: "kingclub/push-open", binaryMessenger: messenger)
    notifications = FlutterMethodChannel(name: "kingclub/local-notifications", binaryMessenger: messenger)
    registration.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "notificationStatus":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          DispatchQueue.main.async {
            result([.authorized, .provisional].contains(settings.authorizationStatus))
          }
        }
      case "requestNotificationPermission":
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
          DispatchQueue.main.async {
            result(error == nil ? nil : FlutterError(code: "PUSH_PERMISSION_FAILED", message: "Notification permission unavailable", details: nil))
          }
        }
      case "openNotificationSettings":
        guard let url = URL(string: UIApplication.openSettingsURLString) else { result(false); return }
        UIApplication.shared.open(url) { success in
          result(success ? nil : FlutterError(code: "PUSH_SETTINGS_FAILED", message: "Settings unavailable", details: nil))
        }
      case "registerApple":
        guard self.waiting == nil else {
          result(FlutterError(code: "PUSH_BUSY", message: "Registration already pending", details: nil)); return
        }
        self.waiting = result
        let task = DispatchWorkItem { [weak self] in self?.registrationFailed() }
        self.timeout = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: task)
        UIApplication.shared.registerForRemoteNotifications()
      default: result(FlutterMethodNotImplemented)
      }
    }
    clicks.setMethodCallHandler { call, result in
      do {
        var values = try Self.readClicks()
        switch call.method {
        case "takePending": result(values.first)
        case "ackPending":
          if let raw = call.arguments as? String, values.first == raw {
            values.removeFirst()
            try Self.writeClicks(values)
          }
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "PUSH_PENDING_STORAGE", message: "Notification recovery unavailable", details: nil))
      }
    }
    notifications.setMethodCallHandler { call, result in
      if call.method == "badge", let args = call.arguments as? [String: Any], let count = args["count"] as? Int {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          DispatchQueue.main.async {
            guard settings.badgeSetting == .enabled else { result(false); return }
            let value = max(0, min(9999, count))
            if #available(iOS 16.0, *) {
              UNUserNotificationCenter.current().setBadgeCount(value) { error in
                DispatchQueue.main.async { result(error == nil) }
              }
            } else {
              UIApplication.shared.applicationIconBadgeNumber = value
              result(true)
            }
          }
        }
      } else {
        // Never acknowledge local display when only APNs can actually notify.
        result(false)
      }
    }
  }

  private static func environment() -> String? {
    // Development-signed Release/Profile builds still use Apple's sandbox.
    // Read the signed provisioning profile rather than infer from Dart mode.
    if let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
       let data = try? Data(contentsOf: url), data.count < 1024 * 1024,
       let start = data.range(of: Data("<?xml".utf8)),
       let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
       let profile = (try? PropertyListSerialization.propertyList(from: data.subdata(in: start.lowerBound..<end.upperBound), options: [], format: nil)) as? [String: Any],
       let entitlements = profile["Entitlements"] as? [String: Any],
       let value = entitlements["aps-environment"] as? String { return value }
    return Bundle.main.object(forInfoDictionaryKey: "KingclubAPNsEnvironment") as? String
  }

  func registered(_ data: Data) {
    let environment = Self.environment()
    guard environment == "development" || environment == "production" else { registrationFailed(); return }
    let callback = waiting
    waiting = nil
    timeout?.cancel()
    callback?(["provider": environment == "development" ? "apns_sandbox" : "apns",
               "token": data.map { String(format: "%02x", $0) }.joined()])
  }

  func registrationFailed() {
    let callback = waiting
    waiting = nil
    timeout?.cancel()
    callback?(FlutterError(code: "PUSH_REGISTRATION_FAILED", message: "APNs registration unavailable", details: nil))
  }

  func clickChanged() { clicks.invokeMethod("changed", arguments: nil) }

  private static func journal() throws -> URL {
    let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    var directory = root.appendingPathComponent("ChatNotificationRecovery", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var resources = URLResourceValues()
    resources.isExcludedFromBackup = true
    try directory.setResourceValues(resources)
    return directory.appendingPathComponent("pending.json")
  }
  private static func readClicks() throws -> [String] {
    let url = try journal()
    if !FileManager.default.fileExists(atPath: url.path) { return [] }
    let data = try Data(contentsOf: url)
    guard data.count <= 32768 else { return [] }
    return ((try? JSONDecoder().decode([String].self, from: data)) ?? []).filter { normalize($0) != nil }.suffix(8).map { $0 }
  }
  private static func writeClicks(_ values: [String]) throws {
    try JSONEncoder().encode(values).write(to: journal(), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }
  static func saveClick(_ raw: String) {
    guard let value = normalize(raw) else { return }
    do {
      var values = try readClicks()
      if !values.contains(value) { values.append(value) }
      try writeClicks(Array(values.suffix(8)))
    } catch { /* Never log notification contents or authentication data. */ }
  }
  private static func normalize(_ raw: String) -> String? {
    guard raw.utf8.count <= 2048, let data = raw.data(using: .utf8),
      let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      object["version"] as? Int == 1,
      let scope = object["scope"] as? String, ["direct", "group"].contains(scope),
      let kind = object["kind"] as? String, ["message", "call"].contains(kind),
      let event = object["eventId"] as? String, UUID(uuidString: event) != nil,
      let recipient = object["recipient"] as? String,
      recipient.range(of: "^[A-Za-z0-9_-]{1,64}$", options: .regularExpression) != nil,
      let target = object["target"] as? String,
      let expiry = object["expiresAt"] as? Double else { return nil }
    guard scope == "group" ? UUID(uuidString: target) != nil : target.range(of: "^[A-Za-z0-9_-]{1,64}$", options: .regularExpression) != nil else { return nil }
    let now = Date().timeIntervalSince1970 * 1000
    guard expiry > now, expiry <= now + 86400000 else { return nil }
    return raw
  }
}
