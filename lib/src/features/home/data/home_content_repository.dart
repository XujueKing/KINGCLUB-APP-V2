import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../../commerce/data/ordering_table_repository.dart';

Never _invalid() => throw const AuthFailure('HOME_CONTENT_INVALID', '首页内容暂不可用');
final _ref = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final _city = RegExp(r'^(?:[1-9][0-9]{5}|INT_[1-9][0-9]{0,11})$');
String _text(dynamic value, int max, {bool empty = false}) {
  if (value is! String || value.length > max || (!empty && value.isEmpty)) {
    _invalid();
  }
  return value;
}

String homeMedia(dynamic value) {
  final text = _text(value, 2048), uri = Uri.tryParse(text);
  if (RegExp(
    r'^assets/legacy/home/legacy_(?:banner_(?:recruitment|childrens_day)|poster_(?:handsome|party|birthday|music))\.webp$',
  ).hasMatch(text)) {
    return text;
  }
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.queryParameters.keys.any(
        (k) => RegExp(
          r'token|signature|credential|secret|authorization',
          caseSensitive: false,
        ).hasMatch(k),
      )) {
    _invalid();
  }
  return text;
}

int _count(dynamic value) {
  if (value is! int || value < 0 || value > 9007199254740991) _invalid();
  return value;
}

Map<String, String> _localized(dynamic value) {
  if (value is! Map) _invalid();
  return {
    for (final key in ['zh-CN', 'zh-TW', 'en', 'th'])
      key: _text(value[key], 5000, empty: true),
  };
}

class HomeContent {
  HomeContent({
    required this.ref,
    required this.placement,
    required this.mode,
    required this.cover,
    required this.ratio,
    required this.titles,
    required this.descriptions,
    this.revision = 1,
    this.video,
    this.author,
    this.avatar,
    this.likeCount = 0,
    this.liked = false,
  });
  final String ref, placement, mode, cover;
  final Map<String, String> titles, descriptions;
  final double ratio;
  final int revision;
  final String? video, author, avatar;
  int likeCount;
  bool liked;
  String copy(Map<String, String> values, String locale) =>
      values[locale]?.isNotEmpty == true
      ? values[locale]!
      : values['zh-CN'] ?? '';
  String get cacheKey => 'home/$ref/$revision';
  factory HomeContent.parse(dynamic value) {
    if (value is! Map || value['document'] is! Map) _invalid();
    final doc = value['document'] as Map;
    final reference = _text(value['contentRef'], 64),
        placement = _text(value['placement'], 16),
        mode = _text(value['mode'], 16);
    final ratio = doc['aspectRatio'], revision = _count(value['revision']);
    if (!_ref.hasMatch(reference) ||
        !{'banner', 'card'}.contains(placement) ||
        !{'poster', 'article', 'video'}.contains(mode) ||
        ratio is! num ||
        !ratio.isFinite ||
        ratio < .4 ||
        ratio > 2.5 ||
        revision < 1 ||
        value['liked'] is! bool) {
      _invalid();
    }
    final video = doc['video'] == null ? null : homeMedia(doc['video']);
    if (mode == 'video' && (video == null || !video.startsWith('https:'))) {
      _invalid();
    }
    return HomeContent(
      ref: reference,
      placement: placement,
      mode: mode,
      cover: homeMedia(doc['cover']),
      ratio: ratio.toDouble(),
      revision: revision,
      titles: _localized(doc['titles']),
      descriptions: _localized(doc['descriptions']),
      video: video,
      author: doc['authorName'] == null
          ? null
          : _text(doc['authorName'], 64, empty: true),
      avatar: doc['authorAvatar'] == null
          ? null
          : homeMedia(doc['authorAvatar']),
      likeCount: _count(value['likeCount']),
      liked: value['liked'] as bool,
    );
  }
}

class HomeContentRepository {
  HomeContentRepository({required this.readSession, required this.request});
  factory HomeContentRepository.secure(String baseUrl) {
    final client = KingclubSecureClient(baseUrl),
        sessions = SecureSessionStore();
    return HomeContentRepository(
      readSession: sessions.readSession,
      request: (id, params, session) =>
          client.call(id, params, session: session),
    );
  }
  final OrderingSessionReader readSession;
  final OrderingContextRequest request;
  String? _identity(Map<String, dynamic>? s) {
    if (s?['account'] is! Map) return null;
    final values = [
      (s!['account'] as Map)['userAccount'],
      s['sessionId'],
      s['apiKeyId'],
      s['apiKey'],
    ];
    if (values.any((v) => v is! String || v.isEmpty)) return null;
    return values.join('\u0000');
  }

  Future<Map> _call(String id, Map<String, dynamic> params) async {
    final session = await readSession(), identity = _identity(session);
    if (identity == null) throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    final response = await request(id, params, session!);
    if (_identity(await readSession()) != identity) {
      throw const AuthFailure('SESSION_EXPIRED', '登录状态已变化');
    }
    // KingclubSecureClient has already decrypted the HTTP data envelope.
    final result = response['result'];
    if (result is! Map) _invalid();
    return result;
  }

  Future<List<HomeContent>> list(String? cityCode) async {
    if (cityCode != null && !_city.hasMatch(cityCode)) _invalid();
    final result = await _call('K261002001970', {'cityCode': ?cityCode});
    if (result['cityCode'] != cityCode ||
        result['items'] is! List ||
        (result['items'] as List).length > 120) {
      _invalid();
    }
    final items = (result['items'] as List).map(HomeContent.parse).toList();
    if (items.map((i) => i.ref).toSet().length != items.length) _invalid();
    return items;
  }

  Future<({int count, bool liked})> like(
    HomeContent content,
    bool liked,
    String? cityCode,
  ) async {
    final result = await _call('K261002001971', {
      'contentRef': content.ref,
      'liked': liked,
      'cityCode': ?cityCode,
    });
    if (result['contentRef'] != content.ref || result['liked'] != liked) {
      _invalid();
    }
    return (count: _count(result['likeCount']), liked: liked);
  }
}

/// Built-in copies of the user's existing public artwork for the first frame.
/// A successful server response (including an empty catalog) replaces these.
List<HomeContent> legacyHomeContent() {
  const rows = [
    ('legacy_recruitment', 'banner', 'recruitment', '兼职探店品鉴官'),
    ('legacy_childrens_day', 'banner', 'childrens_day', '一起过六一'),
    ('legacy_handsome', 'card', 'handsome', '谁是最帅小哥哥'),
    ('legacy_party', 'card', 'party', 'AI 卡颜局'),
    ('legacy_birthday', 'card', 'birthday', '生日有礼'),
    ('legacy_music', 'card', 'music', '玩音乐能赚钱'),
  ];
  return [
    for (final r in rows)
      HomeContent(
        ref: r.$1,
        placement: r.$2,
        mode: 'poster',
        cover:
            'assets/legacy/home/legacy_${r.$2 == 'banner' ? 'banner' : 'poster'}_${r.$3}.webp',
        ratio: r.$2 == 'banner' ? 690 / 417 : 332 / 460,
        titles: {'zh-CN': r.$4},
        descriptions: const {},
      ),
  ];
}
