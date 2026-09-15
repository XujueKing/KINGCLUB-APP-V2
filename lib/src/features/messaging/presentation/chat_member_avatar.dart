import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/media/cached_media_image.dart';
import '../../auth/data/auth_repository_provider.dart';

/// Only a current authorized profile response can supply a private avatar.
class ChatMemberAvatar extends StatelessWidget {
  const ChatMemberAvatar({
    super.key,
    required this.profile,
    required this.account,
    this.own = false,
    this.size = 42,
    this.baseUrl = kingclubApiBaseUrl,
  });
  final Future<Map<String, dynamic>> profile;
  final String account;
  final bool own;
  final double size;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: Color(0xFF302D28),
      child: Center(
        child: Icon(Icons.person, size: 27, color: Color(0xFFC9B69E)),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: FutureBuilder<Map<String, dynamic>>(
          future: profile,
          builder: (context, snapshot) {
            final avatar = snapshot.connectionState == ConnectionState.done
                ? (snapshot.data?['avatar'])
                : null;
            if (avatar is! Map) return fallback;
            final path = avatar['path'];
            final fileId = avatar['fileId'];
            final cacheOnly = avatar['cacheOnly'] == true;
            final validPath =
                path is String &&
                (own
                    ? RegExp(
                        r'^/attachments/[A-Za-z0-9_-]+\?token=[A-Za-z0-9%._~-]+$',
                      ).hasMatch(path)
                    : path.startsWith('/kingclub/profile-media/') &&
                          !path.contains('..') &&
                          !path.contains('?') &&
                          !path.contains('#'));
            if ((!cacheOnly && !validPath) ||
                fileId is! String ||
                fileId.isEmpty ||
                baseUrl.isEmpty) {
              return fallback;
            }
            return CachedMediaImage(
              '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path',
              private: true,
              cacheOnly: cacheOnly,
              contentKey: 'profile:$account:$fileId',
              headers: (avatar['headers'] as Map? ?? {}).map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              ),
              width: size,
              height: size,
              placeholder: fallback,
              errorBuilder: (_, _, _) => fallback,
            );
          },
        ),
      ),
    );
  }
}

/// Reuse successful/in-flight profiles, but let a later rebuild retry a failure.
Future<Map<String, dynamic>> cachedChatAvatarProfile(
  Map<String, Future<Map<String, dynamic>>> cache,
  String account,
  Future<Map<String, dynamic>> Function() load,
) => cache.putIfAbsent(account, () {
  final future = Future<Map<String, dynamic>>.sync(load);
  unawaited(
    future.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        if (identical(cache[account], future)) cache.remove(account);
      },
    ),
  );
  return future;
});
