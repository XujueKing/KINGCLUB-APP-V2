class ChatVideoGrant {
  ChatVideoGrant._(
    this.fileId,
    this.path,
    this.authorization,
    this.sha256,
    this.size,
  );
  final String fileId, path, authorization, sha256;
  final int size;
  factory ChatVideoGrant.parse(
    Map<String, dynamic> result,
    String messageId, {
    required bool group,
    required bool full,
  }) {
    final slot = full ? 'video' : 'thumbnail',
        value = result[full ? 'video' : 'thumbnail'];
    final expected =
        '/kingclub/${group ? 'group-chat-video' : 'chat-video'}/$messageId/$slot';
    if (result['messageId'] != messageId ||
        value is! Map ||
        value['path'] != expected ||
        value['fileId'] is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(value['fileId'] as String) ||
        value['size'] is! int ||
        (value['size'] as int) < 1 ||
        (value['size'] as int) > (full ? 32 * 1024 * 1024 : 1024 * 1024) ||
        value['sha256'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(value['sha256'] as String) ||
        value['headers'] is! Map) {
      throw const FormatException('视频授权无效');
    }
    final auth = (value['headers'] as Map)['authorization'];
    if (auth is! String ||
        !auth.startsWith('Bearer ') ||
        auth.length > 4103 ||
        auth.contains('\n') ||
        auth.contains('\r')) {
      throw const FormatException('视频授权无效');
    }
    return ChatVideoGrant._(
      value['fileId'] as String,
      expected,
      auth,
      value['sha256'] as String,
      value['size'] as int,
    );
  }
}
