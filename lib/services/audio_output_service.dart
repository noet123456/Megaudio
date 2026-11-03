import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One connected audio output as reported by Android.
class AudioOutputDevice {
  final String name;
  final String type; // 'USB DAC' / '3.5mm' / 'Bluetooth' / 'Loa trong' ...
  final bool isDac;
  final int maxSampleRate;

  const AudioOutputDevice({
    required this.name,
    required this.type,
    required this.isDac,
    required this.maxSampleRate,
  });
}

/// Reads the platform's audio output routes so the app can show whether a
/// USB-C / 3.5mm DAC is connected. Playback routing itself is handled by
/// Android: audio is sent to the active output automatically.
class AudioOutputService {
  static const MethodChannel _channel = MethodChannel('megaudio/audio');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<List<AudioOutputDevice>> outputs() async {
    if (!isSupported) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('outputs');
      if (raw == null) return const [];
      final result = <AudioOutputDevice>[];
      for (final item in raw) {
        if (item is! Map) continue;
        result.add(AudioOutputDevice(
          name: (item['name'] ?? '') as String,
          type: (item['type'] ?? '') as String,
          isDac: (item['isDac'] ?? false) as bool,
          maxSampleRate: ((item['maxSampleRate'] ?? 0) as num).toInt(),
        ));
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}
