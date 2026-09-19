import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../../core/session/member_qr_memory.dart';
import 'chat_sent_file_cache.dart';
import 'messaging_repository.dart';
import 'novorudp_file_download.dart';
import 'novorudp_file_sender.dart';
import 'novorudp_frame.dart';
import 'novorudp_frame_link.dart';
import 'peer_file_authority.dart';
import 'group_file_device_scope.dart';

/// Runs only over an independently authenticated member/device lane.
class PeerFileChannel {
  PeerFileChannel({
    required this.link,
    required this.repository,
    required this.peer,
    this.groupScope,
    required this.cache,
    required this.privateDirectory,
    required this.canExchange,
  }) {
    _subscription = link.frames.listen(
      (frame) {
        if (!_active ||
            frame.streamId != controlStream ||
            frame.kind != NovoRudpFrameKind.endpoint ||
            frame.payload.length > 256) {
          return;
        }
        try {
          final packet = jsonDecode(utf8.decode(frame.payload));
          if (packet is! Map ||
              packet.length != (groupId == null ? 3 : 4) ||
              packet['v'] != (groupId == null ? 1 : 2) ||
              (groupId != null && packet['groupId'] != groupId) ||
              packet['messageId'] is! String ||
              frame.objectId == BigInt.zero) {
            return;
          }
          final messageId = packet['messageId'] as String;
          if (!_uuid.hasMatch(messageId) ||
              (scopedMessageId != null && messageId != scopedMessageId)) {
            return;
          }
          switch (packet['op']) {
            case 'request':
              if (_sending != null) {
                if (_sending == frame.objectId &&
                    _sendingMessage == messageId &&
                    _ready) {
                  unawaited(
                    _control(
                      'ready',
                      messageId,
                      frame.objectId,
                    ).catchError((Object _) {}),
                  );
                }
              } else {
                _sending = frame.objectId;
                _sendingMessage = messageId;
                _serving = _serve(messageId, frame.objectId);
                unawaited(_serving);
              }
            case 'ready':
              if (_receiving == frame.objectId &&
                  _receivingMessage == messageId &&
                  _accepted?.isCompleted == false) {
                _accepted!.complete();
              }
            case 'reject':
              if (_receiving == frame.objectId &&
                  _receivingMessage == messageId) {
                if (_accepted?.isCompleted == false) {
                  _accepted!.completeError(StateError('Peer file unavailable'));
                }
                unawaited(_download?.close());
              }
          }
        } catch (_) {
          /* Malformed control packets never create a transfer. */
        }
      },
      onError: (Object _) => unawaited(close()),
      onDone: () => unawaited(close()),
    );
  }

  final NovoRudpFrameLink link;
  final MessagingRepository repository;
  final String peer;
  final GroupFileDeviceScope? groupScope;
  String? get groupId => groupScope?.groupId;
  String? get scopedMessageId => groupScope?.messageId;
  final ChatSentFileCache cache;
  final Directory privateDirectory;
  final bool Function() canExchange;
  static final controlStream = BigInt.from(0x4b434643);
  static final dataStream = BigInt.from(0x4b434644);
  static final _uuid = RegExp(r'^[0-9a-fA-F-]{36}$');
  final int _generation = MemberQrMemory.generation;
  late final StreamSubscription<NovoRudpFrame> _subscription;
  bool _closed = false, _ready = false;
  BigInt? _sending, _receiving;
  String? _sendingMessage, _receivingMessage;
  Completer<void>? _accepted;
  NovoRudpFileSender? _sender;
  NovoRudpFileDownload? _download;
  Timer? _renewSend, _renewReceive, _retry;
  Future<void>? _closing;
  Future<void>? _serving;

  bool get _active =>
      !_closed && _generation == MemberQrMemory.generation && canExchange();
  void _check() {
    if (!_active) throw StateError('Peer file lane unavailable');
  }

  Future<void> _control(String op, String messageId, BigInt object) async {
    _check();
    await link
        .send(
          NovoRudpFrame(
            kind: NovoRudpFrameKind.endpoint,
            sessionId: link.channel.sessionId,
            streamId: controlStream,
            objectId: object,
            sequence: BigInt.zero,
            ackEpoch: BigInt.zero,
            payload: utf8.encode(
              jsonEncode({
                'v': groupId == null ? 1 : 2,
                'op': op,
                'messageId': messageId,
                if (groupId != null) 'groupId': groupId,
              }),
            ),
          ),
        )
        .timeout(const Duration(seconds: 1));
  }

  Future<PeerFileAuthority> authorize(
    String messageId, {
    required bool sending,
  }) async {
    _check();
    if (scopedMessageId != null && messageId != scopedMessageId) {
      throw StateError('File outside lane scope');
    }
    final value = await PeerFileAuthority.read(
      repository,
      peer,
      messageId,
      sending: sending,
      groupId: groupId,
    );
    _check();
    final scope = groupScope;
    if (scope != null &&
        (value.groupId != scope.groupId ||
            value.messageId != scope.messageId ||
            value.sender != scope.sender ||
            value.recipient != scope.recipient ||
            value.senderMembershipVersion != scope.senderVersion ||
            value.recipientMembershipVersion != scope.recipientVersion)) {
      throw StateError('Group file lane permission changed');
    }
    return value;
  }

