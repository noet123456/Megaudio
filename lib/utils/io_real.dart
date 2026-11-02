import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';
import '../services/custom_decoder_service.dart';

/// Native platforms can access the local file system library.
const bool kSupportsLocalLibrary = true;

bool folderExists(String folderPath) {
  try {
    return Directory(folderPath).existsSync();
  } catch (_) {
    return false;
  }
}

/// Recursively scans [folderPath] (including all subfolders) for supported
/// audio files, sorted by path. The folder may legally be empty or contain
/// unrelated files — anything unreadable is skipped, never thrown.
Future<List<String>> listAudioFiles(String folderPath) async {
  final results = <String>[];
  final stack = <Directory>[Directory(folderPath)];
  int guard = 0;
  const maxDirs = 10000;

  while (stack.isNotEmpty && guard++ < maxDirs) {
    final dir = stack.removeLast();
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      continue; // unreadable directory (permissions, locked, ...) — skip it
    }
    for (final e in entries) {
      try {
        if (e is Directory) {
          stack.add(e);
        } else if (e is File && CustomDecoderService.isSupportedAudioFile(e.path)) {
          results.add(e.path);
        }
      } catch (_) {
        continue;
      }
    }
  }

  results.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return results;
}

Future<Song?> inspectAudioFile(String path) async {
  try {
    return await CustomDecoderService.inspectFile(path);
  } catch (_) {
    return null;
  }
}

/// Reads embedded artwork bytes and persists them into the app temp dir.
Future<String?> extractCoverArtFile(String path) async {
  try {
    final pic = await CustomDecoderService.readCoverArt(path);
    if (pic == null || pic.$1.isEmpty) return null;
    return await _saveTempCover(pic.$1, pic.$2, path);
  } catch (_) {
    return null;
  }
}

Future<String> _saveTempCover(Uint8List data, String mime, String sourcePath) async {
  final dir = await getTemporaryDirectory();
  final String ext;
  if (mime.contains('png')) {
    ext = 'png';
  } else if (mime.contains('webp')) {
    ext = 'webp';
  } else if (mime.contains('gif')) {
    ext = 'gif';
  } else {
    ext = 'jpg';
  }
  final file = File('${dir.path}${Platform.pathSeparator}cover_${sourcePath.hashCode}.$ext');
  await file.writeAsBytes(data, flush: true);
  return file.path;
}

/// Decodes an image file into a widget; returns null when unreadable.
/// [cacheWidth] downscales the decode (memory saver for list thumbnails).
Widget? localCoverImage(String path, {BoxFit fit = BoxFit.cover, int? cacheWidth}) {
  try {
    if (!File(path).existsSync()) return null;
    return Image.file(File(path), fit: fit, cacheWidth: cacheWidth);
  } catch (_) {
    return null;
  }
}
