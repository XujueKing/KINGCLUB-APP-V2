import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_location.dart';

void main() {
  final value = <String, dynamic>{
    'latitudeE6': 28000000,
    'longitudeE6': 113000000,
    'coordinateSystem': 'wgs84',
    'name': ' Place ',
    'address': '',
  };
  test(
    'location validates coordinate precision and never accepts a supplied link',
    () {
      final location = ChatLocation.fromJson(value);
      expect(location.name, 'Place');
      for (final invalid in [
        {...value, 'latitudeE6': 90000001},
        {...value, 'longitudeE6': 180000001},
        {...value, 'latitudeE6': 28.1},
        {...value, 'coordinateSystem': 'unknown'},
        {...value, 'url': 'https://untrusted.invalid'},
        {...value, 'name': ' '},
      ]) {
        expect(() => ChatLocation.fromJson(invalid), throwsFormatException);
      }
    },
  );
  test(
    'serialized location cannot mutate its queued source and systems differ',
    () {
      final location = ChatLocation.fromJson(value),
          copy = ChatLocation.fromJson(value);
      location.toJson()['name'] = 'Changed';
      expect(location.name, 'Place');
      expect(location.sameAs(copy), true);
      expect(
        location.sameAs(
          ChatLocation.fromJson({...value, 'coordinateSystem': 'gcj02'}),
        ),
        false,
      );
    },
  );
}
