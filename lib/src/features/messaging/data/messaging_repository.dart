import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';

typedef ChatApiCall = Future<Map<String, dynamic>> Function(
  String interfaceId,
  Map<String, dynamic> params,
);

/// All requests are bound to the account which opened this repository.
class MessagingRepository {
  MessagingRepository({required this.account, required this.call});

  final String account;
  final ChatApiCall call;

  static Future<MessagingRepository> open() async {
    final store = SecureSessionStore();
    final session = await store.readSession();
    final account = (session?['account'] as Map?)?['userAccount'];
    if (session == null || account is! String || account.isEmpty) {
      throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    }
    final client = KingclubSecureClient(kingclubApiBaseUrl);
    return MessagingRepository(
      account: account,
      call: (id, params) async {
        final generation = MemberQrMemory.generation;
        final current = await store.readSession();
        if (current == null ||
            (current['account'] as Map?)?['userAccount'] != account ||
            current['sessionId'] != session['sessionId']) {
          throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
        }
        final data = await client.call(id, params, session: current);
        if (generation != MemberQrMemory.generation) {
          throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
        }
        return Map<String, dynamic>.from(data['result'] as Map);
      },
    );
  }

  Future<Map<String, dynamic>> sendText({
    required String peer,
    required String clientMessageId,
    required String text,
  }) => call('K260913000601', {
    'recipient': peer,
    'clientMessageId': clientMessageId,
    'text': text,
  });
  Future<Map<String, dynamic>> sendImage({
    required String peer,
    required String clientMessageId,
    required String assetId,
  }) => call('K260913000632', {
    'recipient': peer,
    'clientMessageId': clientMessageId,
    'assetId': assetId,
  });
  Future<Map<String, dynamic>> imageMedia(
    String messageId, {
    bool group = false,
  }) =>
      call(group ? 'K260913000635' : 'K260913000633', {'messageId': messageId});

  Future<Map<String, dynamic>> setRelationship(String peer, String action) =>
      call('K260913000602', {'peer': peer, 'action': action});
  Future<Map<String, dynamic>> permission(String peer) =>
      call('K260913000603', {'peer': peer});
  Future<Map<String, dynamic>> history(
    String peer, {
    int? before,
    int? after,
    int limit = 50,
  }) {
    if (before != null && after != null) {
      throw ArgumentError('Choose one history direction');
    }
    return call('K260913000604', {
      'peer': peer,
      'before': ?before,
      'after': ?after,
      'limit': limit,
    });
  }

  Future<Map<String, dynamic>> markRead(String peer, int sequence) =>
      call('K260913000605', {'peer': peer, 'sequence': sequence});
  Future<Map<String, dynamic>> settings(
    String peer, {
    bool? muted,
    bool? pinned,
    bool? onlyChat,
    String? remark,
    bool? hide,
  }) => call('K260913000606', {
    'peer': peer,
    'muted': ?muted,
    'pinned': ?pinned,
    'onlyChat': ?onlyChat,
    'remark': ?remark,
    'hide': ?hide,
  });
  Future<Map<String, dynamic>> conversations({
    int offset = 0,
    int limit = 50,
  }) => call('K260913000607', {'offset': offset, 'limit': limit});
  Future<Map<String, dynamic>> contacts({int offset = 0, int limit = 50}) =>
      call('K260913000608', {'offset': offset, 'limit': limit});
  Future<Map<String, dynamic>> requestFromQr({
    required String code,
    required String requestId,
    String note = '',
  }) => call('K260913000609', {
    'code': code,
    'requestId': requestId,
    'note': note,
  });
  Future<Map<String, dynamic>> resolveRequest(
    String requestId, {
    required bool accept,
  }) => call('K260913000610', {'requestId': requestId, 'accept': accept});
  Future<Map<String, dynamic>> requests({int offset = 0, int limit = 50}) =>
      call('K260913000611', {'offset': offset, 'limit': limit});
}
