// Verify tag parsing on original files (no copy/rename).
// Usage: dart run tools/tag_check.dart <file>
import 'dart:io';

import '../lib/models/song.dart';
import '../lib/services/custom_decoder_service.dart';

Future<void> main(List<String> args) async {
  final path = args.isNotEmpty
      ? args[0]
      : r'E:\Music\AudiophilePro\Rocky Mountain Folks Festival 2011 (24-48kHz Live)\Weir Robinson Greene - Peggy-O.flac';
  final song = await CustomDecoderService.inspectFile(path);
  print('title  : ${song.title}');
  print('artist : ${song.artist}');
  print('album  : ${song.album}');
  print('genre  : "${song.genre}"');
  print('specs  : ${song.specsLabel}');
  print('hires  : ${song.isHiRes}');
  final cover = await CustomDecoderService.readCoverArt(path);
  print('cover  : ${cover == null ? "none" : "${cover.$1.length}B ${cover.$2}"}');
}
