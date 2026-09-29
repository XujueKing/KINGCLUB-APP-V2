import Flutter
import UIKit
import PushKit
import CallKit
import AVFAudio
import WebRTC
import Security
import CoreImage

/// Native incoming-call boundary. Registration is explicit: the Flutter runtime
/// must first support authenticated answer/end handling before calling bind.
final class AppleSystemCalls: NSObject, PKPushRegistryDelegate, CXProviderDelegate {
  private let provider: CXProvider
  private var registry: PKPushRegistry?
  private var channel: FlutterMethodChannel?
  private var account: String?
  private var token: String?
  private var calls: [UUID: [String: Any]] = [:]
  private var timers: [UUID: Timer] = [:]
  private var actions: [UUID: CXCallAction] = [:]
  private var answered: Set<UUID> = []
  private var ownsAudio = false
  private var audioActive = false
  private var previousManualAudio = false
  private var events: [[String: Any]] = []

  override init() {
    let configuration = CXProviderConfiguration(localizedName: "KINGCLUB")
    configuration.supportsVideo = true
    configuration.supportedHandleTypes = [.generic]
    configuration.maximumCallGroups = 1
    configuration.maximumCallsPerCallGroup = 1
    configuration.includesCallsInRecents = false
    configuration.iconTemplateImageData = Self.brandTemplate()
    // Use the system ringtone/haptics until the branded resource is supplied.
    provider = CXProvider(configuration: configuration)
    super.init()
    provider.setDelegate(self, queue: .main)
    account = UserDefaults.standard.string(forKey: "kingclub.voip.account")
    if account != nil { register() }
  }

