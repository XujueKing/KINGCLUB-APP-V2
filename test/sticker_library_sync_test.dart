import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/sticker_library_sync.dart';
import 'package:kingclub/src/features/messaging/data/sticker_library_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

const asset = '12345678-1234-4234-8234-123456789012';

class Cloud extends StickerLibraryRepository {
  Cloud(this.snapshot)
    : super(MessagingRepository(account: 'fixture', call: (_, _) async => {}));
  StickerLibrarySnapshot snapshot;
  int writes = 0;
  @override
  Future<StickerLibrarySnapshot> read() async => snapshot;
  @override
  Future<Uint8List> download(String assetId) async =>
      Uint8List.fromList([1, 2, 3]);
  @override
  Future<StickerLibrarySnapshot> write(
    int revision,
    List<StickerPack> packs,
  ) async {
    writes++;
    expect(revision, snapshot.revision);
    return snapshot = StickerLibrarySnapshot(revision + 1, packs);
  }
}

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sticker-sync-');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test('unchanged reconnect leaves panel snapshot untouched', () async {
    final file = await File('${dir.path}/local.image').writeAsBytes([1, 2, 3]);
    final local = [
      {
        'name': 'favorites',
        'images': [file.path],
      },
    ];
    final cloud = Cloud(
      StickerLibrarySnapshot(2, [
        StickerPack('favorites', [asset]),
      ]),
    );
    final sync = StickerLibrarySync(cloud, dir);
    addTearDown(sync.dispose);
    await File('${dir.path}/cloud.json').writeAsString(
      jsonEncode({
        'revision': 2,
        'local': jsonEncode(local),
        'mapping': {file.path: asset},
      }),
    );
    await sync.synchronize(
      local,
      (_) async => throw StateError('must not reset panel'),
    );
    expect(cloud.writes, 0);
  });
  test('unchanged cloud still restores a missing local image', () async {
    final path = '${dir.path}/missing.image';
    final local = [
      {
        'name': 'favorites',
        'images': [path],
      },
    ];
    final cloud = Cloud(
      StickerLibrarySnapshot(2, [
        StickerPack('favorites', [asset]),
      ]),
    );
    final sync = StickerLibrarySync(cloud, dir);
    addTearDown(sync.dispose);
    await File('${dir.path}/cloud.json').writeAsString(
      jsonEncode({
        'revision': 2,
        'local': jsonEncode(local),
        'mapping': {path: asset},
      }),
    );
    var applied = false;
    await sync.synchronize(local, (packs) async {
      applied = true;
      expect(
        await File((packs.single['images'] as List).single as String).exists(),
        true,
      );
      return true;
    });
    expect(applied, true);
    expect(cloud.writes, 0);
  });
  test(
    'explicit keep-both resolves conflict using latest remote revision',
    () async {
      const second = '22345678-1234-4234-8234-123456789012';
      final localFile = await File('${dir.path}/local.image')
          .writeAsBytes([4, 5, 6]);
      final cloud = Cloud(
        StickerLibrarySnapshot(3, [
          StickerPack('favorites', [asset]),
        ]),
      );
      final sync = StickerLibrarySync(cloud, dir);
      addTearDown(sync.dispose);
      await File('${dir.path}/cloud.json').writeAsString(
        jsonEncode({
          'revision': 2,
          'local': 'old',
          'mapping': {localFile.path: second},
        }),
      );
      await sync.synchronize(
        [
          {
            'name': 'favorites',
            'images': [localFile.path],
          },
        ],
        (packs) async {
          expect((packs.single['images'] as List).length, 2);
          return true;
        },
        combine: true,
      );
      expect(cloud.snapshot.revision, 4);
      expect(cloud.snapshot.packs.single.assets, [asset, second]);
    },
  );
  test('keep-both deduplicates assets and retains differently named packs', () {
    final merged = combineStickerPacks(
      [
        StickerPack('favorites', [asset]),
        StickerPack('remote', [asset]),
      ],
      [
        StickerPack('local favorites', [asset]),
        StickerPack('local', [asset]),
      ],
    );
    expect(merged.map((p) => p.name), ['favorites', 'remote', 'local']);
    expect(merged.first.assets, [asset]);
  });
  test(
    'new device restores cloud files and commits baseline after local apply',
    () async {
      final cloud = Cloud(
        StickerLibrarySnapshot(2, [
          StickerPack('favorites', [asset]),
        ]),
      );
      final sync = StickerLibrarySync(cloud, dir);
      addTearDown(sync.dispose);
      await sync.synchronize(
        [
          {'name': 'favorites', 'images': <String>[]},
        ],
        (packs) async {
          final file = File((packs.first['images'] as List).single as String);
          expect(await file.readAsBytes(), [1, 2, 3]);
          return true;
        },
      );
      expect(cloud.writes, 0);
      expect(
        jsonDecode(
          await File('${dir.path}/cloud.json').readAsString(),
        )['revision'],
        2,
      );
    },
  );
  test('both devices edited does not overwrite either library', () async {
    final cloud = Cloud(
      StickerLibrarySnapshot(3, [
        StickerPack('remote', [asset]),
      ]),
    );
    final sync = StickerLibrarySync(cloud, dir);
    addTearDown(sync.dispose);
    await File(
      '${dir.path}/cloud.json',
    ).writeAsString(jsonEncode({'revision': 2, 'local': 'old', 'mapping': {}}));
    await expectLater(
      sync.synchronize([
        {'name': 'local', 'images': <String>[]},
      ], (_) async => throw StateError('must not apply')),
      throwsStateError,
    );
    expect(cloud.writes, 0);
    expect(
      jsonDecode(
        await File('${dir.path}/cloud.json').readAsString(),
      )['revision'],
      2,
    );
  });
  test('local deletion writes empty library with expected revision', () async {
    final cloud = Cloud(
      StickerLibrarySnapshot(2, [
        StickerPack('favorites', [asset]),
      ]),
    );
    final sync = StickerLibrarySync(cloud, dir);
    addTearDown(sync.dispose);
    await File(
      '${dir.path}/cloud.json',
    ).writeAsString(jsonEncode({'revision': 2, 'local': 'old', 'mapping': {}}));
    await sync.synchronize([
      {'name': 'favorites', 'images': <String>[]},
    ], (_) async => true);
    expect(cloud.writes, 1);
    expect(cloud.snapshot.packs.single.assets, isEmpty);
  });
  test('new local edit during restore prevents baseline acceptance', () async {
    final cloud = Cloud(
      StickerLibrarySnapshot(2, [
        StickerPack('favorites', [asset]),
      ]),
    );
    final sync = StickerLibrarySync(cloud, dir);
    addTearDown(sync.dispose);
    await sync.synchronize([
      {'name': 'favorites', 'images': <String>[]},
    ], (_) async => false);
    expect(await File('${dir.path}/cloud.json').exists(), false);
  });
}
