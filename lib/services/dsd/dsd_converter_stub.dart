/// Web build: no dart:io, so DSD files cannot be converted/played.
Future<String?> convertDsfToWav(
  String dsfPath, {
  void Function(double progress)? onProgress,
}) async =>
    null;
