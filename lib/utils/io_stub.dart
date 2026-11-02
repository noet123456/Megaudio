import 'package:flutter/material.dart';

import '../models/song.dart';

/// Web build: no dart:io, no local folder library.
const bool kSupportsLocalLibrary = false;

bool folderExists(String folderPath) => false;

Future<List<String>> listAudioFiles(String folderPath) async => const [];

Future<Song?> inspectAudioFile(String path) async => null;

Future<String?> extractCoverArtFile(String path) async => null;

Widget? localCoverImage(String path, {BoxFit fit = BoxFit.cover, int? cacheWidth}) => null;
