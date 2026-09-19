import 'dart:async';
import 'dart:io';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/media/media_cache.dart';
import 'peer_file_authority.dart';
import 'chat_sent_file_cache.dart';
import 'member_relay_runtime.dart';
import 'novorudp_file_download.dart';
import 'novorudp_relay_frame_link.dart';
import 'peer_file_channel.dart';
import 'group_file_device_scope.dart';
import 'novorudp_device_binding.dart';

/// File streams share the member's secure lane with text without owning it.
class MemberRelayFiles {
  MemberRelayFiles({
    required this.runtime,
    required this.cache,
    required this.privateDirectory,
  }) {
    _incoming = runtime.channels.listen((arrival) {
      if (_active) _attach(arrival.peer, arrival.link);
    });
    _groupIncoming = runtime.groupFileChannels.listen((arrival) {
      if (_active) _attach(arrival.peer, arrival.link, arrival.scope);
    });
    _connections = runtime.connections.listen((connection) {
      if (connection == null) _clear();
    }, onDone: () => unawaited(close()));
  }
  final MemberRelayRuntime runtime;
  final ChatSentFileCache cache;
  final Directory privateDirectory;
  final int _generation = MemberQrMemory.generation;
  final _channels = <String, PeerFileChannel>{};
  final _closingChannels = <Future<void>>{};
  late final StreamSubscription<MemberRelayArrival> _incoming;
  late final StreamSubscription<GroupFileRelayArrival> _groupIncoming;
  late final StreamSubscription _connections;
  bool _closed = false;
  Future<void>? _closing;
  bool get _active =>
      !_closed &&
      _generation == MemberQrMemory.generation &&
      runtime.connection != null;

  void _release(PeerFileChannel channel) {
    final work = channel.close().catchError((Object _) {});
    _closingChannels.add(work);
    unawaited(work.whenComplete(() => _closingChannels.remove(work)));
  }

  PeerFileChannel _attach(
    String peer,
    NovoRudpRelayFrameLink link, [
    GroupFileDeviceScope? scope,
  ]) {
    final id =
        '${link.expectedPeer}/${scope?.groupId ?? ''}/${scope?.messageId ?? ''}';
    final old = _channels[id];
    if (old != null && identical(old.link, link)) return old;
    if (old != null) _release(old);
    if (old == null && _channels.length >= 8) {
      _release(_channels.remove(_channels.keys.first)!);
    }
    final channel = PeerFileChannel(
      link: link,
      repository: runtime.binding.messaging,
      peer: peer,
      groupScope: scope,
      cache: cache,
      privateDirectory: privateDirectory,
      canExchange: () => _active,
      mediaSource: _mediaSource,
    );
    _channels[id] = channel;
    return channel;
  }

  Future<File?> _mediaSource(PeerFileAuthority authority) async {
    if (!_active || !authority.valid) return null;
    final group = authority.groupId != null;
    final id = authority.messageId;
    final (kind, key) = switch (authority.media) {
      'image' => (MediaKind.image, 'chat-image-message:$group:$id:image'),
      'image-thumbnail' => (
        MediaKind.image,
        'chat-image-message:$group:$id:thumbnail',
      ),
      'voice' => (MediaKind.audio, 'chat-voice-asset:${authority.assetId}'),
      'video' ||
      'hevc' => (MediaKind.video, 'chat-video-message:$group:$id:video'),
      'video-thumbnail' => (
        MediaKind.image,
        'chat-video-message:$group:$id:poster',
      ),
      _ => throw const FormatException('Unsupported media source'),
    };
    try {
      // Use the existing retained media; do not create a second persistent copy
      // that could outlive message deletion. Sender verifies size/hash before data.
      final file = await MediaCache.shared.cached(
        scope: 'member:${runtime.binding.messaging.account}',
        contentKey: key,
        kind: kind,
      );
      return _active && authority.valid ? file : null;
    } on StateError {
      return null;
    }
  }

  Future<NovoRudpFileDownload?> receive({
    required String peer,
    bool group = false,
    String? media,
    required String messageId,
    required String assetId,
    required String fileName,
    required int size,
    required String sha256,
    required bool Function() stillActive,
    Future<void> Function(NovoRudpFileDownload)? prepare,
  }) async {
    bool active() => _active && stillActive();
    if (!active() ||
        peer == runtime.binding.messaging.account ||
        size > ChatSentFileCache.maxBytes) {
      return null;
    }
    GroupFileDeviceScope? scope;
    List<NetworkDeviceKey> keys;
    if (group) {
      if (!runtime.enableGroupFiles) return null;
      final manifest = await runtime.binding.messaging.peerFileAuthority(
        messageId,
        peer,
        group: true,
        media: media,
      );
      final groupId = manifest['groupId'];
      if (groupId is! String) {
        throw const FormatException('Missing group file scope');
      }
      final directory = await runtime.binding.groupFileDirectory(
        peer,
        messageId: messageId,
        groupId: groupId,
      );
      scope = directory.scope;
      keys = directory.keys;
    } else {
      keys = await runtime.binding.directory(peer);
    }
    if (!active()) return null;
    for (final key in keys.take(2)) {
      try {
        final link = scope == null
            ? await runtime.connectPeer(peer, key.bindingId)
            : await runtime.connectGroupFilePeer(peer, key.bindingId, scope);
        if (!active()) return null;
        final channel = _attach(peer, link, scope);
        final authority = await channel.authorize(
          messageId,
          sending: false,
          media: media,
        );
        if (!active()) return null;
        if (authority.assetId != assetId ||
            authority.fileName != fileName ||
            authority.size != size ||
            authority.sha256 != sha256) {
          throw StateError('Message file changed');
        }
        final download = await channel.receive(
          authority,
          active,
          prepare: prepare,
        );
        if (!active()) {
          await download.close();
          return null;
        }
        return download;
      } catch (_) {
        if (!active()) return null;
      }
    }
    return null;
  }

  void _clear() {
    for (final channel in _channels.values) {
      _release(channel);
    }
    _channels.clear();
  }

  Future<void> close() {
    _closed = true;
    return _closing ??= _close();
  }

  Future<void> _close() async {
    _clear();
    await _incoming.cancel();
    await _groupIncoming.cancel();
    await _connections.cancel();
    await Future.wait(_closingChannels.toList());
  }
}
