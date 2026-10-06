import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const updateManifestUrl = String.fromEnvironment(
  'KINGCLUB_UPDATE_MANIFEST',
  defaultValue: 'https://test.wuyexin.cn/kingclub-updates/preview.json',
);

class AppRelease {
  AppRelease(
    this.build,
    this.version,
    this.url,
    this.notes,
    this.bytes,
    this.sha256,
  );
  final int build, bytes;
  final String version, url, sha256;
  final List<String> notes;

  static AppRelease? parse(Map<String, dynamic> manifest, String platform) {
    if (manifest['schema'] != 1) throw const FormatException('schema');
    final value = manifest[platform];
    if (value == null) return null;
    final data = Map<String, dynamic>.from(value as Map);
    final build = data['build'];
    final version = data['version'];
    final url = Uri.tryParse(data['url'] as String? ?? '');
    final notes = data['notes'];
    if (build is! int ||
        build <= 0 ||
        version is! String ||
        version.isEmpty ||
        url == null ||
        url.scheme != 'https' ||
        url.userInfo.isNotEmpty ||
        url.port != 443 ||
        notes is! List ||
        notes.length != 4 ||
        notes.any((n) => n is! String)) {
      throw const FormatException('release');
    }
    final isAndroid = platform == 'android';
    if (isAndroid
        ? url.host != 'test.wuyexin.cn' ||
              !url.path.startsWith('/kingclub-updates/') ||
              !url.path.endsWith('.apk')
        : !((url.host == 'testflight.apple.com' &&
                  url.path.startsWith('/join/')) ||
              url.host == 'apps.apple.com')) {
      throw const FormatException('url');
    }
    final bytes = data['bytes'] ?? 0;
    final sha = data['sha256'] ?? '';
    if (isAndroid &&
        (bytes is! int ||
            bytes <= 0 ||
            bytes > 600 * 1024 * 1024 ||
            sha is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha))) {
      throw const FormatException('integrity');
    }
    return AppRelease(
      build,
      version,
      url.toString(),
      List<String>.from(notes),
      isAndroid ? bytes as int : 0,
      isAndroid ? sha as String : '',
    );
  }
}

/// Quiet startup check; presentation and installation only follow a user action.
class AppUpdates extends ChangeNotifier {
  static final shared = AppUpdates();
  static const native = MethodChannel('kingclub/app-update');
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: false,
    ),
  );
  AppRelease? release;
  int installedBuild = 0;
  String installedVersion = '';
  bool checking = false, failed = false, checked = false;
  bool get available => release != null && release!.build > installedBuild;
  bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> check() async {
    if (!supported || checking) return;
    checking = true;
    failed = false;
    notifyListeners();
    try {
      final info = await const MethodChannel('kingclub/app-version')
          .invokeMapMethod<String, String>('read');
      installedBuild = int.parse(info!['build']!);
      installedVersion = '${info['version']} ($installedBuild)';
      final response = await _dio.get<Map<String, dynamic>>(
        updateManifestUrl,
        options: Options(headers: {'Cache-Control': 'no-cache'}),
      );
      release = AppRelease.parse(
        response.data!,
        Platform.isAndroid ? 'android' : 'ios',
      );
      checked = true;
    } catch (_) {
      failed = true;
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  Future<String> download(
    AppRelease target,
    CancelToken cancel,
    void Function(int, int) progress,
  ) async {
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/app-updates',
    );
    await directory.create(recursive: true);
    final file = File('${directory.path}/update.apk');
    try {
      await _dio.download(
        target.url,
        file.path,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (received > target.bytes) cancel.cancel('size');
          progress(received, target.bytes);
        },
      );
      if (await file.length() != target.bytes) {
        throw const FormatException('size');
      }
      await native.invokeMethod('verify', {
        'path': file.path,
        'sha256': target.sha256,
        'build': target.build,
      });
      return file.path;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }
}
