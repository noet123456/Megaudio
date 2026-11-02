import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/song.dart';
import '../utils/io_facade.dart';

/// Bridge between the Flutter player state and the native Android
/// home-screen widget (see MegaudioWidgetProvider.kt).
///
/// Also decides the widget colour scheme: bright artwork gets a white
/// gradient overlay with black text, dark artwork gets a black gradient with
/// white text. Artwork-less tracks fall back to the app logo.
class WidgetService {
  static const MethodChannel _channel = MethodChannel('megaudio/widget');
  static final Map<String, bool> _lightCache = {};
  static DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  static String _lastSignature = '';

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// True when the artwork's average luminance is bright enough that a white
  /// gradient + black text reads better.
  static Future<bool> coverIsLight(String path) async {
    if (path.isEmpty) return false; // no artwork -> dark scheme + logo
    final cached = _lightCache[path];
    if (cached != null) return cached;
    try {
      final bytes = await readFileBytes(path);
      if (bytes == null) return false;
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 48, targetHeight: 48);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      codec.dispose();
      if (data == null) return false;
      var sum = 0.0;
      var count = 0;
      for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
        final alpha = data.getUint8(i + 3);
        if (alpha < 16) continue; // ignore transparent pixels
        final r = data.getUint8(i);
        final g = data.getUint8(i + 1);
        final b = data.getUint8(i + 2);
        sum += (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
        count++;
      }
      final light = count > 0 && (sum / count) >= 0.6;
      _lightCache[path] = light;
      return light;
    } catch (_) {
      return false;
    }
  }

  /// Pushes the current state. Progress-only changes are throttled to once
  /// every 1.5s; track / play-state / artwork changes go out immediately.
  static Future<void> push({
    required Song? song,
    required bool playing,
    required Duration position,
    required Duration duration,
    bool force = false,
  }) async {
    if (!isSupported) return;
    final now = DateTime.now();
    final signature = '${song?.id}|${song?.coverPath}|$playing';
    final changed = force || signature != _lastSignature;
    if (!changed && now.difference(_lastPush).inMilliseconds < 1500) return;
    _lastPush = now;
    _lastSignature = signature;

    final light = await coverIsLight(song?.coverPath ?? '');
    try {
      await _channel.invokeMethod<void>('update', {
        'title': song?.title ?? '',
        'artist': song?.artist ?? '',
        'coverPath': song?.coverPath ?? '',
        'playing': playing,
        'positionMs': position.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'isLight': light,
      });
    } catch (_) {
      // The widget is optional.
    }
  }

  static Future<void> clear() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } catch (_) {}
  }
}
