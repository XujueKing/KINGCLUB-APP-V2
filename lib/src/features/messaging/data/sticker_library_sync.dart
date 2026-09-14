import 'dart:convert';
import 'dart:io';

import 'chat_image_uploader.dart';
import 'sticker_library_repository.dart';

/// Keeps existing local files until the panel commits a matching snapshot.
class StickerLibrarySync {
  StickerLibrarySync(this.cloud, this.directory, {this.openUploader});
  final StickerLibraryRepository cloud;
  final Directory directory;
  final Future<ChatImageUploader> Function()? openUploader;
  ChatImageUploader? _uploader;
  bool _disposed = false;
  void _check() {
    if (_disposed) throw StateError('表情同步已取消');
  }

  Future<void> synchronize(
    List<Map<String, dynamic>> local,
    Future<bool> Function(List<Map<String, dynamic>>) apply,
  ) async {
    _check();
    final journal = File('${directory.path}/cloud.json');
    Map<String, dynamic> state = {};
    if (await journal.exists()) {
      state = Map<String, dynamic>.from(
        jsonDecode(await journal.readAsString()) as Map,
      );
    }
    _check();
    final mapping = Map<String, dynamic>.from(state['mapping'] as Map? ?? {});
    final signature = jsonEncode(local);
    final remote = await cloud.read();
    _check();
    final dirty = state['local'] != signature;
    final hasLocal = local.any((pack) => (pack['images'] as List).isNotEmpty);
    final hasRemote = remote.packs.any((pack) => pack.assets.isNotEmpty);
    if (dirty &&
        ((state.containsKey('revision') &&
                state['revision'] != remote.revision) ||
            (!state.containsKey('revision') && hasLocal && hasRemote))) {
      throw StateError('另一台设备也修改了表情库，本机修改已保留，暂未覆盖');
    }
    var saved = remote;
    final uploaded = <UploadedChatImage>[];
    if (dirty && (state.containsKey('revision') || hasLocal)) {
      final packs = <StickerPack>[];
      for (final pack in local) {
        final assets = <String>[];
        for (final path in (pack['images'] as List).cast<String>()) {
          final file = File(path);
          if (file.parent.absolute.path != directory.absolute.path) {
            throw StateError('表情文件位置无效');
          }
          var asset = mapping[path] as String?;
          if (asset == null) {
            final size = await file.length();
            if (size < 1 || size > 20 * 1024 * 1024) {
              throw StateError('表情文件须不超过20MB');
            }
            _uploader ??=
                await (openUploader?.call() ??
                    ChatImageUploader.open(cloud.messaging));
            _check();
            final image = await _uploader!.upload(await file.readAsBytes());
            _check();
            asset = image.assetId;
            uploaded.add(image);
            mapping[path] = asset;
          }
          assets.add(asset);
        }
        packs.add(StickerPack(pack['name'] as String, assets));
      }
      saved = await cloud.write(remote.revision, packs);
      _check();
    }
    final resolved = <Map<String, dynamic>>[];
    for (final pack in saved.packs) {
      final paths = <String>[];
      for (final asset in pack.assets) {
        String? path;
        for (final entry in mapping.entries) {
          if (entry.value == asset &&
              File(entry.key).parent.absolute.path == directory.absolute.path &&
              await File(entry.key).exists()) {
            path = entry.key;
            break;
          }
        }
        if (path == null) {
          final bytes = await cloud.download(asset);
          _check();
          path = '${directory.path}/cloud-$asset.image';
          final temp = File('$path.tmp');
          await temp.writeAsBytes(bytes, flush: true);
          _check();
          await temp.rename(path);
          mapping[path] = asset;
        }
        paths.add(path);
      }
      resolved.add({'name': pack.name, 'images': paths});
    }
    _check();
    if (!await apply(resolved)) return;
    _check();
    final temp = File('${journal.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'revision': saved.revision,
        'local': jsonEncode(resolved),
        'mapping': mapping,
      }),
      flush: true,
    );
    _check();
    await temp.rename(journal.path);
    for (final image in uploaded) {
      await _uploader?.acknowledgeQueued(image);
    }
  }

  void dispose() {
    _disposed = true;
    _uploader?.dispose();
    cloud.dispose();
  }
}
