import Flutter
import UIKit
import UserNotifications
import AVFAudio
import MapKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var chatPush: AppleChatPush?
  private var callLifetime: AppleCallLifetime?
  private var systemCalls: AppleSystemCalls?
  private var mapPreview: AppleChatMapPreview?
  private var chatMap: AppleChatMapNavigation?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    systemCalls = AppleSystemCalls()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    mapPreview = AppleChatMapPreview(messenger: engineBridge.applicationRegistrar.messenger())
    chatMap = AppleChatMapNavigation(messenger: engineBridge.applicationRegistrar.messenger())
    engineBridge.applicationRegistrar.register(
      AppleChatMapFactory(messenger: engineBridge.applicationRegistrar.messenger()),
      withId: "kingclub/location-map")
    chatPush = AppleChatPush(messenger: engineBridge.applicationRegistrar.messenger())
    callLifetime = AppleCallLifetime(messenger: engineBridge.applicationRegistrar.messenger())
    systemCalls?.attach(messenger: engineBridge.applicationRegistrar.messenger())
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
      AppleChatPush.clearDeliveredConversation(raw)
      chatPush?.clickChanged()
      completionHandler()
    } else {
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }
  }
}

/// Confirms background audio support and holds the screen awake for video.
private final class AppleCallLifetime {
  private let channel: FlutterMethodChannel
  private var owner: String?
  private var previousIdleTimer = false
  private var changedIdleTimer = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "kingclub/call-foreground", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String, UUID(uuidString: id) != nil else {
        result(FlutterError(code: "CALL_INVALID", message: "Invalid call owner", details: nil)); return
      }
      switch call.method {
      case "start":
        guard self.owner == nil || self.owner == id else {
          result(FlutterError(code: "CALL_BUSY", message: "Another call is active", details: nil)); return
        }
        // getUserMedia has already configured WebRTC's recording session.
        // WebRTC retains audio activation/routing ownership; do not override it.
        let category = AVAudioSession.sharedInstance().category
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        guard modes.contains("audio"), category == .playAndRecord || category == .multiRoute else {
          result(FlutterError(code: "CALL_AUDIO_UNAVAILABLE", message: "Background call audio unavailable", details: nil)); return
        }
        if self.owner == nil {
          self.previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
          self.owner = id
        }
        if args["video"] as? Bool == true {
          self.changedIdleTimer = true
          UIApplication.shared.isIdleTimerDisabled = true
        }
        result(nil)
      case "stop":
        if self.owner == id {
          if self.changedIdleTimer {
            UIApplication.shared.isIdleTimerDisabled = self.previousIdleTimer
          }
          self.changedIdleTimer = false
          self.owner = nil
        }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// No APNs signing key belongs in the application. Only the device token crosses
/// this channel; the authenticated server establishes its owner.
final class AppleChatPush {
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

  static func environment() -> String? {
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

  // Notification Center retains earlier banners after opening the latest one.
  // Clear only this recipient's message conversation; preserve other chats/calls.
  static func clearDeliveredConversation(_ raw: String) {
    guard let data = raw.data(using: .utf8),
      let clicked = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      clicked["version"] as? Int == 1, clicked["kind"] as? String == "message",
      let recipient = clicked["recipient"] as? String,
      let scope = clicked["scope"] as? String,
      let target = clicked["target"] as? String else { return }
    let center = UNUserNotificationCenter.current()
    center.getDeliveredNotifications { notifications in
      let identifiers = notifications.compactMap { notice -> String? in
        guard let stored = notice.request.content.userInfo["kingclub_push"] as? String,
          let bytes = stored.data(using: .utf8),
          let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
          value["version"] as? Int == 1, value["kind"] as? String == "message",
          value["recipient"] as? String == recipient,
          value["scope"] as? String == scope,
          value["target"] as? String == target else { return nil }
        return notice.request.identifier
      }
      center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
  }

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


private func chatCoordinate(_ args: [String: Any]) -> CLLocationCoordinate2D? {
  guard args["coordinateSystem"] as? String == "wgs84",
        let lat = args["latitudeE6"] as? NSNumber,
        let lon = args["longitudeE6"] as? NSNumber else { return nil }
  let point = CLLocationCoordinate2D(latitude: lat.doubleValue / 1e6, longitude: lon.doubleValue / 1e6)
  return CLLocationCoordinate2DIsValid(point) ? point : nil
}

private final class AppleChatMapNavigation {
  private let channel: FlutterMethodChannel
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "kingclub/chat-map", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "open", let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented); return
      }
      if let coordinate = chatCoordinate(args) {
        let place = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        place.name = args["name"] as? String
        let mode = args["mode"] as? String == "walking" ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving
        let options: [String: Any] = args["mode"] as? String == "view"
          ? [:] : [MKLaunchOptionsDirectionsModeKey: mode]
        result(place.openInMaps(launchOptions: options))
      } else if args["coordinateSystem"] as? String == "gcj02",
                let lat = args["latitudeE6"] as? NSNumber,
                let lon = args["longitudeE6"] as? NSNumber,
                abs(lat.doubleValue) <= 90e6, abs(lon.doubleValue) <= 180e6 {
        // Preserve legacy coordinates for the provider which understands them.
        var url = URLComponents(string: "https://uri.amap.com/marker")!
        url.queryItems = [URLQueryItem(name: "position", value: "\(lon.doubleValue / 1e6),\(lat.doubleValue / 1e6)"),
          URLQueryItem(name: "name", value: args["name"] as? String),
          URLQueryItem(name: "coordinate", value: "gaode"), URLQueryItem(name: "callnative", value: "1")]
        guard let target = url.url else { result(false); return }
        UIApplication.shared.open(target, options: [:]) { result($0) }
      } else { result(false) }
    }
  }
}

private final class AppleChatMapFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    AppleChatMapView(frame: frame, id: viewId, args: args as? [String: Any] ?? [:], messenger: messenger)
  }
}

