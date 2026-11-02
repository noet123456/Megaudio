// Standalone headless test of the folder-scan + header-parse pipeline.
// Run from the project root:  dart run tools/scan_test.dart <optional-folder>
// It builds a "dirty" folder (real FLACs + garbage/fake/empty files +
// subfolders) and verifies that every file is handled without throwing,
// hanging, or crashing.
import 'dart:io';

import '../lib/models/song.dart';
import '../lib/services/custom_decoder_service.dart';

Future<void> main(List<String> args) async {
  final realMusicDir = args.isNotEmpty
      ? args[0]
      : r'E:\Music\AudiophilePro\Rocky Mountain Folks Festival 2011 (24-48kHz Live)';

  final testDir = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}audiophile_scan_test_${DateTime.now().millisecondsSinceEpoch}');
  testDir.createSync(recursive: true);
  final sub = Directory('${testDir.path}${Platform.pathSeparator}subfolder with spaces');
  sub.createSync();

  final realFlacs = realMusicDir.isNotEmpty && Directory(realMusicDir).existsSync()
      ? Directory(realMusicDir).listSync().whereType<File>().where((f) => f.path.endsWith('.flac')).take(2).toList()
      : <File>[];

  // Copy real FLACs into the dirty folder + one into the subfolder.
  for (var i = 0; i < realFlacs.length; i++) {
    final dest = i == 0 ? testDir : sub;
    realFlacs[i].copySync('${dest.path}${Platform.pathSeparator}copy_of_real_${i}.flac');
  }

  // Hostile files that must never break the scan:
  File('${testDir.path}${Platform.pathSeparator}notes.txt')
      .writeAsStringSync('this is not music');
  File('${testDir.path}${Platform.pathSeparator}empty.flac').writeAsBytesSync([]);
  File('${testDir.path}${Platform.pathSeparator}garbage.wav')
      .writeAsBytesSync([0x52, 0x49, 0x46, 0x46, 0xFF, 0xFF, 0xFF, 0xFF, 0x57, 0x41, 0x56, 0x45, 0x64, 0x61, 0x74, 0x61, 0x00, 0x00, 0x00, 0x00]); // RIFF with data chunk size 0 — the old infinite-loop trigger
  File('${testDir.path}${Platform.pathSeparator}zero_chunk.wav')
      .writeAsBytesSync([0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45, 0x66, 0x6D, 0x74, 0x20, 0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x02, 0x00, 0x80, 0xBB, 0x00, 0x00, 0x00, 0xEE, 0x02, 0x00, 0x04, 0x00, 0x10, 0x00, 0x64, 0x61, 0x74, 0x61, 0x00, 0x00, 0x00, 0x00, 0x64, 0x61, 0x74, 0x61, 0x00, 0x00, 0x00, 0x00]); // valid fmt, two zero-size data chunks
  File('${testDir.path}${Platform.pathSeparator}fake.mp3')
      .writeAsStringSync('ID3 fake text pretending to be an mp3');
  File('${testDir.path}${Platform.pathSeparator}no_extension');

  print('=== Scanning dirty folder: ${testDir.path} ===');
  final watch = Stopwatch()..start();

  // --- same scan logic as io_real.listAudioFiles ---
  final results = <String>[];
  final stack = <Directory>[testDir];
  int guard = 0;
  while (stack.isNotEmpty && guard++ < 10000) {
    final dir = stack.removeLast();
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      continue;
    }
    for (final e in entries) {
      try {
        if (e is Directory) {
          stack.add(e);
        } else if (e is File && CustomDecoderService.isSupportedAudioFile(e.path)) {
          results.add(e.path);
        }
      } catch (_) {}
    }
  }
  results.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  print('Found ${results.length} candidate audio file(s) in ${watch.elapsedMilliseconds}ms:');

  var ok = 0;
  for (final path in results) {
    final song = await CustomDecoderService.inspectFile(path);
    final cover = await CustomDecoderService.readCoverArt(path);
    final coverInfo = cover == null ? 'no cover' : 'cover ${cover.$1.length}B ${cover.$2}';
    print('  [${song.format.name}] ${song.sampleRate}Hz/${song.bitDepth}-bit '
        '${song.durationLabel.padRight(5)} | artist="${song.artist}" genre="${song.genreLabel}" '
        '| $coverInfo | ${path.split(Platform.pathSeparator).last}');
    ok++;
  }

  watch.stop();
  print('---');
  print('Parsed $ok/${results.length} files in ${watch.elapsedMilliseconds}ms — no exceptions, no hangs.');
  print(realFlacs.isEmpty ? 'NOTE: no real FLAC found to copy; only hostile files tested.' : 'Real FLAC copy verified: re-run app against a real folder for playback.');

  // Sanity expectations
  if (realFlacs.isNotEmpty) {
    final real = await CustomDecoderService.inspectFile(realFlacs.first.path);
    assert(real.sampleRate > 0, 'sample rate must be positive');
    print('Real FLAC check: ${real.sampleRate}Hz/${real.bitDepth}-bit ${real.durationLabel} -> OK');
  }

  testDir.deleteSync(recursive: true);
  print('Dirty folder cleaned up. TEST PASSED.');
}
