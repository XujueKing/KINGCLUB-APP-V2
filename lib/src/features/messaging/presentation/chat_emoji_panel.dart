import '../data/messaging_repository.dart';
import '../data/sticker_library_repository.dart';
import '../data/sticker_library_sync.dart';

import 'package:cryptography/dart.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/design_system/king_notice.dart';
import '../../../core/session/secure_session_store.dart';
import 'legacy_emoji_data.dart';
import 'legacy_messaging_components.dart';

/// Local-first sticker library. Chat transport remains owned by the caller.
class ChatEmojiPanel extends StatefulWidget {
  const ChatEmojiPanel({
    super.key,
    required this.onEmoji,
    required this.onSticker,
    required this.onDelete,
    required this.onSend,
    this.account,
    this.repository,
    this.libraryDirectory,
    this.pickImages,
  });
  final String? account;
  final MessagingRepository? repository;
  final Future<List<XFile>> Function()? pickImages;
  final Future<Directory> Function(String? account)? libraryDirectory;
  final ValueChanged<String> onEmoji;
  final ValueChanged<String> onSticker;
  final VoidCallback onDelete;
  final VoidCallback onSend;

  @override
  State<ChatEmojiPanel> createState() => _ChatEmojiPanelState();
}

class _ChatEmojiPanelState extends State<ChatEmojiPanel> {
  final List<List<String>> _images = [[]];
  final List<String> _names = ['添加的单个表情'];
  Future<void>? _load;
  StickerLibrarySync? _cloud;
  bool _syncing = false;
  bool _syncAgain = false;
  int _epoch = 0;
  bool _invalid = false;
  StreamSubscription<void>? _session;
  bool _current(int epoch) => mounted && !_invalid && epoch == _epoch;
  int _category = 0;
  int _page = 0;
  bool _importing = false;

