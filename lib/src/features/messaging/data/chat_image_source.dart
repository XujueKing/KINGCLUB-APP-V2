import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Compress static camera/photos before hashing, encrypting and retaining them.
/// GIF/WebP keep their existing path so animated input is never flattened here.
Future<Uint8List> prepareChatImageSource(Uint8List input) async {
  if (!Platform.isAndroid) return input;
  final jpeg = input.length > 2 && input[0] == 0xff && input[1] == 0xd8;
  final png =
      input.length > 8 &&
      input[0] == 0x89 &&
      input[1] == 0x50 &&
      input[2] == 0x4e &&
      input[3] == 0x47;
  if (!jpeg && !png) return input;
  if (png) {
    final data = ByteData.sublistView(input);
    for (var offset = 8; offset + 12 <= input.length;) {
      final length = data.getUint32(offset);
      if (length > input.length - offset - 12) break;
      if (String.fromCharCodes(input.sublist(offset + 4, offset + 8)) == 'acTL') {
        return input;
      }
      offset += length + 12;
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(input);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width, height = descriptor.height;
    if (width * height > 32000000) throw const FormatException('图片像素过大');
    final longest = width > height ? width : height;
    final scale = longest > 2560 ? 2560 / longest : 1.0;
    final result = await FlutterImageCompress.compressWithList(
      input,
      minWidth: (width * scale).round().clamp(1, 2560),
      minHeight: (height * scale).round().clamp(1, 2560),
      quality: 85,
      format: CompressFormat.webp,
      keepExif: false,
    );
    if (result.isEmpty || result.length > 20 * 1024 * 1024) {
      throw const FormatException('图片压缩失败');
    }
    return result;
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}
