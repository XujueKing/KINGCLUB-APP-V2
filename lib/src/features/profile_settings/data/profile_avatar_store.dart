import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class ProfileAvatarStore {
  Future<String?> load();

  Future<String> persist(String sourcePath);
}

class LocalProfileAvatarStore implements ProfileAvatarStore {
  LocalProfileAvatarStore._();

  static final instance = LocalProfileAvatarStore._();

  @override
  Future<String?> load() async {
    final file = await _avatarFile();
    return await file.exists() ? file.path : null;
  }

  @override
  Future<String> persist(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('头像文件不存在');
    }

    final target = await _avatarFile();
    if (source.absolute.path == target.absolute.path) return target.path;

    await target.parent.create(recursive: true);
    final staging = File('${target.path}.staging');
    if (await staging.exists()) await staging.delete();
    await source.copy(staging.path);
    if (await target.exists()) await target.delete();
    await staging.rename(target.path);
    return target.path;
  }

  Future<File> _avatarFile() async {
    final root = await getApplicationSupportDirectory();
    return File(
      '${root.path}${Platform.pathSeparator}profile'
      '${Platform.pathSeparator}avatar.png',
    );
  }
}
