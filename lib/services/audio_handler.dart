import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';

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
        MediaControl.skipToPrevious,
        MediaControl.rewind,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.fastForward,
        MediaControl.skipToNext,
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

  /// Publishes the track metadata and starts playback.
  Future<void> loadSong(Song song) async {
    mediaItem.add(MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration > Duration.zero ? song.duration : null,
      artUri: song.coverPath.isNotEmpty ? Uri.file(song.coverPath) : null,
      extras: {'specs': song.specsLabel},
    ));
    await player.setFilePath(song.path);
    await player.play();
  }

  @override
  Future<void> play() => player.play();

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