  Future<void> _serve(String messageId, BigInt object) async {
    try {
      var authority = await authorize(messageId, sending: true);
      final sent = await cache.use<bool>(
        assetId: authority.assetId,
        size: authority.size,
        sha256: authority.sha256,
        send: (source) async {
          final refreshed = await authorize(messageId, sending: true);
          if (!authority.sameFile(refreshed)) {
            throw StateError('Peer file changed');
          }
          authority = refreshed;
          final sender = _sender = NovoRudpFileSender(
            link: link,
            file: source,
            streamId: dataStream,
            objectId: object,
            size: authority.size,
            sha256: authority.sha256,
            canSend: () => _active && authority.valid,
          );
          var renewing = false;
          _renewSend = Timer.periodic(const Duration(seconds: 5), (_) async {
            if (renewing) return;
            renewing = true;
            try {
              final current = await authorize(
                messageId,
                sending: true,
              ).timeout(const Duration(seconds: 5));
              if (!authority.sameFile(current)) {
                throw StateError('Peer file changed');
              }
              authority = current;
            } catch (_) {
              sender.cancel();
            } finally {
              renewing = false;
            }
          });
          _ready = true;
          await _control('ready', messageId, object);
          await sender.run();
          final completed = await authorize(messageId, sending: true);
          if (!authority.sameFile(completed)) {
            throw StateError('Peer file changed');
          }
          return true;
        },
      );
      if (sent != true) throw StateError('Peer file cache miss');
    } catch (_) {
      try {
        await _control('reject', messageId, object);
      } catch (_) {}
    } finally {
      _renewSend?.cancel();
      _renewSend = null;
      _sender = null;
      _sending = null;
      _sendingMessage = null;
      _ready = false;
    }
  }

  Future<NovoRudpFileDownload> receive(
    PeerFileAuthority expected,
    bool Function() stillActive, {
    Future<void> Function(NovoRudpFileDownload)? prepare,
  }) async {
    _check();
    if (_receiving != null) throw StateError('Peer file receive busy');
    final random = Random.secure();
    final object =
        (BigInt.from(random.nextInt(1 << 32)) << 32) |
        BigInt.from(random.nextInt(1 << 32));
    if (object == BigInt.zero) throw StateError('Invalid transfer identity');
    _receiving = object;
    _receivingMessage = expected.messageId;
    final accepted = _accepted = Completer<void>();
    unawaited(accepted.future.then<void>((_) {}, onError: (Object _) {}));
    NovoRudpFileDownload? download;
    try {
      var authority = await authorize(expected.messageId, sending: false);
      if (!authority.sameFile(expected) || !stillActive()) {
        throw StateError('Peer file changed');
      }
      download = await NovoRudpFileDownload.open(
        link: link,
        privateDirectory: privateDirectory,
        streamId: dataStream,
        objectId: object,
        size: authority.size,
        sha256: authority.sha256,
        canReceive: () => _active && stillActive() && authority.valid,
      );
      _download = download;
      final owned = download;
      // Seed the bitmap before REQUEST: the sender's first DONE must observe
      // cached fragments rather than launch an unnecessary full initial send.
      await prepare?.call(owned);
      _check();
      if (!stillActive()) throw StateError('Peer file cancelled');
      var renewing = false;
      _renewReceive = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (renewing) return;
        renewing = true;
        try {
          final current = await authorize(
            expected.messageId,
            sending: false,
          ).timeout(const Duration(seconds: 5));
          if (!authority.sameFile(current) || !stillActive()) {
            throw StateError('Peer file changed');
          }
          authority = current;
        } catch (_) {
          await owned.close();
        } finally {
          renewing = false;
        }
      });
      unawaited(
        owned.completed.then<void>(
          (_) {
            if (!accepted.isCompleted) accepted.complete();
            _finishReceive(object);
          },
          onError: (Object _) {
            if (!accepted.isCompleted) {
              accepted.completeError(StateError('Peer receive ended'));
            }
            _finishReceive(object);
          },
        ),
      );
      _retry = Timer.periodic(const Duration(milliseconds: 450), (_) {
        if (accepted.isCompleted) return;
        unawaited(
          _control(
            'request',
            expected.messageId,
            object,
          ).catchError((Object _) {}),
        );
      });
      await _control('request', expected.messageId, object);
      await accepted.future.timeout(const Duration(seconds: 3));
      _retry?.cancel();
      _retry = null;
      _check();
      if (!stillActive()) throw StateError('Peer file cancelled');
      return owned;
    } catch (_) {
      await download?.close();
      _finishReceive(object);
      rethrow;
    }
  }

  void _finishReceive(BigInt object) {
    if (_receiving != object) return;
    _renewReceive?.cancel();
    _renewReceive = null;
    _retry?.cancel();
    _retry = null;
    _download = null;
    _receiving = null;
    _receivingMessage = null;
    _accepted = null;
  }

  Future<void> close() {
    _closed = true;
    _sender?.cancel();
    _renewSend?.cancel();
    _renewReceive?.cancel();
    _retry?.cancel();
    if (_accepted?.isCompleted == false) {
      _accepted!.completeError(StateError('Peer file lane closed'));
    }
    return _closing ??= Future.wait([
      _subscription.cancel(),
      if (_download != null) _download!.close(),
      ?_serving,
    ]).then((_) {});
  }
}
