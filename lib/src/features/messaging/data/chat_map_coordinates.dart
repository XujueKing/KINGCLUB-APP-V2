import 'dart:math' as math;

/// Adapted from googollee/eviltransform (BSD-2-Clause), see
/// assets/licenses/eviltransform.txt. Only used at the Tencent GCJ02 boundary;
/// MapKit GPS and the stored WGS84 message must never be transformed twice.
class ChatMapCoordinates {
  static Map<String, dynamic> tencentArguments(
    Map<String, dynamic> coordinate,
  ) {
    if (coordinate['coordinateSystem'] == 'gcj02') return coordinate;
    final point = toTencent(
      (coordinate['latitudeE6'] as num).toDouble() / 1e6,
      (coordinate['longitudeE6'] as num).toDouble() / 1e6,
    );
    return {
      ...coordinate,
      'latitudeE6': (point.lat * 1e6).round(),
      'longitudeE6': (point.lon * 1e6).round(),
      'coordinateSystem': 'gcj02',
    };
  }

  /// The native Apple bridge chooses by the placemark's country, never by
  /// the conversion algorithm's rectangular bounds alone.
  static Map<String, dynamic> appleArguments(Map<String, dynamic> coordinate) {
    if (coordinate['coordinateSystem'] != 'wgs84') return coordinate;
    final point = toTencent(
      (coordinate['latitudeE6'] as num).toDouble() / 1e6,
      (coordinate['longitudeE6'] as num).toDouble() / 1e6,
    );
    return {
      ...coordinate,
      'alternateGCJ02': {
        'latitudeE6': (point.lat * 1e6).round(),
        'longitudeE6': (point.lon * 1e6).round(),
        'coordinateSystem': 'gcj02',
      },
    };
  }

  static bool _outside(double lat, double lon) =>
      lon < 72.004 || lon > 137.8347 || lat < .8293 || lat > 55.8271;

  static ({double lat, double lon}) toTencent(double lat, double lon) {
    if (_outside(lat, lon)) return (lat: lat, lon: lon);
    final d = _delta(lat, lon);
    return (lat: lat + d.lat, lon: lon + d.lon);
  }

  static ({double lat, double lon}) fromTencent(double lat, double lon) {
    if (_outside(lat, lon)) return (lat: lat, lon: lon);
    var wLat = lat, wLon = lon;
    for (var i = 0; i < 30; i++) {
      final mapped = toTencent(wLat, wLon);
      final dLat = mapped.lat - lat, dLon = mapped.lon - lon;
      wLat -= dLat;
      wLon -= dLon;
      if (math.max(dLat.abs(), dLon.abs()) < 1e-7) break;
    }
    return (lat: wLat, lon: wLon);
  }

  static ({double lat, double lon}) _delta(double lat, double lon) {
    final x = lon - 105, y = lat - 35;
    final xy = x * y, absX = math.sqrt(x.abs());
    final xp = x * math.pi, yp = y * math.pi;
    final common = 20 * math.sin(6 * xp) + 20 * math.sin(2 * xp);
    var dLat =
        common +
        20 * math.sin(yp) +
        40 * math.sin(yp / 3) +
        160 * math.sin(yp / 12) +
        320 * math.sin(yp / 30);
    var dLon =
        common +
        20 * math.sin(xp) +
        40 * math.sin(xp / 3) +
        150 * math.sin(xp / 12) +
        300 * math.sin(xp / 30);
    dLat =
        dLat * 2 / 3 - 100 + 2 * x + 3 * y + .2 * y * y + .1 * xy + .2 * absX;
    dLon = dLon * 2 / 3 + 300 + x + 2 * y + .1 * x * x + .1 * xy + .1 * absX;
    const earth = 6378137.0, ee = .00669342162296594323;
    final rad = lat / 180 * math.pi;
    final sin = math.sin(rad), magic = 1 - ee * sin * sin;
    final sqrt = math.sqrt(magic);
    return (
      lat: dLat * 180 / ((earth * (1 - ee)) / (magic * sqrt) * math.pi),
      lon: dLon * 180 / (earth / sqrt * math.cos(rad) * math.pi),
    );
  }
}
