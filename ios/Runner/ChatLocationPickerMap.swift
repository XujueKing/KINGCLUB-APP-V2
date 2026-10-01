import Flutter
import MapKit

/// The picker owns a separate light map; conversation detail maps keep their style.
final class ChatLocationPickerMapFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments: Any?) -> FlutterPlatformView {
    ChatLocationPickerMap(frame: frame, id: id, messenger: messenger)
  }
}

private final class ChatLocationPickerMap: NSObject, FlutterPlatformView, MKMapViewDelegate {
  private let map: MKMapView
  private let channel: FlutterMethodChannel
  private let geocoder = CLGeocoder()
  private var search: MKLocalSearch?
  private var pending: FlutterResult?
  private var revision = 0
  private var userRegionChange = false
  private var positioned = false
  private var locating = false
  private var settlingLocation = false
  private var locationStarted = Date.distantPast
  private var bestLocation: CLLocation?
  private var bestDisplayCoordinate: CLLocationCoordinate2D?
  private var locationTimer: DispatchWorkItem?
  private var selectionCoordinate: CLLocationCoordinate2D?
  private var lastAnchor: CGPoint?
  private var mapCoordinateSystem = "wgs84"
  private var countryOrigin: CLLocation?

  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger) {
    map = MKMapView(frame: frame)
    channel = FlutterMethodChannel(name: "kingclub/location-picker-map/\(id)", binaryMessenger: messenger)
    super.init()
    map.overrideUserInterfaceStyle = .light
    map.delegate = self
    map.isRotateEnabled = false
    map.isPitchEnabled = false
    map.showsCompass = false
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      if call.method == "cancel" {
        self.cancel(); result(true); return
      }
      guard let args = call.arguments as? [String: Any] else { result(FlutterMethodNotImplemented); return }
      if call.method == "center", let point = self.coordinate(args) {
        self.center(point, args: args, result: result)
      } else if call.method == "locate" {
        self.locate(result)
      } else if call.method == "nearby", let point = self.coordinate(args) {
        self.nearby(point, name: args["name"] as? String ?? "地图选点", result: result)
      } else if call.method == "search", let query = args["query"] as? String,
                !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, query.count <= 100 {
        self.find(query, result: result)
      } else { result(FlutterMethodNotImplemented) }
    }
  }

  func view() -> UIView { map }
  private func coordinate(_ args: [String: Any]) -> CLLocationCoordinate2D? {
    guard let system = args["coordinateSystem"] as? String, ["wgs84", "gcj02"].contains(system),
          let lat = args["latitudeE6"] as? NSNumber, let lon = args["longitudeE6"] as? NSNumber else { return nil }
    let point = CLLocationCoordinate2D(latitude: lat.doubleValue / 1e6, longitude: lon.doubleValue / 1e6)
    return CLLocationCoordinate2DIsValid(point) ? point : nil
  }
  private func location(_ point: CLLocationCoordinate2D, name: String, address: String, system: String? = nil) -> [String: Any] {
    ["latitudeE6": Int((point.latitude * 1e6).rounded()), "longitudeE6": Int((point.longitude * 1e6).rounded()),
     "coordinateSystem": system ?? mapCoordinateSystem, "name": String(name.prefix(100)), "address": String(address.prefix(300))]
  }
  private func center(_ point: CLLocationCoordinate2D, args: [String: Any], result: @escaping FlutterResult) {
    let requestRevision = start(result)
    let original = CLLocation(latitude: point.latitude, longitude: point.longitude)
    let apply: () -> Void = { [weak self] in
      guard let self = self, self.revision == requestRevision else { return }
      var display = point
      if self.mapCoordinateSystem == "gcj02", args["coordinateSystem"] as? String == "wgs84" {
        guard let alternate = args["alternateGCJ02"] as? [String: Any], let converted = self.coordinate(alternate) else {
          self.finish(FlutterError(code: "coordinate", message: "缺少地图显示坐标，请重试", details: nil), revision: requestRevision); return
        }
        display = converted
      }
      self.userRegionChange = false
      self.map.setUserTrackingMode(.none, animated: false)
      self.selectionCoordinate = display
      self.positioned = true
      if args["userLocation"] as? Bool == true { self.map.showsUserLocation = true }
      self.map.setRegion(MKCoordinateRegion(center: display, latitudinalMeters: 900, longitudinalMeters: 900), animated: false)
      self.updateAnchor()
      self.finish(self.mapCoordinateSystem, revision: requestRevision)
    }
    if let origin = countryOrigin, original.distance(from: origin) < 50000 { apply(); return }
    // Resolve the country, rather than treating the transform's rectangular
    // bounds (which also contain Thailand and Taiwan) as mainland China.
    geocoder.reverseGeocodeLocation(original) { [weak self] places, _ in
      guard let self = self, self.revision == requestRevision else { return }
      guard let country = places?.first?.isoCountryCode else {
        self.finish(FlutterError(code: "coordinate", message: "暂时无法识别地图区域，请重试", details: nil), revision: requestRevision); return
      }
      self.mapCoordinateSystem = country == "CN" ? "gcj02" : "wgs84"
      self.countryOrigin = original
      apply()
    }
  }
  private func address(_ place: CLPlacemark?) -> String {
    guard let place = place else { return "" }
    var seen = Set<String>()
    return [place.administrativeArea, place.locality, place.subLocality, place.thoroughfare, place.subThoroughfare]
      .compactMap { $0 }.filter { !$0.isEmpty && seen.insert($0).inserted }.joined(separator: " ")
  }
  private func cancel() {
    revision += 1
    search?.cancel(); search = nil; geocoder.cancelGeocode()
    locating = false; settlingLocation = false; bestLocation = nil; bestDisplayCoordinate = nil
    locationTimer?.cancel(); locationTimer = nil
    let callback = pending; pending = nil
    callback?(FlutterError(code: "cancelled", message: "Location request superseded", details: nil))
  }
  private func locate(_ result: @escaping FlutterResult) {
    let requestRevision = start(result)
    locating = true; userRegionChange = false; locationStarted = Date()
    map.showsUserLocation = true
    // MapKit's own camera and blue dot share one coordinate pipeline.
    map.setUserTrackingMode(.follow, animated: false)
    if let existing = map.userLocation.location { accept(existing, revision: requestRevision) }
    guard locating else { return }
    let timeout = DispatchWorkItem { [weak self] in
      guard let self = self, self.locating, self.revision == requestRevision else { return }
      if let location = self.bestLocation, self.usable(location) { self.completeLocation(location, revision: requestRevision) }
      else {
        self.locating = false
        self.finish(FlutterError(code: "location", message: "地图定位精度不足，请移至窗边或室外后重试", details: nil), revision: requestRevision)
      }
    }
    locationTimer = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
  }
  private func usable(_ point: CLLocation) -> Bool {
    let age = Date().timeIntervalSince(point.timestamp)
    guard CLLocationCoordinate2DIsValid(point.coordinate), point.horizontalAccuracy > 0,
          point.horizontalAccuracy <= 100, age >= -5, age <= 30,
          point.timestamp >= locationStarted.addingTimeInterval(-2) else { return false }
    if #available(iOS 15.0, *), point.sourceInformation?.isSimulatedBySoftware == true { return false }
    return true
  }
  private func accept(_ point: CLLocation, revision: Int) {
    guard locating, revision == self.revision, usable(point) else { return }
    if bestLocation == nil || point.horizontalAccuracy <= bestLocation!.horizontalAccuracy {
      bestLocation = point
      bestDisplayCoordinate = map.userLocation.coordinate
    }
    if point.horizontalAccuracy <= 50, !settlingLocation { completeLocation(point, revision: revision) }
  }
  private func completeLocation(_ point: CLLocation, revision: Int) {
    guard locating, !settlingLocation else { return }
    settlingLocation = true
    locationTimer?.cancel(); locationTimer = nil
    positioned = true
    map.setUserTrackingMode(.follow, animated: false)
    // Let MapKit settle its own camera before freezing a sendable selection.
    // Continuing to follow after returning would move the green marker while
    // the selected message coordinate stayed at an earlier fix.
    let snapshot = DispatchWorkItem { [weak self] in
      guard let self = self, self.locating, self.revision == revision else { return }
      let live = self.bestLocation ?? self.map.userLocation.location ?? point
      guard self.usable(live) else {
        self.locating = false; self.settlingLocation = false
        self.finish(FlutterError(code: "location", message: "地图位置已失效，请重新定位", details: nil), revision: revision)
        return
      }
      // MKUserLocation's annotation coordinate is the blue dot's actual map
      // coordinate. Do not substitute an independent CoreLocation raw fix.
      let selected = self.bestDisplayCoordinate ?? self.map.userLocation.coordinate
      self.map.setUserTrackingMode(.none, animated: false)
      self.map.setRegion(MKCoordinateRegion(center: selected, latitudinalMeters: 900, longitudinalMeters: 900), animated: false)
      self.selectionCoordinate = selected
      self.updateAnchor()
      self.locating = false; self.settlingLocation = false; self.locationTimer = nil
      self.geocoder.reverseGeocodeLocation(live) { [weak self] places, _ in
        guard let self = self, self.revision == revision else { return }
        guard let country = places?.first?.isoCountryCode else {
          self.finish(FlutterError(code: "coordinate", message: "暂时无法识别地图区域，请重新定位", details: nil), revision: revision); return
        }
        self.mapCoordinateSystem = country == "CN" ? "gcj02" : "wgs84"
        self.countryOrigin = live
        self.finish(["location": self.location(selected, name: "当前位置", address: ""),
                     "accuracyMeters": live.horizontalAccuracy], revision: revision)
      }
    }
    locationTimer = snapshot
    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: snapshot)
  }
  func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
    if let point = userLocation.location { accept(point, revision: revision) }
  }
  func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
    guard locating else { return }
    locating = false; locationTimer?.cancel(); locationTimer = nil
    finish(FlutterError(code: "location", message: "无法获取系统地图位置，请检查定位权限后重试", details: nil), revision: revision)
  }
  private func start(_ result: @escaping FlutterResult) -> Int {
    cancel(); pending = result; return revision
  }
  private func finish(_ value: Any?, revision: Int) {
    guard revision == self.revision, let callback = pending else { return }
    pending = nil; search = nil; callback(value)
  }
  private func nearby(_ point: CLLocationCoordinate2D, name: String, result: @escaping FlutterResult) {
    let requestRevision = start(result)
    selectionCoordinate = point
    updateAnchor()
    geocoder.reverseGeocodeLocation(CLLocation(latitude: point.latitude, longitude: point.longitude), preferredLocale: Locale(identifier: "zh_CN")) { [weak self] places, _ in
      guard let self = self, requestRevision == self.revision else { return }
      let selected = self.location(point, name: name, address: self.address(places?.first))
      let request = MKLocalPointsOfInterestRequest(center: point, radius: 1200)
      let search = MKLocalSearch(request: request); self.search = search
      search.start { [weak self] response, _ in
        guard let self = self, requestRevision == self.revision else { return }
        // A POI is a separate explicit choice, never a renamed GPS position.
        let items = (response?.mapItems ?? []).sorted {
          CLLocation(latitude: $0.placemark.coordinate.latitude, longitude: $0.placemark.coordinate.longitude)
            .distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude)) <
          CLLocation(latitude: $1.placemark.coordinate.latitude, longitude: $1.placemark.coordinate.longitude)
            .distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
        }
        self.finish([selected] + self.serialize(items), revision: requestRevision)
      }
    }
  }
  private func find(_ query: String, result: @escaping FlutterResult) {
    let requestRevision = start(result)
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    if positioned { request.region = map.region }
    request.resultTypes = [.address, .pointOfInterest]
    let search = MKLocalSearch(request: request); self.search = search
    search.start { [weak self] response, error in
      guard let self = self, requestRevision == self.revision else { return }
      if error != nil { self.finish(FlutterError(code: "search", message: "Place search unavailable", details: nil), revision: requestRevision) }
      else { self.finish(self.serialize(response?.mapItems ?? []), revision: requestRevision) }
    }
  }
  private func serialize(_ items: [MKMapItem]) -> [[String: Any]] {
    var seen = Set<String>()
    return items.prefix(30).compactMap { item in
      let point = item.placemark.coordinate
      guard CLLocationCoordinate2DIsValid(point), let name = item.name, !name.isEmpty else { return nil }
      let key = "\(Int(point.latitude * 1e6)):\(Int(point.longitude * 1e6)):\(name)"
      guard seen.insert(key).inserted else { return nil }
      let country = item.placemark.isoCountryCode
      return location(point, name: name, address: address(item.placemark),
                      system: country.map { $0 == "CN" ? "gcj02" : "wgs84" })
    }
  }
  func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
    // Only a user gesture starts a new manual choice. Camera following and
    // tile loading must not cancel an in-flight fix or clear its selection.
    beginManualMovement(mapView)
  }
  private func beginManualMovement(_ mapView: MKMapView) {
    guard !userRegionChange, hasGesture(mapView) else { return }
    userRegionChange = true
    map.setUserTrackingMode(.none, animated: false)
    positioned = true
    cancel()
    channel.invokeMethod("moving", arguments: nil)
  }
  private func hasGesture(_ view: UIView) -> Bool {
    if (view.gestureRecognizers ?? []).contains(where: {
      guard ($0.state == .began || $0.state == .changed), $0.numberOfTouches > 0 else { return false }
      if let pan = $0 as? UIPanGestureRecognizer {
        let movement = pan.translation(in: map)
        return hypot(movement.x, movement.y) >= 6
      }
      if let pinch = $0 as? UIPinchGestureRecognizer { return abs(pinch.scale - 1) >= 0.02 }
      return false
    }) { return true }
    return view.subviews.contains(where: { hasGesture($0) })
  }
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    guard positioned, userRegionChange else { return }
    userRegionChange = false
    selectionCoordinate = mapView.centerCoordinate
    updateAnchor()
    channel.invokeMethod("centerChanged", arguments: location(mapView.centerCoordinate, name: "地图选点", address: ""))
  }
  func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
    beginManualMovement(mapView)
    if userRegionChange { selectionCoordinate = mapView.centerCoordinate }
    updateAnchor()
  }
  private func updateAnchor() {
    guard let selected = selectionCoordinate, map.bounds.width > 0, map.bounds.height > 0 else { return }
    let point = map.convert(selected, toPointTo: map)
    guard point.x.isFinite, point.y.isFinite else { return }
    if let last = lastAnchor, abs(last.x - point.x) < 0.5, abs(last.y - point.y) < 0.5 { return }
    lastAnchor = point
    // MapKit may inset its visible center around safe areas. Use the map's
    // actual projection rather than assuming Flutter's box center is the pin.
    channel.invokeMethod("selectionAnchor", arguments: ["x": point.x, "y": point.y])
  }
  func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
    if fullyRendered && positioned { updateAnchor(); channel.invokeMethod("status", arguments: "ready") }
  }
  func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
    channel.invokeMethod("status", arguments: "failed")
  }
  deinit {
    locationTimer?.cancel()
    search?.cancel(); geocoder.cancelGeocode(); pending?(nil)
    channel.setMethodCallHandler(nil); map.delegate = nil; map.showsUserLocation = false
  }
}
