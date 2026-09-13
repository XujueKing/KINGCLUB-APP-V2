/// Explicit coordinate system and integer microdegrees survive persistence
/// without float-dependent message identities.
class ChatLocation {
  const ChatLocation._(
    this.latitudeE6,
    this.longitudeE6,
    this.coordinateSystem,
    this.name,
    this.address,
  );
  factory ChatLocation.fromJson(Map<String, dynamic> value) {
    const fields = {
      'latitudeE6',
      'longitudeE6',
      'coordinateSystem',
      'name',
      'address',
    };
    final lat = value['latitudeE6'],
        lon = value['longitudeE6'],
        system = value['coordinateSystem'],
        name = value['name'],
        address = value['address'] ?? '';
    if (value.keys.any((key) => !fields.contains(key)) ||
        lat is! int ||
        lat < -90000000 ||
        lat > 90000000 ||
        lon is! int ||
        lon < -180000000 ||
        lon > 180000000 ||
        (system != 'wgs84' && system != 'gcj02') ||
        name is! String ||
        name.trim().isEmpty ||
        name.trim().length > 100 ||
        address is! String ||
        address.trim().length > 300) {
      throw const FormatException('地点信息无效');
    }
    return ChatLocation._(
      lat,
      lon,
      system as String,
      name.trim(),
      address.trim(),
    );
  }

  /// Corrupt or older history must not crash the entire conversation.
  static ChatLocation? tryParse(dynamic value) {
    if (value is! Map) return null;
    try {
      return ChatLocation.fromJson(Map<String, dynamic>.from(value));
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  final int latitudeE6, longitudeE6;
  final String coordinateSystem, name, address;
  Map<String, dynamic> toJson() => {
    'latitudeE6': latitudeE6,
    'longitudeE6': longitudeE6,
    'coordinateSystem': coordinateSystem,
    'name': name,
    'address': address,
  };
  bool sameAs(ChatLocation other) =>
      latitudeE6 == other.latitudeE6 &&
      longitudeE6 == other.longitudeE6 &&
      coordinateSystem == other.coordinateSystem &&
      name == other.name &&
      address == other.address;
}
