// Independent native document-provider probe. Build only with --flavor filetest.
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_exporter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: ExportProbe()));
}

class ExportProbe extends StatefulWidget {
  const ExportProbe({super.key});
  @override
  State<ExportProbe> createState() => _ExportProbeState();
}

class _ExportProbeState extends State<ExportProbe> {
  String status = '独立文件保存测试：仅生成测试数据';
  bool busy = false;
  final exporter = ChatFileExporter();
  Future<void> run() async {
    if (busy) return;
    setState(() {
      busy = true;
      status = '准备测试文件';
    });
    Directory? directory;
    try {
      directory = await (await getTemporaryDirectory()).createTemp(
        'kingclub-chat-download-',
      );
      final file = File('${directory.path}/content.bin');
      final out = await file.open(mode: FileMode.write);
      final hash = const DartSha256().newHashSink();
      const size = 8 * 1024 * 1024 + 17;
      try {
        for (var position = 0; position < size;) {
          final length = (size - position).clamp(0, 65536);
          final bytes = Uint8List.fromList(
            List.generate(length, (i) => (position + i) % 251),
          );
          hash.add(bytes);
          await out.writeFrom(bytes);
          position += length;
        }
      } finally {
        await out.close();
      }
      hash.close();
      final digest = (await hash.hash()).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      var authorizations = 0;
      final saved = await exporter.save(
        file,
        ChatFileReference(
          messageId: 'synthetic',
          assetId: 'synthetic',
          fileName: 'kingclub-export-probe.bin',
          size: size,
          sha256: digest,
        ),
        () async {
          authorizations++;
        },
      );
      if (saved && authorizations != 2) throw StateError('Authorization order');
      final marker = saved ? 'SAVED_SIZE_${size}_SHA256_$digest' : 'CANCELLED';
      debugPrint('KINGCLUB_FILE_PROBE_$marker');
      if (mounted) setState(() => status = marker);
    } catch (_) {
      debugPrint('KINGCLUB_FILE_PROBE_FAILED');
      if (mounted) setState(() => status = 'FAILED');
    } finally {
      if (directory != null) await directory.delete(recursive: true);
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    exporter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('KINGCLUB 文件测试')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: busy ? null : run,
              child: const Text('保存测试文件'),
            ),
          ],
        ),
      ),
    ),
  );
}
