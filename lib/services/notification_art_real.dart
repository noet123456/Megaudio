import 'dart:io';
import 'dart:ui' as ui;

/// Returns the artwork to publish to the media notification.
///
/// Android derives the notification's text and control-icon colours from the
/// artwork. Very bright covers therefore produce low-contrast text/icons on a
/// pale background. Bright covers are darkened hard (cached by path + size) so
/// the system switches to white text and white controls. Covers that are
/// already dark are returned untouched.
Future<String> notificationArtPath(String coverPath) async {
  if (coverPath.isEmpty) return coverPath;
  try {
    final source = File(coverPath);
    if (!await source.exists()) return coverPath;
    final length = await source.length();

    final cacheDir = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}megaudio_notif_art',
    );
    // v4: forces regeneration of artwork cached by older, weaker scrims.
    final target = File(
      '${cacheDir.path}${Platform.pathSeparator}'
      '${coverPath.hashCode.toRadixString(16)}_${length}_v4.png',
    );
    if (await target.exists()) return target.path;

    final bytes = await source.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 640);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return coverPath;
      final rgba = data.buffer.asUint8List();

      // Perceived luminance. The 60th percentile is a better proxy than the
      // mean for the "dominant" background the system extracts: a mostly pale
      // cover with a few dark objects must still be treated as bright.
      final lums = <double>[];
      for (var i = 0; i + 3 < rgba.length; i += 4 * 17) {
        final r = rgba[i];
        final g = rgba[i + 1];
        final b = rgba[i + 2];
        lums.add((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0);
      }
      if (lums.isEmpty) return coverPath;
      lums.sort();
      final p60 = lums[(lums.length * 0.6).floor().clamp(0, lums.length - 1)];

      // Already dark enough for white notification text/icons.
      if (p60 <= 0.24) return coverPath;

      // Bring the artwork down to a near-black level (target luminance 0.10),
      // so the media card always ends up dark with white text and controls.
      final alpha = (1.0 - 0.10 / p60).clamp(0.50, 0.94).toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final w = image.width.toDouble();
      final h = image.height.toDouble();
      canvas.drawImage(image, ui.Offset.zero, ui.Paint());
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, w, h),
        ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, alpha),
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
