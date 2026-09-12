import 'package:flutter/foundation.dart';

import '../../../core/session/member_qr_memory.dart';

import 'dart:convert';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'dart:io';

import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../../core/media/media_cache.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';

class ProfileRepository {
  static final changes = ValueNotifier<int>(0);
  final _client = KingclubSecureClient(kingclubApiBaseUrl);
  Future<Map<String, dynamic>> call(
    String id,
    Map<String, dynamic> params,
  ) async {
    final session = await SecureSessionStore().readSession();
    if (session == null) throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    final data = await _client.call(id, params, session: session);
    return Map<String, dynamic>.from(data['result'] as Map);
  }

  Future<Map<String, dynamic>> load() async {
    final generation = MemberQrMemory.generation;
    final result = await call('K260912000501', {});
    if (generation == MemberQrMemory.generation) {
      MemberQrMemory.profile = result;
    }
    return result;
  }

  Future<Map<String, dynamic>> memberQr() {
    final cached = MemberQrMemory.valid;
    if (cached != null && (cached['ttlSeconds'] as int) > 60) {
      return Future.value(cached);
    }
    return MemberQrMemory.pending ??= _fetchQr();
  }

  Future<Map<String, dynamic>> _fetchQr() async {
    final generation = MemberQrMemory.generation;
    final elapsed = Stopwatch()..start();
    try {
      final result = await call('K260912000506', {});
      if (generation != MemberQrMemory.generation) throw StateError('会话已变化');
      final adjusted = {
        ...result,
        'ttlSeconds':
            ((result['ttlSeconds'] as num).toInt() - elapsed.elapsed.inSeconds)
                .clamp(0, 600),
      };
      MemberQrMemory.put(adjusted);
      return adjusted;
    } finally {
      if (generation == MemberQrMemory.generation) {
        MemberQrMemory.pending = null;
      }
    }
  }

  Future<Map<String, dynamic>> save(
    int version,
    String requestId,
    Map<String, dynamic> patch,
  ) async {
    final result = await call('K260912000502', {
      'version': version,
      'requestId': requestId,
      'patch': patch,
    });
    changes.value++;
    return result;
  }

  Future<Map<String, dynamic>> content(String category, int offset) =>
      call('K260912000504', {'category': category, 'offset': offset});
  Future<String> upload(String slot, String path) async {
    Uint8List? bytes;
    for (final size in [1200, 960, 720]) {
      bytes = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: size,
        minHeight: size,
        quality: size == 720 ? 76 : 85,
        keepExif: false,
      );
      if (bytes != null && bytes.length <= 800000) break;
    }
    if (bytes == null || bytes.length > 800000) {
      throw StateError('图片无法压缩，请选择其他图片');
    }
    final result = await call('K260912000505', {
      'slot': slot,
      'base64': base64Encode(bytes),
    });
    return result['fileId'] as String;
  }

  Future<File?> image(Map? ref) async {
    if (ref == null) return null;
    final session = await SecureSessionStore().readSession();
    final account = (session?['account'] as Map?)?['userAccount'];
    if (account == null) throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    return MediaCache.shared.get(
      '$kingclubApiBaseUrl${ref['path']}',
      scope: 'member:$account',
      contentKey: 'profile:${ref['fileId']}',
    );
  }
}
