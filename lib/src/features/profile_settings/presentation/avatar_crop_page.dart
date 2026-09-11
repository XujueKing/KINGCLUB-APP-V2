import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/design_system/king_components.dart';

class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({required this.imagePath, super.key});

  final String imagePath;

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  static const _gold = Color(0xFFC9B69E);
  final _captureKey = GlobalKey();
  final _controller = TransformationController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: KingBackButton.leftOffset(context),
                    top: KingBackButton.safeAreaOffset.dy,
                    child: KingBackButton(
                      key: const ValueKey('avatar-crop-back'),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                  const Text(
                    '修改头像',
                    style: TextStyle(color: _gold, fontSize: 19),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF666666),
                    border: Border.all(
                      color: const Color(0x99C9B69E),
                      width: 2,
                    ),
                  ),
                  child: RepaintBoundary(
                    key: _captureKey,
                    child: ClipRect(
                      child: InteractiveViewer(
                        key: const ValueKey('avatar-crop-viewer'),
                        transformationController: _controller,
                        minScale: 1,
                        maxScale: 4,
                        child: SizedBox.expand(
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: _gold,
                                size: 50,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '拖动图片调整位置，双指缩放',
              style: TextStyle(color: Color(0xFFAAA096), fontSize: 14),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('avatar-crop-cancel'),
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        side: const BorderSide(color: Color(0x99C9B69E)),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('关闭'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const ValueKey('avatar-crop-confirm'),
                      onPressed: _saving ? null : _capture,
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: const Color(0xFF3A3025),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF3A3025),
                              ),
                            )
                          : const Text('确认修改'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capture() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('头像预览尚未就绪');
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('头像生成失败');
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'kingclub-avatar-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (mounted) Navigator.pop(context, file.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('头像调整失败，请重新选择图片。')));
    }
  }
}
