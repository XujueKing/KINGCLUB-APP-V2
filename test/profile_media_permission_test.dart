import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/cached_media_image.dart';
import 'package:kingclub/src/features/auth/data/auth_repository_provider.dart';
import 'package:kingclub/src/features/contacts/presentation/profile_media_page.dart';

void main() {
  // Run with --dart-define=KINGCLUB_API_BASE_URL=https://example.invalid.
  // Without an API URL the page deliberately hides all media, which cannot
  // establish that the permission guard works.
  final skip = kingclubApiBaseUrl.isEmpty;

  Widget page(ValueNotifier<int> visibility, int version) => MaterialApp(
    home: ProfileMediaPage(
      media: const {'path': '/kingclub/profile-media/test', 'fileId': 'test'},
      contentType: 'image/png',
      account: 'viewer',
      owner: 'owner',
      visibility: visibility,
      visibilityVersion: version,
    ),
  );

  testWidgets(
    'permission revoked before route build cannot mount cached media',
    (tester) async {
      final visibility = ValueNotifier<int>(0);
      final clickedVersion = visibility.value;
      visibility.value++;
      await tester.pumpWidget(page(visibility, clickedVersion));
      expect(find.byType(CachedMediaImage), findsNothing);
      expect(find.text('内容暂不可查看'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      visibility.dispose();
    },
    skip: skip,
  );

  testWidgets('open media is removed and old route never regains access', (
    tester,
  ) async {
    final visibility = ValueNotifier<int>(0);
    await tester.pumpWidget(page(visibility, 0));
    expect(find.byType(CachedMediaImage), findsOneWidget);
    visibility.value++;
    await tester.pump();
    expect(find.byType(CachedMediaImage), findsNothing);
    expect(find.text('内容暂不可查看'), findsOneWidget);
    visibility.value++;
    await tester.pump();
    expect(find.byType(CachedMediaImage), findsNothing);
    await tester.pumpWidget(const SizedBox());
    visibility.dispose();
  }, skip: skip);
}
