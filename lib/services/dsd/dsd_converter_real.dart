import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// DSF (DSD) -> PCM WAV converter.
///
/// A DSF file stores a 1-bit sigma-delta stream at 2.8224 MHz (DSD64) or
/// higher. Android / Windows media stacks only decode PCM, so files are
/// converted to a 88.2 kHz 16-bit stereo WAV that any backend can play.
///
/// The decimation filter is a 3rd-order CIC with R = fs / 88200, which is
/// O(1) per input bit (sliding integer sums) yet gives ~78 dB of alias
/// rejection at Nyquist — far better than a short FIR and thousands of times
/// cheaper than a long FIR at the DSD rate.
Future<String?> convertDsfToWav(
  String dsfPath, {
  void Function(double progress)? onProgress,
}) async {
  try {
    final source = File(dsfPath);
    if (!await source.exists()) return null;

    final cacheDir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}megaudio_dsd');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final target = File('${cacheDir.path}${Platform.pathSeparator}megaudio_dsd_'
        '${dsfPath.hashCode.toRadixString(16)}_${source.lengthSync()}.wav');

    // Cache: a previous conversion of the same source file is reused.
    if (await target.exists() && await target.length() > 44) {
      return target.path;
    }

    final raf = await source.open();
    try {
      final header = await raf.read(92);
      if (header.length < 92) return null;
      if (header[0] != 0x44 || header[1] != 0x53 || header[2] != 0x44) return null; // 'DSD'

      final channels = _le32(header, 52);
      final sampleRate = _le32(header, 56);
      final bitsPerSample = _le32(header, 60);
      final sampleCount = _le64(header, 64); // per channel, in bits
      final blockSize = _le32(header, 72);

      if (channels < 1 || channels > 2) return null;
      if (bitsPerSample != 1) return null; // only raw 1-bit DSD is supported
      if (sampleRate < 2000000 || sampleRate > 25000000) return null;
      if (blockSize <= 0 || blockSize > 1 << 20) return null;

      final decimation = (sampleRate / 88200).round();
      if (decimation < 8 || decimation > 256) return null;
      final outRate = (sampleRate / decimation).round();

      final totalBitsPerChannel = sampleCount > 0
          ? sampleCount
          : (await source.length() - 92) * 8 ~/ channels;
      final outSamples = totalBitsPerChannel ~/ decimation;
      if (outSamples <= 0) return null;

      final dataBytes = outSamples * channels * 2;
      final sink = await target.open(mode: FileMode.write);
      try {
        await sink.writeFrom(_wavHeader(channels, outRate, dataBytes));

        final cics = List<_Cic>.generate(channels, (_) => _Cic(decimation));
        final channelOut = List<List<int>>.generate(channels, (_) => <int>[]);

        var remaining = totalBitsPerChannel;
        var processedBytes = 0;
        final totalReadBytes = (totalBitsPerChannel + 7) ~/ 8 * channels;
        final buffer = Uint8List(blockSize);

        while (remaining > 0) {
          final blockBytes = math.min(blockSize, (remaining + 7) ~/ 8);
          for (var ch = 0; ch < channels; ch++) {
            final read = await raf.readInto(buffer, 0, blockBytes);
            if (read <= 0) break;
            final out = channelOut[ch];
            out.clear();
            final cic = cics[ch];
            // MSB-first bit stream.
            for (var i = 0; i < read; i++) {
              final byte = buffer[i];
              for (var bit = 7; bit >= 0; bit--) {
                final sample = cic.feed((byte >> bit) & 1);
                if (sample != null) out.add(sample);
              }
            }
            processedBytes += read;
          }
          remaining -= blockBytes * 8;
          if (processedBytes > 0 && onProgress != null && totalReadBytes > 0) {
            onProgress((processedBytes / totalReadBytes).clamp(0.0, 1.0));
          }

          // Interleave and write the samples produced by this block group.
          final count = channelOut.map((l) => l.length).reduce(math.min);
          if (count > 0) {
            final bytes = Uint8List(count * channels * 2);
            var o = 0;
            for (var i = 0; i < count; i++) {
              for (var ch = 0; ch < channels; ch++) {
                final v = channelOut[ch][i];
                bytes[o++] = v & 0xFF;
                bytes[o++] = (v >> 8) & 0xFF;
              }
            }
            await sink.writeFrom(bytes);
            for (final l in channelOut) {
              l.removeRange(0, count);
            }
          }
          if (processedBytes >= totalReadBytes) break;
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      onProgress?.call(1.0);
      return target.path;
    } finally {
      await raf.close();
    }
  } catch (_) {
    return null;
  }
}

/// 3rd-order CIC decimator over a 1-bit stream (bit 1 -> +1, bit 0 -> -1).
class _Cic {
  _Cic(this.r) : scale = 1.0 / (r * r * r);

  final int r;
  final double scale;
  int _s1 = 0, _s2 = 0, _s3 = 0;
  int _p3 = 0, _p1 = 0, _p2 = 0;
  int _counter = 0;

  int? feed(int bit) {
    final x = bit == 1 ? 1 : -1;
    _s1 += x;
    _s2 += _s1;
    _s3 += _s2;
    if (++_counter < r) return null;
    _counter = 0;
    final y1 = _s3 - _p3;
    _p3 = _s3;
    final y2 = y1 - _p1;
    _p1 = y1;
    final y3 = y2 - _p2;
    _p2 = y2;
    final v = (y3 * scale).clamp(-1.0, 1.0);
    return (v * 32767).round();
  }
}

Uint8List _wavHeader(int channels, int sampleRate, int dataBytes) {
  final header = ByteData(44);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * channels * 2, Endian.little);
  header.setUint16(32, channels * 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, dataBytes, Endian.little);
  return header.buffer.asUint8List();
}

int _le32(List<int> b, int o) => b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

int _le64(List<int> b, int o) => _le32(b, o) | (_le32(b, o + 4) << 32);
