import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/data/profile_cover_store.dart';
import 'package:kingclub/src/features/profile_settings/presentation/edit_profile_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';

class _FakeCoverStore implements ProfileCoverStore {
  _FakeCoverStore({this.saved});

  String? saved;
  String? persistedSource;

  @override
  Future<String?> load() async => saved;

  @override
  Future<String> persist(String sourcePath) async {
    persistedSource = sourcePath;
    saved = 'assets/legacy/home/mock_poster_music.png';
    return saved!;
  }
}

void main() {
  Widget subject({
    required ProfileCoverStore store,
    Future<EditableProfileResult?> Function(String, String, String)? onEdit,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(393, 852)),
        child: Scaffold(
          body: MyProfilePage(coverStore: store, onOpenEditProfile: onEdit),
        ),
      ),
    );
  }

  testWidgets('我的主页启动时加载已保存封面', (tester) async {
    final store = _FakeCoverStore(
      saved: 'assets/legacy/home/mock_poster_music.png',
    );
    await tester.pumpWidget(subject(store: store));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('my-profile-cover')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (image.image as AssetImage).assetName,
      'assets/legacy/home/mock_poster_music.png',
    );
  });

  testWidgets('编辑保存后先持久化裁剪封面再刷新主页', (tester) async {
    final store = _FakeCoverStore();
    await tester.pumpWidget(
      subject(
        store: store,
        onEdit: (_, _, _) async => const EditableProfileResult(
          nickname: '杨嘉琪',
          signature: '',
          coverAsset: 'temporary-adjusted-cover.png',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('my-profile-edit')));
    await tester.tap(find.byKey(const ValueKey('my-profile-edit')));
    await tester.pumpAndSettle();

    expect(store.persistedSource, 'temporary-adjusted-cover.png');
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('my-profile-cover')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (image.image as AssetImage).assetName,
      'assets/legacy/home/mock_poster_music.png',
    );
  });
}
