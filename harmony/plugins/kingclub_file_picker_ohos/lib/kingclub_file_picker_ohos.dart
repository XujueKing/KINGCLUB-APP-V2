import 'package:flutter/services.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

class KingclubFilePickerOhos extends FilePickerPlatform {
  static const _channel = MethodChannel('com.lingmei.kingclub/file_picker');
  static void registerWith() => FilePickerPlatform.instance = KingclubFilePickerOhos();
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle, String? initialDirectory,
    FileType type = FileType.any, List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading, int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (type != FileType.any || (allowedExtensions?.isNotEmpty ?? false) || compressionQuality != 0) {
      throw UnsupportedError('This Harmony adapter supports uncompressed single documents only');
    }
    onFileLoading?.call(FilePickerStatus.picking);
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('pickFile');
      if (result == null) return null;
      final path = result['path'] as String;
      final name = result['name'] as String;
      final size = (result['size'] as num).toInt();
      if (!path.startsWith('/') || name.isEmpty || size < 0 || size > 268435456) {
        throw const FormatException('Invalid picked file');
      }
      return OhosPickedFile(path, name, size);
    } finally { onFileLoading?.call(FilePickerStatus.done); }
  }
}
final class OhosPickedFile extends PlatformFile {
  OhosPickedFile(String path, this.name, this._size) : xFile = XFile(path, name: name);
  @override final String name;
  final int _size;
  @override final XFile xFile;
  @override Uri get uri => Uri.file(xFile.path);
  @override int lengthSync() => _size;
  @override Future<int> length() => xFile.length();
  @override Future<Uint8List> readAsBytes() => xFile.readAsBytes();
  @override Stream<Uint8List> readAsByteStream() => xFile.openRead().map(Uint8List.fromList);
}