  private static func brandTemplate() -> Data? {
    // CallKit consumes an alpha template, not the opaque black app-icon square.
    // Reuse the exact bundled KING artwork and convert luminance to alpha.
    guard let artwork = UIImage(named: "CallKitBrand"), let input = CIImage(image: artwork),
      let mask = CIFilter(name: "CIMaskToAlpha", parameters: [kCIInputImageKey: input])?.outputImage,
      let cg = CIContext().createCGImage(mask, from: input.extent) else { return nil }
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    format.scale = 3
    return UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40), format: format)
      .image { _ in UIImage(cgImage: cg).draw(in: CGRect(x: 0, y: 0, width: 40, height: 40)) }.pngData()
  }

  func attach(messenger: FlutterBinaryMessenger) {
    let bridge = FlutterMethodChannel(name: "kingclub/system-calls", binaryMessenger: messenger)
    channel = bridge
    bridge.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      self.handle(call, result: result)
    }
  }

  private func register() {
    if registry == nil {
      registry = PKPushRegistry(queue: .main)
      registry?.delegate = self
    }
    registry?.desiredPushTypes = [.voIP]
  }

  private func emit(_ event: [String: Any]) {
    events.append(event)
    while events.count > 64, let index = events.firstIndex(where: { $0["actionId"] == nil }) {
      events.remove(at: index)
    }
    // One active call and action deadlines bound this queue; never discard an
    // unanswered system action merely because Flutter is still starting.
    channel?.invokeMethod("changed", arguments: nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "prepareCredentials":
      // Change only the existing login item's protection class, in place.
      // No delete/recreate window, no credential value crosses this channel.
      var updated = false
      for key in ["kingclub.auth.session", "kingclub.device.id"] {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
          kSecAttrService: "flutter_secure_storage_service",
          kSecAttrAccount: key, kSecAttrSynchronizable: false]
        let status = SecItemUpdate(query as CFDictionary,
          [kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] as CFDictionary)
        if status == errSecSuccess { updated = true }
        else if status != errSecItemNotFound {
          result(FlutterError(code: "CALL_CREDENTIALS_UNAVAILABLE", message: nil, details: nil)); return
        }
      }
      if updated { result(true) }
      else { result(FlutterError(code: "CALL_CREDENTIALS_UNAVAILABLE", message: nil, details: nil)) }
    case "bind":
      guard let owner = args["account"] as? String,
        owner.range(of: "^[A-Za-z0-9_-]{1,64}$", options: .regularExpression) != nil else {
        result(FlutterError(code: "CALL_ACCOUNT_INVALID", message: nil, details: nil)); return
      }
      if account != owner { reset() }
      account = owner
      UserDefaults.standard.set(owner, forKey: "kingclub.voip.account")
      register()
      result(nil)
    case "unbind":
      reset()
      account = nil
      token = nil
      registry?.desiredPushTypes = []
      UserDefaults.standard.removeObject(forKey: "kingclub.voip.account")
      result(nil)
    case "token": result(token)
    case "registration":
      let environment = AppleChatPush.environment()
      guard let token = token, environment == "development" || environment == "production" else {
        result(nil); return
      }
      result(["token": token, "provider": environment == "development" ? "apns_voip_sandbox" : "apns_voip"])
    case "answer":
      guard let raw = args["callId"] as? String, let id = UUID(uuidString: raw), calls[id] != nil else {
        result(false); return
      }
      CXCallController().request(CXTransaction(action: CXAnswerCallAction(call: id))) { error in
        if error != nil { result(FlutterError(code: "CALL_ANSWER_FAILED", message: nil, details: nil)) }
        else { result(true) }
      }
    case "pending": result(events)
    case "ack":
      guard let id = args["eventId"] as? String else { result(false); return }
      events.removeAll { $0["eventId"] as? String == id }
      result(true)
    case "completeAction":
      guard let raw = args["actionId"] as? String, let id = UUID(uuidString: raw),
        let action = actions.removeValue(forKey: id) else { result(false); return }
      events.removeAll { $0["actionId"] as? String == raw }
      if args["success"] as? Bool == true {
        action.fulfill()
        if action is CXEndCallAction { forget(action.callUUID) }
      } else {
        action.fail()
        finish(action.callUUID, reason: .failed)
      }
      result(true)
    case "end":
      guard let raw = args["callId"] as? String, let id = UUID(uuidString: raw) else {
        result(false); return
      }
      finish(id, reason: args["failed"] as? Bool == true ? .failed : .remoteEnded)
      result(true)
    default: result(FlutterMethodNotImplemented)
    }
  }

  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    guard type == .voIP else { return }
    let updated = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    guard token != updated else { return }
    token = updated
    channel?.invokeMethod("tokenChanged", arguments: nil)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    token = nil
    channel?.invokeMethod("tokenChanged", arguments: nil)
  }

  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType, completion: @escaping () -> Void) {
    guard type == .voIP else { completion(); return }
    let input = payload.dictionaryPayload["kingclub_call"] as? [String: Any] ?? [:]
    let id = (input["callId"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
    let deadline = (input["expiresAt"] as? NSNumber)?.doubleValue ?? 0
    let now = Date().timeIntervalSince1970 * 1000
    let valid = input["version"] as? Int == 1 && input["recipient"] as? String == account && account != nil
      && ["direct", "group"].contains(input["scope"] as? String ?? "")
      && input["video"] is Bool && input["callId"] as? String != nil
      && UUID(uuidString: input["callId"] as? String ?? "") != nil
      && deadline > now && deadline - now <= 300_000
    let duplicate = calls[id] != nil
    let busy = !calls.isEmpty && !duplicate
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: "KINGCLUB")
    update.localizedCallerName = "KINGCLUB"
    update.hasVideo = input["video"] as? Bool ?? false
    update.supportsHolding = false
    update.supportsGrouping = false
    update.supportsUngrouping = false
    update.supportsDTMF = false
    // Always report before network/Flutter work, including malformed/stale pushes.
    if valid && !busy && !duplicate { calls[id] = input }
    provider.reportNewIncomingCall(with: id, update: update) { [weak self] error in
      defer { completion() }
      guard let self = self else { return }
      if duplicate { return }
      guard error == nil, valid, !busy,
        self.calls[id] != nil, self.account == input["recipient"] as? String else {
        if error == nil { self.provider.reportCall(with: id, endedAt: Date(), reason: .failed) }
        self.forget(id)
        return
      }
      if !self.answered.contains(id) {
        self.timers[id] = Timer.scheduledTimer(withTimeInterval: max(0.1, (deadline-now)/1000), repeats: false) { [weak self] _ in
          self?.finish(id, reason: .unanswered)
        }
      }
      self.emit(["eventId": UUID().uuidString, "kind": "incoming", "callId": id.uuidString,
        "account": self.account ?? "", "scope": input["scope"] ?? "direct"])
    }
  }

  private func action(_ action: CXCallAction, kind: String) {
    guard let input = calls[action.callUUID] else { action.fail(); return }
    actions[action.uuid] = action
    emit(["eventId": action.uuid.uuidString, "actionId": action.uuid.uuidString,
      "kind": kind, "callId": action.callUUID.uuidString, "account": input["recipient"] ?? "",
      "scope": input["scope"] ?? "direct"])
  }

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    guard calls[action.callUUID] != nil else { action.fail(); return }
    do {
      // Configure, but let CallKit activate. Opening WebRTC tracks alone must
      // not seize the microphone before the system answer action is fulfilled.
      let rtc = RTCAudioSession.sharedInstance()
      rtc.lockForConfiguration()
      defer { rtc.unlockForConfiguration() }
      let video = calls[action.callUUID]?["video"] as? Bool ?? false
      try rtc.setCategory(AVAudioSession.Category.playAndRecord,
        with: video ? [.allowBluetooth, .defaultToSpeaker] : [.allowBluetooth])
      try rtc.setMode(video ? AVAudioSession.Mode.videoChat : AVAudioSession.Mode.voiceChat)
      previousManualAudio = rtc.useManualAudio
      rtc.useManualAudio = true
      rtc.isAudioEnabled = false
      ownsAudio = true
    } catch {
      action.fail()
      finish(action.callUUID, reason: .failed)
      return
    }
    answered.insert(action.callUUID)
    timers.removeValue(forKey: action.callUUID)?.invalidate()
    self.action(action, kind: "answer")
    // Flutter must acknowledge authenticated connection success, not just a tap.
  }
  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    timers.removeValue(forKey: action.callUUID)?.invalidate()
    self.action(action, kind: "end")
  }
  func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
    guard let call = actions.removeValue(forKey: action.uuid) else { return }
    action.fail()
    finish(call.callUUID, reason: .failed)
  }
  func providerDidReset(_ provider: CXProvider) {
    for id in Array(calls.keys) { finish(id, reason: .failed) }
  }
  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    if ownsAudio && !audioActive {
      audioActive = true
      RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
      RTCAudioSession.sharedInstance().isAudioEnabled = true
    }
    channel?.invokeMethod("audioActivated", arguments: nil)
  }
  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    if ownsAudio && audioActive {
      audioActive = false
      RTCAudioSession.sharedInstance().isAudioEnabled = false
      RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
    }
    channel?.invokeMethod("audioDeactivated", arguments: nil)
  }

  private func finish(_ id: UUID, reason: CXCallEndedReason) {
    guard let input = calls[id] else { return }
    provider.reportCall(with: id, endedAt: Date(), reason: reason)
    forget(id)
    emit(["eventId": UUID().uuidString, "kind": "ended", "callId": id.uuidString,
      "account": input["recipient"] ?? "", "scope": input["scope"] ?? "direct"])
  }
  private func forget(_ id: UUID) {
    answered.remove(id)
    calls.removeValue(forKey: id)
    if calls.isEmpty && ownsAudio {
      let rtc = RTCAudioSession.sharedInstance()
      rtc.isAudioEnabled = false
      if audioActive {
        rtc.audioSessionDidDeactivate(AVAudioSession.sharedInstance())
        audioActive = false
      }
      rtc.useManualAudio = previousManualAudio
      ownsAudio = false
    }
    timers.removeValue(forKey: id)?.invalidate()
    for key in Array(actions.keys) where actions[key]?.callUUID == id {
      actions.removeValue(forKey: key)?.fail()
    }
    events.removeAll { $0["callId"] as? String == id.uuidString }
  }
  private func reset() {
    for id in Array(calls.keys) { finish(id, reason: .failed) }
    events.removeAll()
  }
}
