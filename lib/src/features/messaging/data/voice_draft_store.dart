import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/session/secure_session_store.dart';
import '../../../core/session/member_qr_memory.dart';

class VoiceDraftStore {
  VoiceDraftStore({required Directory root, required String account})
    : directory = Directory(
        p.join(
          root.path,
          'voice_drafts',
          'accounts',
          base64Url.encode(utf8.encode(account)).replaceAll('=', ''),
        ),
      ) {
    if (account.isEmpty) throw ArgumentError('Missing account');
  }
  final Directory directory;
  static Future<VoiceDraftStore> current() async {
    final generation = MemberQrMemory.generation;
    final session = await SecureSessionStore().readSession();
    final account = (session?['account'] as Map?)?['userAccount'];
    if (account is! String || account.isEmpty) throw StateError('请先登录');
    final root = await getApplicationSupportDirectory();
    if (generation != MemberQrMemory.generation) throw StateError('登录状态已变化');
    return VoiceDraftStore(root: root, account: account);
  }

  bool owns(String path) =>
      p.equals(p.dirname(p.absolute(path)), directory.absolute.path) &&
      p.extension(path) == '.m4a';
  Future<String> allocate() async {
    await directory.create(recursive: true);
    return p.join(
      directory.path,
      '${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
  }

  Future<List<File>> list() async {
    if (!await directory.exists()) return [];
    final files = await directory
        .list(followLinks: false)
        .where((entry) => entry is File && owns(entry.path))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}
