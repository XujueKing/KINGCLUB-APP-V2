import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/chat_location.dart';
import 'package:kingclub/src/features/messaging/data/chat_saved_locations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final place = ChatLocation.fromJson({
    'latitudeE6': 28000000,
    'longitudeE6': 113000000,
    'coordinateSystem': 'wgs84',
    'name': '地点',
    'address': '地址',
  });
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'bookmarks persist with coordinate system and remain account scoped',
    () async {
      await ChatSavedLocations('synthetic-a').save([place]);
      expect(
        (await ChatSavedLocations('synthetic-a').read()).single.sameAs(place),
        true,
      );
      expect(await ChatSavedLocations('synthetic-b').read(), isEmpty);
      await ChatSavedLocations('synthetic-a').save([]);
      expect(await ChatSavedLocations('synthetic-a').read(), isEmpty);
    },
  );
  test('reject unauthenticated and oversized writes', () async {
    await expectLater(ChatSavedLocations('').save([place]), throwsStateError);
    await expectLater(
      ChatSavedLocations('synthetic-a').save(List.filled(201, place)),
      throwsStateError,
    );
    expect(await ChatSavedLocations('synthetic-a').read(), isEmpty);
  });
}
