/// Metadata for a server-normalized video; never stores bearer grants.
class ChatVideo {
  ChatVideo({
    required this.assetId,
    required this.durationMs,
    required this.width,
    required this.height,
    required this.hasAudio,
  }) {
    if (!RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(assetId) ||
        durationMs < 500 ||
        durationMs > 120500 ||
        width < 2 ||
        width > 1280 ||
        height < 2 ||
        height > 1280) {
      throw const FormatException('视频处理结果无效');
    }
  }
  final String assetId;
  final int durationMs, width, height;
  final bool hasAudio;
  factory ChatVideo.fromPrepared(Map<String, dynamic> value) {
    if (value['status'] != 'ready' ||
        value['assetId'] is! String ||
        value['durationMs'] is! int ||
        value['width'] is! int ||
        value['height'] is! int ||
        value['hasAudio'] is! bool) {
      throw const FormatException('视频尚未处理完成');
    }
    return ChatVideo(
      assetId: value['assetId'] as String,
      durationMs: value['durationMs'] as int,
      width: value['width'] as int,
      height: value['height'] as int,
      hasAudio: value['hasAudio'] as bool,
    );
  }
  Map<String, dynamic> toMessageFields() => {
    'videoAssetId': assetId,
    'videoDurationMs': durationMs,
    'videoWidth': width,
    'videoHeight': height,
    'videoHasAudio': hasAudio,
  };
}
