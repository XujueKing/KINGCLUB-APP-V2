import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class ProfileCoverStore {
  Future<String?> load();

  Future<String> persist(String sourcePath);
}

class LocalProfileCoverStore implements ProfileCoverStore {
  LocalProfileCoverStore._();

  static final instance = LocalProfileCoverStore._();

  static const _directoryName = 'profile';
  static const _fileName = 'cover.png';

  @override
  Future<String?> load() async {
    final file = await _coverFile();
    return await file.exists() ? file.path : null;
  }

  @override
  Future<String> persist(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('封面文件不存在');
    }

    final target = await _coverFile();
    if (source.absolute.path == target.absolute.path) return target.path;

    await target.parent.create(recursive: true);
    final staging = File('${target.path}.staging');
    if (await staging.exists()) await staging.delete();
    await source.copy(staging.path);
    if (await target.exists()) await target.delete();
    await staging.rename(target.path);
    return target.path;
  }

  Future<File> _coverFile() async {
    final root = await getApplicationSupportDirectory();
    return File(
      '${root.path}${Platform.pathSeparator}$_directoryName'
      '${Platform.pathSeparator}$_fileName',
    );
  }
}
