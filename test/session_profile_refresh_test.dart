import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/core/session/member_qr_memory.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_draft_store.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final initial = <String, dynamic>{
    'sessionId': 'session-a',
    'apiKeyId': 'key-a',
    'apiKey': 'secret-a',
    'account': {'userAccount': 'member-a', 'accountStatus': 'active'},
    'membership': {'status': 'active', 'registrationStatus': 'approved'},
  };
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'gallery return profile refresh preserves pending media draft binding',
    () async {
      final store = SecureSessionStore();
      await store.saveSession(initial);
      await Future<void>.delayed(Duration.zero);
      final draft = await ChatFileDraftStore.open(
        'member-a',
        'video-peer:friend',
      );
      final generation = MemberQrMemory.generation;
      final presentation = MemberQrMemory.presentationGeneration;
      var changes = 0;
      final subscription = SecureSessionStore.changes.stream.listen(
        (_) => changes++,
      );
      addTearDown(subscription.cancel);
      MemberQrMemory.profile = {'nickname': 'old'};
      await store.saveSession({
        ...initial,
        'account': {...initial['account'] as Map, 'nickname': 'updated'},
      });
      await Future<void>.delayed(Duration.zero);
      await draft.checkSession();
      expect(MemberQrMemory.generation, generation);
      expect(MemberQrMemory.presentationGeneration, greaterThan(presentation));
      expect(MemberQrMemory.profile, isNull);
      expect(changes, 0);
      expect((await store.readSession())!['account']['nickname'], 'updated');
    },
  );
  for (final patch in <Map<String, dynamic>>[
    {'sessionId': 'session-b'},
    {'apiKeyId': 'key-b'},
    {'apiKey': 'secret-b'},
    {
      'account': {'userAccount': 'member-b', 'accountStatus': 'active'},
    },
    {
      'account': {'userAccount': 'member-a', 'accountStatus': 'disabled'},
    },
    {
      'membership': {'status': 'suspended', 'registrationStatus': 'approved'},
    },
  ]) {
    test(
      'credential/access change invalidates draft: ${patch.keys.first} $patch',
      () async {
        final store = SecureSessionStore();
        await store.saveSession(initial);
        await Future<void>.delayed(Duration.zero);
        final draft = await ChatFileDraftStore.open(
          'member-a',
          'video-peer:friend',
        );
        var changes = 0;
        final subscription = SecureSessionStore.changes.stream.listen(
          (_) => changes++,
        );
        addTearDown(subscription.cancel);
        await store.saveSession({...initial, ...patch});
        await Future<void>.delayed(Duration.zero);
        await expectLater(draft.checkSession(), throwsA(isA<AuthFailure>()));
        expect(changes, 1);
      },
    );
  }
}
