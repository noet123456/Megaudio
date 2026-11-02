// Dump FLAC metadata block headers of a file: block types + lengths.
// Usage: dart run tools/flac_dump.dart <file.flac>
import 'dart:io';
import 'dart:typed_data';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('usage: dart run tools/flac_dump.dart <file.flac>');
    exit(1);
  }
  final f = File(args[0]);
  final raf = await f.open();
  try {
    final magic = await raf.read(4);
    print('magic: ${String.fromCharCodes(magic)}');
    if (String.fromCharCodes(magic) != 'fLaC') {
      print('NOT A FLAC FILE');
      return;
    }
    const typeNames = {
      0: 'STREAMINFO',
      1: 'PADDING',
      2: 'APPLICATION',
      3: 'SEEKTABLE',
      4: 'VORBIS_COMMENT',
      5: 'CUESHEET',
      6: 'PICTURE',
    };
    for (var i = 0; i < 40; i++) {
      final h = await raf.read(4);
      if (h.length < 4) break;
      final isLast = (h[0] & 0x80) != 0;
      final type = h[0] & 0x7F;
      final len = (h[1] << 16) | (h[2] << 8) | h[3];
      print(
          'block #$i: type=$type (${typeNames[type] ?? '?'}) len=$len last=$isLast');
      if (type == 4 && len < 4096) {
        final body = await raf.read(len);
        print('  vorbis raw: ${_preview(body, 400)}');
        continue;
      }
      if (isLast) break;
      await raf.setPosition(await raf.position() + len);
    }
  } finally {
    await raf.close();
  }
}

String _preview(Uint8List b, int n) {
  final s = String.fromCharCodes(b.take(n).map((c) => c < 32 ? 0x2022 : c));
  return s;
}
