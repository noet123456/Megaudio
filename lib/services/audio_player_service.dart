import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'audio_handler.dart';

class AudioPlayerService {
  /// On Android the audio_service handler owns the player (needed for the
  /// media session / notification / hardware buttons). Elsewhere (Windows,
  /// web) a plain AudioPlayer is used.
  final MegaudioAudioHandler? _handler;
  AudioPlayer? _plain;
  bool _isCustomDspEnabled = true;

  AudioPlayerService({MegaudioAudioHandler? handler}) : _handler = handler {
    final h = _handler;
    if (h != null) {
      h.onSkipNext = () async {
        await onMediaSkipNext?.call();
      };
      h.onSkipPrevious = () async {
        await onMediaSkipPrevious?.call();
      };
    }
  }

  /// Wired by PlayerProvider: OS media buttons must follow app queue logic.
  Future<void> Function()? onMediaSkipNext;
  Future<void> Function()? onMediaSkipPrevious;

  /// Song currently loaded into the player backend (nullable public field).
  Song? currentSong;

  /// Serializes every backend load so rapid track switching can never issue
  /// concurrent native calls (a known source of native crashes / stalls).
  Future<void> _loadQueue = Future.value();

  AudioPlayer get _player => _handler?.player ?? (_plain ??= AudioPlayer());
  AudioPlayer get player => _player;
  bool get isCustomDspEnabled => _isCustomDspEnabled;

  set customDspEnabled(bool value) => _isCustomDspEnabled = value;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;

  /// Loads a real audio file or stream URL and starts playback.
  /// Returns false (without throwing) when the backend cannot decode the file,
  /// e.g. DSD streams that the Windows Media Foundation cannot handle.
  Future<bool> loadSong(Song song) {
    final task = _loadQueue.then((_) => _doLoad(song));
    // Keep the queue alive even when a load fails.
    _loadQueue = task.then<void>((_) {}, onError: (_) {});
    return task;
  }

  Future<bool> _doLoad(Song song) async {
    currentSong = song;
    if (song.path.isEmpty) return false;
    try {
      // On Android the handler publishes media metadata + state; elsewhere a
      // plain player handles the local file.
      final h = _handler;
      if (h != null) {
        await h.loadSong(song);
        return true;
      }
      await _player.setFilePath(song.path);
      await _player.play();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> play() async {
    try {
      final h = _handler;
      if (h != null) {
        await h.play();
      } else {
        await _player.play();
      }
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      final h = _handler;
      if (h != null) {
        await h.pause();
      } else {
        await _player.pause();
      }
    } catch (_) {}
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (_) {}
  }

  /// Native single-track looping for repeat-one mode. Falls back silently on
  /// backends without setLoopMode (the provider also handles the completed
  /// state manually in that case).
  Future<void> setRepeatOne(bool on) async {
    try {
      await _player.setLoopMode(on ? LoopMode.one : LoopMode.off);
    } catch (_) {}
  }

  /// Relative seeking (e.g. +/- 10 seconds), clamped to [0, duration].
  Future<void> seekBy(int seconds) async {
    try {
      final dur = _player.duration ?? Duration.zero;
      var target = _player.position + Duration(seconds: seconds);
      if (target < Duration.zero) target = Duration.zero;
      if (dur > Duration.zero && target > dur) target = dur;
      await _player.seek(target);
    } catch (_) {}
  }

  void toggleCustomDsp() {
    _isCustomDspEnabled = !_isCustomDspEnabled;
  }

  void dispose() {
    _plain?.dispose();
  }
}
