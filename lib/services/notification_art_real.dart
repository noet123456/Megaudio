import 'dart:io';
import 'dart:ui' as ui;

/// Returns the artwork to publish to the media notification.
///
/// Android derives the notification's text and icon colours from the artwork.
/// A very bright cover therefore produces dark, low-contrast controls on a pale
/// background. Such covers are darkened once (cached by path + size) so the
/// system picks white text/icons instead. Darker covers are returned untouched.
Future<String> notificationArtPath(String coverPath) async {
  if (coverPath.isEmpty) return coverPath;
  try {
    final source = File(coverPath);
    if (!await source.exists()) return coverPath;
    final length = await source.length();

    final cacheDir = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}megaudio_notif_art',
    );
    final target = File(
      '${cacheDir.path}${Platform.pathSeparator}'
      '${coverPath.hashCode.toRadixString(16)}_$length.png',
    );
    if (await target.exists()) return target.path;

    final bytes = await source.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 768);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return coverPath;
      final rgba = data.buffer.asUint8List();

      // Perceived luminance, sampled so that large covers stay cheap.
      var sum = 0.0;
      var count = 0;
      for (var i = 0; i + 3 < rgba.length; i += 4 * 41) {
        final r = rgba[i];
        final g = rgba[i + 1];
        final b = rgba[i + 2];
        sum += (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
        count++;
      }
      if (count == 0 || sum / count <= 0.62) return coverPath;

      // Light cover: draw it under a 45% black scrim.
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final w = image.width.toDouble();
      final h = image.height.toDouble();
      canvas.drawImage(image, ui.Offset.zero, ui.Paint());
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, w, h),
        ui.Paint()..color = const ui.Color(0x73000000),
      );
      final picture = recorder.endRecording();
      final out = await picture.toImage(image.width, image.height);
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      out.dispose();
      if (png == null) return coverPath;

      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      await target.writeAsBytes(png.buffer.asUint8List(), flush: true);
      return target.path;
    } finally {
      image.dispose();
      codec.dispose();
    }
  } catch (_) {
    return coverPath;
  }
}
