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
  private var programmatic = false
  private var positioned = false

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
        self.programmatic = true
        self.positioned = true
        if args["userLocation"] as? Bool == true { self.map.showsUserLocation = true }
        self.map.setRegion(MKCoordinateRegion(center: point, latitudinalMeters: 900, longitudinalMeters: 900), animated: false)
        result(true)
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
    guard args["coordinateSystem"] as? String == "wgs84",
          let lat = args["latitudeE6"] as? NSNumber, let lon = args["longitudeE6"] as? NSNumber else { return nil }
    let point = CLLocationCoordinate2D(latitude: lat.doubleValue / 1e6, longitude: lon.doubleValue / 1e6)
    return CLLocationCoordinate2DIsValid(point) ? point : nil
  }
  private func location(_ point: CLLocationCoordinate2D, name: String, address: String) -> [String: Any] {
    ["latitudeE6": Int((point.latitude * 1e6).rounded()), "longitudeE6": Int((point.longitude * 1e6).rounded()),
     "coordinateSystem": "wgs84", "name": String(name.prefix(100)), "address": String(address.prefix(300))]
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
    let callback = pending; pending = nil
    callback?(FlutterError(code: "cancelled", message: "Location request superseded", details: nil))
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
      return location(point, name: name, address: address(item.placemark))
    }
  }
  func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
    // setRegion may produce no delegate callback when its center is unchanged.
    // An actual gesture must always release that programmatic suppression.
    if hasGesture(mapView) { programmatic = false }
    guard positioned, !programmatic else { return }
    cancel()
    channel.invokeMethod("moving", arguments: nil)
  }
  private func hasGesture(_ view: UIView) -> Bool {
    if (view.gestureRecognizers ?? []).contains(where: { $0.state == .began || $0.state == .changed }) { return true }
    return view.subviews.contains(where: { hasGesture($0) })
  }
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    if programmatic { programmatic = false; return }
    guard positioned else { return }
    channel.invokeMethod("centerChanged", arguments: location(mapView.centerCoordinate, name: "地图选点", address: ""))
  }
  func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
    if fullyRendered { channel.invokeMethod("status", arguments: "ready") }
  }
  func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
    channel.invokeMethod("status", arguments: "failed")
  }
  deinit {
    search?.cancel(); geocoder.cancelGeocode(); pending?(nil)
    channel.setMethodCallHandler(nil); map.delegate = nil; map.showsUserLocation = false
  }
}
