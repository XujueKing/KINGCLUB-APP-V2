import 'dart:convert';
import 'dart:io';

import 'chat_image_uploader.dart';
import 'sticker_library_repository.dart';

class StickerLibraryConflict extends StateError {
  StickerLibraryConflict() : super('两端表情库都有修改');
}

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
    Future<bool> Function(List<Map<String, dynamic>>) apply, {
    bool combine = false,
  }) async {
    _check();
    final journal = File('${directory.path}/cloud.json');
    Map<String, dynamic> state = {};
    if (await journal.exists()) {
      state = _decodeJournal(await journal.readAsString());
    }
    _check();
    final mapping = Map<String, dynamic>.from(state['mapping'] as Map? ?? {});
    final signature = jsonEncode(local);
    final remote = await cloud.read();
    _check();
    var dirty = state['local'] != signature;
    if (!dirty && state['revision'] == remote.revision) {
      var intact = true;
      for (final pack in local) {
        for (final path in (pack['images'] as List).cast<String>()) {
          final file = File(path);
          if (file.parent.absolute.path != directory.absolute.path ||
              !await file.exists()) {
            intact = false;
            break;
          }
        }
        if (!intact) break;
      }
      _check();
      if (intact) return;
    }

    final hasLocal = local.any((pack) => (pack['images'] as List).isNotEmpty);
    final hasRemote = remote.packs.any((pack) => pack.assets.isNotEmpty);
    // A committed write can lose its response. When every local image already
    // has a known asset ID, an identical remote snapshot proves convergence;
    // adopting its revision is safe even if the local baseline is older.
    final mapped = <Map<String, dynamic>>[];
    var fullyMapped = true;
    for (final pack in local) {
      final assets = <String>[];
      for (final path in (pack['images'] as List).cast<String>()) {
        final asset = mapping[path];
        if (asset is! String) {
          fullyMapped = false;
          break;
        }
        assets.add(asset);
      }
      if (!fullyMapped) break;
      mapped.add({'name': pack['name'], 'images': assets});
    }
    if (dirty &&
        fullyMapped &&
        jsonEncode(mapped) ==
            jsonEncode(remote.packs.map((pack) => pack.toJson()).toList())) {
      dirty = false;
    }
    if (!combine &&
        dirty &&
        ((state.containsKey('revision') &&
                state['revision'] != remote.revision) ||
            (!state.containsKey('revision') && hasLocal && hasRemote))) {
      throw StickerLibraryConflict();
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
      saved = await cloud.write(
        remote.revision,
        combine ? combineStickerPacks(remote.packs, packs) : packs,
      );
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

/// Explicit keep-both resolution: union assets in matching named categories.
List<StickerPack> combineStickerPacks(
  List<StickerPack> remote,
  List<StickerPack> local,
) {
  final result = remote.map((p) => StickerPack(p.name, p.assets)).toList();
  for (var i = 0; i < local.length; i++) {
    final pack = local[i];
    final index = i == 0 && result.isNotEmpty
        ? 0
        : result.indexWhere((p) => p.name == pack.name);
    if (index < 0) {
      result.add(StickerPack(pack.name, pack.assets));
    } else {
      final old = result[index];
      result[index] = StickerPack(
        old.name,
        {...old.assets, ...pack.assets}.toList(),
      );
    }
  }
  StickerLibrarySnapshot.parse({
    'revision': 0,
    'packs': result.map((p) => p.toJson()).toList(),
  });
  return result;
}

// A damaged local baseline must not permanently disable cloud recovery. Treat
// it as an unknown baseline: existing first-sync conflict rules protect both
// libraries. File-system failures still propagate and are not treated as empty.
Map<String, dynamic> _decodeJournal(String source) {
  try {
    final raw = jsonDecode(source);
    if (raw is! Map<String, dynamic> ||
        raw['revision'] is! int ||
        (raw['revision'] as int) < 0 ||
        (raw['revision'] as int) > 2147483647 ||
        raw['local'] is! String ||
        raw['mapping'] is! Map<String, dynamic>) {
      return {};
    }
    final local = jsonDecode(raw['local'] as String);
    if (local is! List ||
        local.isEmpty ||
        local.any(
          (pack) =>
              pack is! Map ||
              pack['name'] is! String ||
              pack['images'] is! List ||
              (pack['images'] as List).any((path) => path is! String),
        )) {
      return {};
    }
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if ((raw['mapping'] as Map).values.any(
      (asset) => asset is! String || !uuid.hasMatch(asset),
    )) {
      return {};
    }
    return raw;
  } on FormatException {
    return {};
  }
}
