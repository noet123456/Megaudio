/// DSD -> PCM conversion facade.
///
/// Native platforms convert DSF files to a temporary WAV; web has no local
/// files and falls back to the stub.
library;

export 'dsd_converter_stub.dart' if (dart.library.io) 'dsd_converter_real.dart';
