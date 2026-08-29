import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class CoverAdjustPage extends StatefulWidget {
  const CoverAdjustPage({required this.imagePath, super.key});

  final String imagePath;

  @override
  State<CoverAdjustPage> createState() => _CoverAdjustPageState();
}

class _CoverAdjustPageState extends State<CoverAdjustPage> {
  static const _gold = Color(0xFFC9B69E);
  final _captureKey = GlobalKey();
  final _transformationController = TransformationController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: _gold,
        centerTitle: true,
        title: const Text(
          '调整封面',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AspectRatio(
                aspectRatio: 2.1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    if (!_initialized) {
                      _initialized = true;
                      _transformationController.value = Matrix4.identity()
                        ..translateByDouble(-width * .2, -height * .2, 0, 1);
                    }
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: _gold, width: 1.5),
                      ),
                      child: RepaintBoundary(
                        key: _captureKey,
                        child: ClipRect(
                          child: InteractiveViewer(
                            key: const ValueKey('cover-adjust-viewer'),
                            transformationController: _transformationController,
                            constrained: false,
                            minScale: .72,
                            maxScale: 4,
                            boundaryMargin: const EdgeInsets.all(600),
                            child: SizedBox(
                              width: width * 1.4,
                              height: height * 1.4,
                              child: Image.file(
                                File(widget.imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Color(0xFF171411),
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: _gold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              '拖动图片调整位置，双指缩放',
              style: TextStyle(color: Color(0xFFB7ADA0), fontSize: 14),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('cover-adjust-cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        side: const BorderSide(color: Color(0x887E705E)),
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const ValueKey('cover-adjust-confirm'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: const Color(0xFF20170F),
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _saving ? null : _capture,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF20170F),
                              ),
                            )
                          : const Text(
                              '使用此封面',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
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
      if (boundary == null) throw StateError('封面预览尚未就绪');
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('封面生成失败');
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'kingclub-cover-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (mounted) Navigator.pop(context, file.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('封面调整失败，请重新选择图片。')));
    }
  }
}
