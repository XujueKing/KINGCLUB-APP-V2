import 'dart:typed_data';

/// Strip M4A metadata in place without changing AAC packets or chunk offsets.
/// Unsupported containers use the existing server normalization path.
Uint8List? canonicalVoiceContainer(Uint8List input) {
  if (input.length < 16 || input.length > 2 * 1024 * 1024) return null;
  final out = Uint8List.fromList(input), data = ByteData.sublistView(input);
  var boxes = 0, tracks = 0, media = 0, types = 0;
  const layouts = <String, List<String>>{
    'root': ['ftyp', 'moov', 'mdat'],
    'moov': ['mvhd', 'trak'],
    'trak': ['tkhd', 'edts', 'mdia'],
    'edts': ['elst'],
    'mdia': ['mdhd', 'hdlr', 'minf'],
    'minf': ['smhd', 'dinf', 'stbl'],
    'dinf': ['dref'],
    'stbl': [
      'stsd',
      'stts',
      'stsc',
      'stsz',
      'stco',
      'co64',
      'stss',
      'ctts',
      'sgpd',
      'sbgp',
    ],
    'stsd': ['mp4a'],
    'mp4a': ['esds', 'btrt'],
    'dref': ['url '],
  };
  String tag(int offset) =>
      String.fromCharCodes(input.sublist(offset, offset + 4));
  void walk(int start, int end, String parent, int depth) {
    if (depth > 9) throw const FormatException();
    var offset = start;
    while (offset < end) {
      if (++boxes > 4096 || offset + 8 > end) throw const FormatException();
      var size = data.getUint32(offset), header = 8;
      final type = tag(offset + 4);
      if (size == 1) {
        if (offset + 16 > end || data.getUint32(offset + 8) != 0) {
          throw const FormatException();
        }
        size = data.getUint32(offset + 12);
        header = 16;
      }
      if (size == 0) size = end - offset;
      if (size < header || size > end - offset) throw const FormatException();
      final body = offset + header,
          stop = offset + size,
          length = size - header;
      if (['free', 'skip', 'wide', 'udta', 'meta'].contains(type)) {
        out.setRange(offset + 4, offset + 8, 'free'.codeUnits);
        out.fillRange(body, stop, 0);
      } else {
        if (!(layouts[parent]?.contains(type) ?? false)) {
          throw const FormatException();
        }
        if (type == 'trak') tracks++;
        if (type == 'mdat') media++;
        if (type == 'ftyp') {
          types++;
          if (length < 8 || length % 4 != 0) throw const FormatException();
          for (var p = body; p < stop; p += 4) {
            if (p == body + 4) continue;
            if (![
              'M4A ',
              'isom',
              'iso2',
              'mp41',
              'mp42',
              '3gp4',
              '3gp5',
            ].contains(tag(p))) {
              throw const FormatException();
            }
          }
        } else if (['mvhd', 'tkhd', 'mdhd'].contains(type)) {
          if (length < 4 || input[body] > 1) throw const FormatException();
          final n = input[body] == 1 ? 16 : 8;
          if (length < 4 + n) throw const FormatException();
          out.fillRange(body + 4, body + 4 + n, 0);
        } else if (type == 'hdlr') {
          if (length < 24 || tag(body + 8) != 'soun') {
            throw const FormatException();
          }
          out.fillRange(body + 24, stop, 0);
        } else if (type == 'url ') {
          if (length != 4 || data.getUint32(body) != 1) {
            throw const FormatException();
          }
        } else if (type == 'stsd' || type == 'dref') {
          if (length < 8 ||
              data.getUint32(body) != 0 ||
              data.getUint32(body + 4) != 1) {
            throw const FormatException();
          }
          walk(body + 8, stop, type, depth + 1);
        } else if (type == 'mp4a') {
          if (length < 28 || data.getUint16(body + 8) != 0) {
            throw const FormatException();
          }
          walk(body + 28, stop, type, depth + 1);
        } else if (layouts.containsKey(type)) {
          walk(body, stop, type, depth + 1);
        }
      }
      offset = stop;
    }
  }

  try {
    walk(0, out.length, 'root', 0);
    return types == 1 && tracks == 1 && media == 1 ? out : null;
  } on FormatException {
    return null;
  }
}