private final class AppleChatMapView: NSObject, FlutterPlatformView, MKMapViewDelegate {
  private let map: MKMapView
  private let channel: FlutterMethodChannel
  private let target: CLLocationCoordinate2D?
  private var loadState = "loading"
  init(frame: CGRect, id: Int64, args: [String: Any], messenger: FlutterBinaryMessenger) {
    map = MKMapView(frame: frame)
    target = chatCoordinate(args)
    channel = FlutterMethodChannel(name: "kingclub/location-map/\(id)", binaryMessenger: messenger)
    super.init()
    map.overrideUserInterfaceStyle = .dark
    map.delegate = self
    map.isRotateEnabled = true
    map.showsCompass = true
    if let target = target {
      let pin = MKPointAnnotation(); pin.coordinate = target; pin.title = args["name"] as? String
      map.addAnnotation(pin)
      center(target)
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(false); return }
      if call.method == "status" { result(self.loadState)
      } else if call.method == "target", let target = self.target {
        self.center(target); result(true)
      } else if call.method == "locate", let args = call.arguments as? [String: Any], let point = chatCoordinate(args) {
        self.map.showsUserLocation = true
        self.center(point); result(true)
      } else { result(FlutterMethodNotImplemented) }
    }
  }
  private func center(_ point: CLLocationCoordinate2D) {
    map.setRegion(MKCoordinateRegion(center: point, latitudinalMeters: 900, longitudinalMeters: 900), animated: true)
  }
  func view() -> UIView { map }
  func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
    guard fullyRendered else { return }
    loadState = "ready"
    channel.invokeMethod("status", arguments: loadState)
  }
  func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
    loadState = "failed"
    channel.invokeMethod("status", arguments: loadState)
  }
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    if annotation is MKUserLocation { return nil }
    let pin = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "destination")
    pin.markerTintColor = UIColor(red: 0.03, green: 0.76, blue: 0.38, alpha: 1)
    pin.glyphImage = UIImage(systemName: "circle.fill")
    pin.glyphTintColor = .white
    pin.displayPriority = .required
    return pin
  }
  deinit { channel.setMethodCallHandler(nil); map.delegate = nil; map.showsUserLocation = false }
}

/// Map previews use the system map provider; no chat text is sent to it.
private final class AppleChatMapPreview {
  private let channel: FlutterMethodChannel
  private var pending: [UUID: MKMapSnapshotter] = [:]

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "kingclub/chat-map-preview", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "snapshot" else { result(FlutterMethodNotImplemented); return }
      guard let self = self,
            let args = call.arguments as? [String: Any],
            let lat = args["latitudeE6"] as? NSNumber,
            let lon = args["longitudeE6"] as? NSNumber,
            args["coordinateSystem"] as? String == "wgs84" else {
        // Do not plot legacy GCJ-02 coordinates on a WGS-84 API incorrectly.
        result(nil); return
      }
      let coordinate = CLLocationCoordinate2D(latitude: lat.doubleValue / 1_000_000,
                                             longitude: lon.doubleValue / 1_000_000)
      guard CLLocationCoordinate2DIsValid(coordinate), self.pending.count < 8 else {
        result(nil); return
      }
      let options = MKMapSnapshotter.Options()
      options.region = MKCoordinateRegion(center: coordinate,
        latitudinalMeters: 650, longitudinalMeters: 1500)
      options.size = CGSize(width: 250, height: 96)
      options.scale = 2
      options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
      let snapshotter = MKMapSnapshotter(options: options)
      let id = UUID()
      self.pending[id] = snapshotter
      snapshotter.start(with: .main) { [weak self] snapshot, _ in
        guard self?.pending.removeValue(forKey: id) != nil else { return }
        if let data = snapshot?.image.pngData() {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(nil)
        }
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
        guard let active = self?.pending.removeValue(forKey: id) else { return }
        active.cancel()
        result(nil)
      }
    }
  }
}
