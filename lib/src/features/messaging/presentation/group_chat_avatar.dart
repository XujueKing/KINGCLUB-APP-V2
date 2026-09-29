import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/media/media_cache.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/group_chat_repository.dart';
import '../data/messaging_repository.dart';

/// Edge-to-edge tiles: halves for two, one above two for three members.
List<Rect> groupAvatarTiles(int count, {double size = 144}) {
  count = count.clamp(0, 9);
  if (count == 0) return const [];
  final rows = count <= 2
      ? 1
      : count <= 6
      ? 2
      : 3;
  final base = count ~/ rows;
  final extra = count % rows;
  return [
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < base + (row >= rows - extra ? 1 : 0); col++)
        Rect.fromLTWH(
          col * size / (base + (row >= rows - extra ? 1 : 0)),
          row * size / rows,
          size / (base + (row >= rows - extra ? 1 : 0)),
          size / rows,
        ),
  ];
}

/// One small, account-scoped, PNG-compressed mosaic, rather than nine full-size
/// image widgets. Read disk first; refresh membership without a loading spinner.
class GroupChatAvatar extends StatefulWidget {
  const GroupChatAvatar({
    super.key,
    required this.repository,
    required this.groupId,
    this.size = 42,
  });
  final MessagingRepository repository;
  final String groupId;
  final double size;
  @override
  State<GroupChatAvatar> createState() => _GroupChatAvatarState();
}

class _GroupChatAvatarState extends State<GroupChatAvatar> {
  static const _storage = FlutterSecureStorage();
  File? _file;
  int _generation = 0;
  StreamSubscription<void>? _session;
  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      if (!mounted) return;
      _generation++;
      setState(() => _file = null);
    });
    unawaited(_load());
  }

  @override
  void didUpdateWidget(GroupChatAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId ||
        oldWidget.repository != widget.repository) {
      _generation++;
      _file = null;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = _generation;
    final repository = widget.repository;
    final group = widget.groupId;
    final scope = 'member:${repository.account}';
    final pointer =
        'kingclub.group-avatar.v2.${jsonEncode([repository.account, group])}';
    bool active() => mounted && generation == _generation;
    void display(File file) {
      if (active()) setState(() => _file = file);
    }

    try {
      if (repository.persistHistory) {
        final key = await _storage.read(key: pointer);
        if (!active()) return;
        if (key != null) {
          try {
            display(
              await MediaCache.shared.cachedImage(
                scope: scope,
                contentKey: key,
              ),
            );
          } catch (_) {
            /* A cleared cache is rebuilt below. */
          }
        }
      }
      final details = await GroupChatRepository(repository).details(group);
      if (!active()) return;
      final members = (details['members'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => m['account'])
          .whereType<String>()
          .toSet()
          .take(9)
          .toList();
      if (members.isEmpty) return;
      final identities = <String>[];
      final images = <ui.Image?>[];
      try {
        for (final member in members) {
          if (!active()) return;
          ui.Image? image;
          String? fileId;
          try {
            final profile = await repository.avatarProfile(member);
            final avatar = profile['avatar'];
            if (avatar is Map && avatar['fileId'] is String) {
              fileId = avatar['fileId'] as String;
              final contentKey = 'profile:$member:$fileId';
              File source;
              if (avatar['cacheOnly'] == true) {
                source = await MediaCache.shared.cachedImage(
                  scope: scope,
                  contentKey: contentKey,
                );
              } else {
                final path = avatar['path'];
                final valid =
                    path is String &&
                    (member == repository.account
                        ? RegExp(
                            r'^/attachments/[A-Za-z0-9_-]+\?token=[A-Za-z0-9%._~-]+$',
                          ).hasMatch(path)
                        : path.startsWith('/kingclub/profile-media/') &&
                              !path.contains('..') &&
                              !path.contains('?') &&
                              !path.contains('#'));
                if (!valid) throw const FormatException('Invalid avatar path');
                source = await MediaCache.shared.get(
                  '${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}$path',
                  scope: scope,
                  contentKey: contentKey,
                  headers: (avatar['headers'] as Map? ?? {}).map(
                    (k, v) => MapEntry(k.toString(), v.toString()),
                  ),
                );
              }
              final codec = await ui.instantiateImageCodec(
                await source.readAsBytes(),
                targetWidth: 144,
              );
              try {
                image = (await codec.getNextFrame()).image;
              } finally {
                codec.dispose();
              }
            }
          } on AuthFailure catch (error) {
            if (error.code == 'NETWORK_ERROR' ||
                error.code == 'SESSION_CHANGED' ||
                error.code == 'SESSION_EXPIRED') {
              rethrow;
            }
            fileId = null;
          } catch (_) {
            fileId = null;
          }
          identities.add('$member:${image == null ? 'fallback' : fileId}');
          images.add(image);
        }
        if (!active()) return;
        final hash = await Sha256().hash(
          utf8.encode(jsonEncode([group, identities])),
        );
        final key =
            'group-avatar-v2:${hash.bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';
        File? file;
        try {
          file = await MediaCache.shared.cachedImage(
            scope: scope,
            contentKey: key,
          );
        } catch (_) {}
        if (file == null) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawColor(const Color(0xFF303030), BlendMode.src);
          final tiles = groupAvatarTiles(images.length);
          for (var i = 0; i < tiles.length; i++) {
            final tile = tiles[i], image = images[i];
            if (image != null) {
              final sourceSize = Size(
                image.width.toDouble(),
                image.height.toDouble(),
              );
              final fitted = applyBoxFit(BoxFit.cover, sourceSize, tile.size);
              canvas.drawImageRect(
                image,
                Alignment.center.inscribe(
                  fitted.source,
                  Offset.zero & sourceSize,
                ),
                tile,
                Paint()..filterQuality = FilterQuality.medium,
              );
            } else {
              canvas.drawRect(tile, Paint()..color = const Color(0xFF494949));
              final paint = Paint()..color = const Color(0xFFB8B8B8);
              canvas.drawCircle(
                Offset(tile.center.dx, tile.top + tile.height * .35),
                tile.width * .16,
                paint,
              );
              canvas.drawOval(
                Rect.fromCenter(
                  center: Offset(tile.center.dx, tile.top + tile.height * .77),
                  width: tile.width * .6,
                  height: tile.height * .43,
                ),
                paint,
              );
            }
          }
          final picture = recorder.endRecording();
          final composite = await picture.toImage(144, 144);
          picture.dispose();
          try {
            final bytes = await composite.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (!active() || bytes == null) return;
            file = await MediaCache.shared.importBytes(
              bytes.buffer.asUint8List(),
              scope: scope,
              contentKey: key,
              kind: MediaKind.image,
            );
          } finally {
            composite.dispose();
          }
        }
        if (!active()) return;
        if (repository.persistHistory) {
          await _storage.write(key: pointer, value: key);
        }
        display(file);
      } finally {
        for (final image in images) {
          image?.dispose();
        }
      }
    } on AuthFailure catch (error) {
      if (active() && error.code != 'NETWORK_ERROR') {
        if (repository.persistHistory) await _storage.delete(key: pointer);
        if (active()) setState(() => _file = null);
      }
    } catch (_) {
      /* Offline: retain the last local mosaic. */
    }
  }

  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox.square(
      dimension: widget.size,
      child: _file == null
          ? const ColoredBox(
              color: Color(0xFF303030),
              child: Icon(Icons.groups, color: Color(0xFFB8B8B8), size: 28),
            )
          : Image.file(
              _file!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.groups, color: Color(0xFFB8B8B8)),
            ),
    ),
  );
}
