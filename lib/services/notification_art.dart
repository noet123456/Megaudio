/// Notification artwork helper.
///
/// On native platforms a very bright cover is darkened before it is handed to
/// the media notification, so the OS picks light title text and control icons.
/// Web has no file access and keeps the original path.
library;

export 'notification_art_stub.dart'
    if (dart.library.io) 'notification_art_real.dart';
