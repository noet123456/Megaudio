/// Platform IO facade.
///
/// On native platforms (Windows/Android) this re-exports the real
/// `dart:io`-backed implementation. On web it re-exports the stub, so the
/// whole app compiles for `flutter build web` (dart:io does not exist there).
library;

export 'io_stub.dart' if (dart.library.io) 'io_real.dart';
