import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'notification_art.dart';

/// Notification transport buttons use Megaudio's own drawables: white glyphs on
/// a translucent dark disc. Android 9 tints the media card with colours taken
/// from the cover art, so plain white system icons disappear on bright covers.
const MediaControl _notifPrevious = MediaControl(
  androidIcon: 'drawable/megaudio_notif_previous',
  label: 'Previous',
  action: MediaAction.skipToPrevious,
);

const MediaControl _notifRewind = MediaControl(
  androidIcon: 'drawable/megaudio_notif_fast_rewind',
  label: 'Rewind',
  action: MediaAction.rewind,
);

const MediaControl _notifPlay = MediaControl(
  androidIcon: 'drawable/megaudio_notif_play',
  label: 'Play',
  action: MediaAction.play,
);

const MediaControl _notifPause = MediaControl(
  androidIcon: 'drawable/megaudio_notif_pause',
  label: 'Pause',
  action: MediaAction.pause,
);

const MediaControl _notifFastForward = MediaControl(
  androidIcon: 'drawable/megaudio_notif_fast_forward',
  label: 'Fast Forward',
  action: MediaAction.fastForward,
);

const MediaControl _notifNext = MediaControl(
  androidIcon: 'drawable/megaudio_notif_next',
  label: 'Next',
  action: MediaAction.skipToNext,
);


/// Android media session handler.
///
/// Owns the AudioPlayer and publishes the now-playing [MediaItem] plus the
/// [PlaybackState], which is what makes Android treat the app as a real music
/// player: compact media notification with artwork and transport controls,
/// lock-screen card, headset/Bluetooth hardware media buttons, and the
/// system media picker entry.
class MegaudioAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer player = AudioPlayer();

  /// Wired by AudioPlayerService -> PlayerProvider so the OS "next"/"previous"
  /// buttons follow the same queue logic as the in-app controls.
  Future<void> Function()? onSkipNext;
  Future<void> Function()? onSkipPrevious;

  MegaudioAudioHandler() {
    player.playbackEventStream.listen((_) => _broadcast(), onError: (_, __) {});
    player.positionStream.listen((p) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: p,
        bufferedPosition: player.bufferedPosition,
      ));
    });
    player.durationStream.listen((d) {
      final item = mediaItem.value;
      if (d != null && d > Duration.zero && item != null) {
        mediaItem.add(item.copyWith(duration: d));
      }
    });
  }

  AudioProcessingState _mapProcessing(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  void _broadcast() {
    final playing = player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        _notifPrevious,
        _notifRewind,
        playing ? _notifPause : _notifPlay,
        _notifFastForward,
        _notifNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 2, 4],
      processingState: _mapProcessing(player.processingState),
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
    ));
  }

  /// Publishes the track metadata and starts playback. [playPath] may point
  /// at a converted copy (DSD -> PCM WAV) instead of the original file.
  Future<void> loadSong(Song song, {String? playPath}) async {
    final art = song.coverPath;
    mediaItem.add(MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration > Duration.zero ? song.duration : null,
      artUri: art.isNotEmpty ? Uri.file(art) : null,
      // Full strings for the notification / media card; the OS decides how
      // much of them fits on one line.
      displayTitle: song.title,
      displaySubtitle: '${song.artist} · ${song.specsLabel}',
      displayDescription: song.album,
      extras: {'specs': song.specsLabel},
    ));
    await player.setFilePath(playPath ?? song.path);
    _startPlayback();
    // Image processing must never delay the next track from starting, so the
    // high-contrast artwork is applied in the background.
    unawaited(_applyContrastArtwork(song));
  }

  /// Replaces the notification artwork with a high-contrast copy once the
  /// track is already playing. Light covers are darkened so Android picks
  /// white text and control icons instead of dark/low-contrast ones.
  Future<void> _applyContrastArtwork(Song song) async {
    if (song.coverPath.isEmpty) return;
    try {
      final art = await notificationArtPath(song.coverPath);
      if (art == song.coverPath) return;
      final item = mediaItem.value;
      if (item == null || item.id != song.id) return; // track changed meanwhile
      mediaItem.add(item.copyWith(artUri: Uri.file(art)));
    } catch (_) {
      // Artwork is cosmetic; keep the original cover on failure.
    }
  }

  /// just_audio's `play()` future only completes when playback pauses, stops
  /// or reaches the end of the track. Awaiting it would keep the load queue
  /// locked for the whole song, making every later track change wait.
  void _startPlayback() {
    unawaited(player.play().catchError((Object _) {}));
  }

  @override
  Future<void> play() async => _startPlayback();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    await onSkipNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    await onSkipPrevious?.call();
  }

  @override
  Future<void> rewind() => player.seek(_clamp(player.position - const Duration(seconds: 10)));

  @override
  Future<void> fastForward() => player.seek(_clamp(player.position + const Duration(seconds: 10)));

  Duration _clamp(Duration d) {
    if (d < Duration.zero) return Duration.zero;
    final dur = player.duration;
    if (dur != null && d > dur) return dur;
    return d;
  }
}
