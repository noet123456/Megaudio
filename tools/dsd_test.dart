// Headless test of the DSD -> PCM converter.
// Creates a synthetic stereo DSF (1 kHz left, 500 Hz right, DSD64), converts
// it, then verifies the WAV header and the recovered tone frequencies.
// Run: dart run tools/dsd_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../lib/services/dsd/dsd_converter_real.dart';

const int fs = 2822400; // DSD64
const int blockSize = 4096;
const int blocks = 172; // ~2 seconds
const int bitsPerChannel = blocks * blockSize * 8;

void main() async {
  final dir = await Directory.systemTemp.createTemp('dsd_synth');
  final file = File('${dir.path}/test.dsf');
  print('generating synthetic DSF: ${file.path}');
  await _writeDsf(file, leftHz: 1000, rightHz: 500);

  final sw = Stopwatch()..start();
  var lastProgress = -1;
  final wavPath = await convertDsfToWav(file.path, onProgress: (p) {
    final pct = (p * 100).round();
    if (pct != lastProgress && pct % 25 == 0) {
      lastProgress = pct;
      print('  progress $pct%');
    }
  });
  sw.stop();
  if (wavPath == null) {
    print('TEST FAILED: converter returned null');
    exit(1);
  }
  final wav = File(wavPath);
  final size = await wav.length();
  print('converted in ${sw.elapsedMilliseconds}ms -> ${(size / 1024 / 1024).toStringAsFixed(1)} MB');

  final bytes = await wav.readAsBytes();
  final header = ByteData.sublistView(bytes, 0, 44);
  final channels = header.getUint16(22, Endian.little);
  final rate = header.getUint32(24, Endian.little);
  final bits = header.getUint16(34, Endian.little);
  final dataBytes = header.getUint32(40, Endian.little);
  print('WAV: ${channels}ch ${rate}Hz ${bits}-bit data=${dataBytes}B');
  if (channels != 2 || rate != 88200 || bits != 16) {
    print('TEST FAILED: unexpected WAV format');
    exit(1);
  }

  final sampleCount = dataBytes ~/ 4;
  double rms(int ch) {
    var sum = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final o = 44 + i * 4 + ch * 2;
      var s = (bytes[o + 1] << 8) | bytes[o];
      if (s >= 0x8000) s -= 0x10000;
      final v = s / 32768.0;
      sum += v * v;
    }
    return math.sqrt(sum / sampleCount);
  }

  int zeroCrossings(int ch) {
    var count = 0;
    int? prev;
    for (var i = 0; i < sampleCount; i++) {
      final o = 44 + i * 4 + ch * 2;
      var s = (bytes[o + 1] << 8) | bytes[o];
      if (s >= 0x8000) s -= 0x10000;
      if (prev != null && ((prev < 0 && s >= 0) || (prev >= 0 && s < 0))) count++;
      prev = s;
    }
    return count;
  }

  final seconds = sampleCount / rate;
  final leftHz = zeroCrossings(0) / 2 / seconds;
  final rightHz = zeroCrossings(1) / 2 / seconds;
  print('recovered tone: left=${leftHz.toStringAsFixed(0)}Hz right=${rightHz.toStringAsFixed(0)}Hz');
  print('RMS: left=${rms(0).toStringAsFixed(3)} right=${rms(1).toStringAsFixed(3)}');

  final ok = (leftHz - 1000).abs() < 60 && (rightHz - 500).abs() < 60;
  print(ok ? 'TEST PASSED' : 'TEST FAILED: tone mismatch');

  // Second call must hit the cache (same source file).
  final sw2 = Stopwatch()..start();
  final cached = await convertDsfToWav(file.path);
  sw2.stop();
  print('cache hit: ${cached == wavPath} in ${sw2.elapsedMilliseconds}ms');

  await dir.delete(recursive: true);
  if (!ok) exit(1);
}

Future<void> _writeDsf(File file, {required double leftHz, required double rightHz}) async {
  final raf = await file.open(mode: FileMode.write);
  try {
    final header = ByteData(92);
    void ascii(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'DSD ');
    header.setUint64(4, 28, Endian.little);
    final dataBytes = blocks * blockSize * 2;
    header.setUint64(12, 92 + dataBytes, Endian.little);
    header.setUint64(20, 0, Endian.little);
    ascii(28, 'fmt ');
    header.setUint64(32, 52, Endian.little);
    header.setUint32(40, 1, Endian.little); // version
    header.setUint32(44, 0, Endian.little); // raw DSD
    header.setUint32(48, 2, Endian.little); // channel type stereo
    header.setUint32(52, 2, Endian.little); // channels
    header.setUint32(56, fs, Endian.little);
    header.setUint32(60, 1, Endian.little); // 1 bit
    header.setUint64(64, bitsPerChannel, Endian.little);
    header.setUint32(72, blockSize, Endian.little);
    header.setUint32(76, 0, Endian.little);
    ascii(80, 'data');
    header.setUint64(84, dataBytes + 12, Endian.little);
    await raf.writeFrom(header.buffer.asUint8List());

    final left = _sigmaDelta(leftHz, 0.4, bitsPerChannel);
    final right = _sigmaDelta(rightHz, 0.4, bitsPerChannel);
    for (var b = 0; b < blocks; b++) {
      await raf.writeFrom(left, b * blockSize, (b + 1) * blockSize);
      await raf.writeFrom(right, b * blockSize, (b + 1) * blockSize);
    }
  } finally {
    await raf.close();
  }
}

Uint8List _sigmaDelta(double hz, double amplitude, int bits) {
  final out = Uint8List(bits ~/ 8);
  var integrator = 0.0;
  var byte = 0;
  var bitIndex = 7;
  for (var n = 0; n < bits; n++) {
    final x = amplitude * math.sin(2 * math.pi * hz * n / fs);
    final y = integrator >= 0 ? 1.0 : -1.0;
    integrator += x - y;
    if (y > 0) byte |= 1 << bitIndex;
    if (--bitIndex < 0) {
      out[n ~/ 8] = byte;
      byte = 0;
      bitIndex = 7;
    }
  }
  return out;
}