  Future<Directory> _directory() async {
    final account = widget.account;
    if (widget.libraryDirectory != null) {
      return widget.libraryDirectory!(account);
    }
    final root = await getApplicationDocumentsDirectory();
    final hash = (await const DartSha256().hash(
      utf8.encode(jsonEncode(['sticker-library-v1', account])),
    )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return Directory('${root.path}/chat_stickers/$hash')
        .create(recursive: true);
  }

  Future<void> _restore() async {
    final epoch = _epoch;
    try {
      final directory = await _directory();
      final file = File('${directory.path}/library.json');
      if (!await file.exists()) return;
      final records = jsonDecode(await file.readAsString()) as List;
      final names = <String>[];
      final images = <List<String>>[];
      for (final record in records) {
        final paths = (record['images'] as List)
            .cast<String>()
            .where(
              (path) =>
                  File(path).parent.absolute.path == directory.absolute.path,
            )
            .toList();
        if (names.isNotEmpty && paths.isEmpty) continue;
        names.add(record['name'] as String);
        images.add(paths);
      }
      if (_current(epoch) && names.isNotEmpty) {
        _names
          ..clear()
          ..addAll(names);
        _images
          ..clear()
          ..addAll(images);
      }
    } catch (_) {
      // A missing plugin in widget tests or unavailable local storage must not
      // prevent the built-in emoji categories from opening immediately.
    }
  }

  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      if (!mounted || widget.account == null) return;
      setState(() {
        _invalid = true;
        _epoch++;
        _images
          ..clear()
          ..add([]);
        _names
          ..clear()
          ..add('添加的单个表情');
        _category = 0;
        _page = 0;
      });
    });
    (_load ??= _restore()).then((_) {
      if (mounted) setState(() {});
      unawaited(_syncCloud());
    });
  }

  @override
  void didUpdateWidget(covariant ChatEmojiPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) {
      _epoch++;
      _cloud?.dispose();
      _cloud = null;
      _invalid = false;
      _names
        ..clear()
        ..add('添加的单个表情');
      _images
        ..clear()
        ..add([]);
      _category = 0;
      _page = 0;
      _importing = false;
      final epoch = _epoch;
      _load = _restore().then((_) {
        if (_current(epoch)) setState(() {});
        unawaited(_syncCloud());
      });
    }
  }

  @override
  void dispose() {
    _session?.cancel();
    _cloud?.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _localPacks() => [
    for (var i = 0; i < _names.length; i++)
      {'name': _names[i], 'images': List<String>.of(_images[i])},
  ];
  Future<void> _syncCloud({bool notify = false}) async {
    final repository = widget.repository;
    if (!mounted ||
        _invalid ||
        _importing ||
        repository == null ||
        repository.account != widget.account) {
      return;
    }
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    final epoch = _epoch;
    final local = _localPacks(), signature = jsonEncode(_localPacks());
    try {
      final directory = await _directory();
      if (!_current(epoch)) return;
      final sync = _cloud ??= StickerLibrarySync(
        StickerLibraryRepository(repository),
        directory,
      );
      await sync.synchronize(local, (next) async {
        if (!_current(epoch) ||
            _importing ||
            jsonEncode(_localPacks()) != signature) {
          _syncAgain = true;
          return false;
        }
        setState(() => _importing = true);
        try {
          final file = File('${directory.path}/library.json');
          final temp = File('${file.path}.cloud.tmp');
          await temp.writeAsString(jsonEncode(next), flush: true);
          if (!_current(epoch)) return false;
          await temp.rename(file.path);
          if (!_current(epoch)) return false;
          setState(() {
            _names
              ..clear()
              ..addAll(next.map((p) => p['name'] as String));
            _images
              ..clear()
              ..addAll(next.map((p) => (p['images'] as List).cast<String>()));
            if (_category > _names.length + 2) _category = 3;
            _page = 0;
          });
          return true;
        } finally {
          if (_current(epoch)) setState(() => _importing = false);
        }
      });
    } catch (_) {
      if (mounted && notify && _current(epoch)) {
        KingNotice.of(context).show('表情已保留在本机，云同步暂未完成');
      }
    } finally {
      _syncing = false;
      if (_syncAgain) {
        _syncAgain = false;
        if (mounted && !_invalid) unawaited(_syncCloud());
      }
    }
  }

  Future<void> _add({required bool pack}) async {
    if (_importing || _invalid) return;
    final epoch = _epoch;
    final copied = <File>[];
    File? journal;
    var committed = false;
    setState(() => _importing = true);
    try {
      final selected =
          await (widget.pickImages?.call() ?? ImagePicker().pickMultiImage());
      if (selected.isEmpty || !mounted || !_current(epoch)) return;
      String? name;
      if (pack) {
        name = await showDialog<String>(
          context: context,
          builder: (context) {
            var value = '';
            return AlertDialog(
              backgroundColor: const Color(0xFF202020),
              title: const Text('添加表情包'),
              content: TextField(
                autofocus: true,
                maxLength: 20,
                decoration: const InputDecoration(hintText: '表情包名称'),
                onChanged: (text) => value = text.trim(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    if (value.isNotEmpty) Navigator.pop(context, value);
                  },
                  child: const Text('添加'),
                ),
              ],
            );
          },
        );
        if (name == null || !_current(epoch)) return;
      }
      await (_load ??= _restore());
      if (!_current(epoch)) return;
      final directory = await _directory();
      if (!_current(epoch)) return;
      final paths = <String>[];
      final batch = DateTime.now().microsecondsSinceEpoch;
      for (var i = 0; i < selected.length; i++) {
        if (!_current(epoch)) return;
        final size = await selected[i].length();
        if (size <= 0 || size > 20 * 1024 * 1024) {
          throw StateError('表情文件须不超过20MB');
        }
        if (!_current(epoch)) return;
        final path = '${directory.path}/$batch-$i.image';
        copied.add(File(path));
        await selected[i].saveTo(path);
        paths.add(path);
      }
      if (!_current(epoch)) return;
      final nextNames = [..._names];
      final nextImages = _images.map((images) => [...images]).toList();
      if (pack) {
        nextNames.add(name!);
        nextImages.add(paths);
      } else {
        nextImages[0].addAll(paths);
      }
      final file = File('${directory.path}/library.json');
      final temp = journal = File('${file.path}.$batch.tmp');
      await temp.writeAsString(
        jsonEncode([
          for (var i = 0; i < nextNames.length; i++)
            {'name': nextNames[i], 'images': nextImages[i]},
        ]),
        flush: true,
      );
      if (!_current(epoch)) return;
      await temp.rename(file.path);
      committed = true;
      if (!_current(epoch)) return;
      _names
        ..clear()
        ..addAll(nextNames);
      _images
        ..clear()
        ..addAll(nextImages);
      if (_current(epoch)) {
        setState(() => _category = pack ? _names.length + 2 : 3);
      }
    } catch (_) {
      if (mounted && _current(epoch)) {
        KingNotice.of(context).show('添加失败，请检查相册权限后重试');
      }
    } finally {
      if (!committed) {
        for (final file in [...copied, ?journal]) {
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
      }
      if (_current(epoch)) {
        setState(() => _importing = false);
        unawaited(_syncCloud(notify: true));
      }
    }
  }

  Future<void> _remove(int library, {String? path}) async {
    if (_importing || _invalid) return;
    final epoch = _epoch;
    setState(() => _importing = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF202020),
          title: Text(path == null ? '删除表情包' : '删除表情'),
          content: const Text('从本机收藏中删除，已发送的消息不受影响。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true || !_current(epoch)) return;
      final directory = await _directory();
      if (!_current(epoch)) return;
      final names = [..._names];
      final images = _images.map((items) => [...items]).toList();
      final removed = path == null ? [...images[library]] : [path];
      if (path == null) {
        if (library == 0) return;
        names.removeAt(library);
        images.removeAt(library);
      } else {
        images[library].remove(path);
        if (library > 0 && images[library].isEmpty) {
          names.removeAt(library);
          images.removeAt(library);
        }
      }
      final file = File('${directory.path}/library.json');
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        jsonEncode([
          for (var i = 0; i < names.length; i++)
            {'name': names[i], 'images': images[i]},
        ]),
        flush: true,
      );
      if (!_current(epoch)) return;
      await temp.rename(file.path);
      if (!_current(epoch)) return;
      setState(() {
        _names
          ..clear()
          ..addAll(names);
        _images
          ..clear()
          ..addAll(images);
        _category = 3;
        _page = 0;
      });
      final retained = images.expand((items) => items).toSet();
      for (final oldPath in removed) {
        final oldFile = File(oldPath);
        if (retained.contains(oldPath) ||
            oldFile.parent.absolute.path != directory.absolute.path) {
          continue;
        }
        try {
          await oldFile.delete();
        } on FileSystemException {
          // The index is committed; an unavailable file must not undo removal.
        }
      }
    } catch (_) {
      if (mounted && _current(epoch)) KingNotice.of(context).show('删除失败，请重试');
    } finally {
      if (_current(epoch)) {
        setState(() => _importing = false);
        unawaited(_syncCloud(notify: true));
      }
    }
  }

  Widget _tab(int category, String label, Widget child) => Tooltip(
    message: label,
    child: InkWell(
      onLongPress: category > 3 && !_importing && !_invalid
          ? () => _remove(category - 3)
          : null,
      onTap: () => setState(() {
        _category = category;
        _page = 0;
      }),
      child: Container(
        width: 46,
        height: 42,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _category == category
              ? const Color(0xFF302C26)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    ),
  );

  Widget _image(String path) => Image.file(
    File(path),
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) =>
        const Icon(Icons.broken_image_outlined, color: legacyMessageGold),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 300,
    child: ColoredBox(
      color: legacyMessagePanel,
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    children: [
                      for (var i = 0; i < 3; i++)
                        _tab(
                          i,
                          ['表情', '动物', '食物'][i],
                          Text(
                            ['😀', '🐶', '🍏'][i],
                            style: const TextStyle(fontSize: 25),
                          ),
                        ),
                      _tab(
                        3,
                        '添加的单个表情',
                        const Icon(
                          Icons.favorite_border,
                          size: 25,
                          color: legacyMessageGold,
                        ),
                      ),
                      for (var i = 1; i < _names.length; i++)
                        _tab(
                          i + 3,
                          _names[i],
                          Padding(
                            padding: const EdgeInsets.all(5),
                            child: _image(_images[i].first),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '添加表情包',
                  onPressed: (_importing || _invalid)
                      ? null
                      : () => _add(pack: true),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    size: 24,
                    color: legacyMessageGold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: .5, color: Color(0x184F473D)),
          Expanded(child: _category < 3 ? _unicodeGrid() : _stickerGrid()),
        ],
      ),
    ),
  );

  Widget _unicodeGrid() {
    final emojis = legacyEmojiCategories[_category];
    final pages = (emojis.length / 29).ceil();
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            key: ValueKey('emoji-pages-$_category'),
            itemCount: pages,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, page) => LayoutBuilder(
              builder: (context, box) => Column(
                children: [
                  for (var row = 0; row < 4; row++)
                    SizedBox(
                      height: box.maxHeight / 4,
                      child: Row(
                        children: [
                          for (var col = 0; col < (row == 3 ? 5 : 8); col++)
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final index = page * 29 + row * 8 + col;
                                  return index < emojis.length
                                      ? InkWell(
                                          onTap: () =>
                                              widget.onEmoji(emojis[index]),
                                          child: Center(
                                            child: Text(
                                              emojis[index],
                                              style: const TextStyle(
                                                fontSize: 27,
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox();
                                },
                              ),
                            ),
                          if (row == 3) ...[
                            Expanded(
                              child: IconButton(
                                tooltip: '删除表情',
                                onPressed: widget.onDelete,
                                icon: const Icon(
                                  Icons.backspace_outlined,
                                  color: Color(0xFFAAAAAA),
                                  size: 21,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                ),
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D6646),
                                    foregroundColor: const Color(0xFFE1E8E2),
                                    minimumSize: const Size(0, 34),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  onPressed: widget.onSend,
                                  child: const Text('发送'),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < pages; i++)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? legacyMessageGold
                        : const Color(0xFF555555),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stickerGrid() {
    final index = _category - 3;
    final images = _images[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 7),
          child: Text(
            _names[index],
            style: const TextStyle(fontSize: 12, color: Color(0xFF8F8A82)),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: images.length + (index == 0 ? 1 : 0),
            itemBuilder: (context, item) {
              if (index == 0 && item == 0) {
                return InkWell(
                  key: const ValueKey('add-single-sticker'),
                  onTap: (_importing || _invalid)
                      ? null
                      : () => _add(pack: false),
                  child: CustomPaint(
                    painter: _DashedAddBorder(),
                    child: const Center(
                      child: Icon(
                        Icons.add,
                        size: 34,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ),
                );
              }
              final path = images[item - (index == 0 ? 1 : 0)];
              return InkWell(
                key: ValueKey('saved-sticker-$path'),
                onLongPress: _importing
                    ? null
                    : () => _remove(index, path: path),
                onTap: _invalid ? null : () => widget.onSticker(path),
                child: _image(path),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DashedAddBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
      );
    final paint = Paint()
      ..color = const Color(0xFF999999)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 10) {
        canvas.drawPath(metric.extractPath(start, start + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedAddBorder oldDelegate) => false;
}
