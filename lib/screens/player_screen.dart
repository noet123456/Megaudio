import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../utils/app_icons.dart';
import '../utils/io_facade.dart';
import '../widgets/spectrum_visualizer.dart';

/// Icon / label for the current playback mode button.
IconData _modeIcon(PlayMode mode) {
  switch (mode) {
    case PlayMode.sequential:
      return Icons.format_list_numbered;
    case PlayMode.repeatOne:
      return Icons.repeat_one;
    case PlayMode.shuffle:
      return Icons.shuffle;
  }
}

String _modeTooltip(PlayMode mode) {
  switch (mode) {
    case PlayMode.sequential:
      return 'Phát tuần tự — bấm để chuyển sang lặp 1 bài';
    case PlayMode.repeatOne:
      return 'Lặp 1 bài — bấm để chuyển sang phát ngẫu nhiên';
    case PlayMode.shuffle:
      return 'Phát ngẫu nhiên trong thể loại — bấm để quay lại tuần tự';
  }
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final song = provider.currentSong;

    if (song == null) {
      return Scaffold(
        backgroundColor: UiColors.bg,
        appBar: AppBar(),
        body: const Center(
          child: Text('Không có bài nào đang phát', style: TextStyle(color: UiColors.textFaint)),
        ),
      );
    }

    final totalMs = provider.duration.inMilliseconds.toDouble();
    final posMs = provider.position.inMilliseconds
        .toDouble()
        .clamp(0.0, totalMs > 0 ? totalMs : 1.0);
    final total = provider.playlist.length;
    final index = provider.currentIndex >= 0 ? provider.currentIndex : 0;

    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronDown, size: 22, color: UiColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        // Tape-counter style track position: TR 03 / 12
        title: Text(
          'TR ${(index + 1).toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            letterSpacing: 2,
            color: UiColors.textFaint,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _modeIcon(provider.playMode),
              size: 20,
              color: provider.playMode == PlayMode.sequential
                  ? UiColors.textDim
                  : UiColors.accent,
            ),
            onPressed: () => provider.cyclePlayMode(),
            tooltip: _modeTooltip(provider.playMode),
          ),
          IconButton(
            icon: Icon(
              Icons.graphic_eq,
              size: 20,
              color: provider.showSpectrum ? UiColors.accent : UiColors.textFaint,
            ),
            onPressed: () => provider.toggleSpectrum(),
            tooltip: provider.showSpectrum ? 'Tắt phổ âm' : 'Bật phổ âm',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, thickness: 0.5, color: UiColors.line),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              if (provider.errorMessage != null) _ErrorBanner(provider: provider),

              // Album artwork: large square, hairline border, no glow.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: AspectRatio(aspectRatio: 1, child: _CoverArtwork(song: song)),
                    ),
                  ),
                ),
              ),

              // Spectrum (toggled from the app bar).
              if (provider.showSpectrum)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    color: UiColors.surface,
                    border: Border(
                      top: BorderSide(color: UiColors.line, width: 0.5),
                      bottom: BorderSide(color: UiColors.line, width: 0.5),
                    ),
                  ),
                  child: SpectrumVisualizer(isPlaying: provider.isPlaying, height: 72),
                ),

              // Codec spec line: "FLAC · 96kHz / 24bit   HI-RES"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${song.formatString}  ·  ${song.specsLabel}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                      color: UiColors.textFaint,
                    ),
                  ),
                  if (song.isHiRes) ...[
                    const SizedBox(width: 10),
                    const Text(
                      'HI-RES',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: UiColors.accent,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              Text(
                song.title,
                style: const TextStyle(
                  color: UiColors.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                song.artist,
                style: const TextStyle(color: UiColors.textDim, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),

              // Seekbar: thin 2px line, amber active track.
              SliderTheme(
                data: const SliderThemeData(
                  trackHeight: 2,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 3.5),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: UiColors.accent,
                  inactiveTrackColor: UiColors.line,
                  thumbColor: UiColors.text,
                  overlayColor: Color(0x22D8A657),
                ),
                child: Slider(
                  value: posMs,
                  max: totalMs > 0 ? totalMs : 1.0,
                  onChanged: totalMs > 0
                      ? (val) {
                          provider.seek(Duration(milliseconds: val.toInt()));
                        }
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(provider.position),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: UiColors.textFaint,
                      ),
                    ),
                    Text(
                      _formatDuration(provider.duration),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: UiColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Transport controls: prev | -10s | play | +10s | next
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.skipBack, color: UiColors.text, size: 28),
                    onPressed: () => provider.playPrevious(),
                    tooltip: 'Bài trước',
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: UiColors.textDim, size: 26),
                    onPressed: () => provider.seekBy(-10),
                    tooltip: 'Tua lại 10 giây',
                  ),
                  // Play button: quiet circle outline, no gradient / glow.
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: UiColors.line, width: 1.5),
                      color: UiColors.surface,
                    ),
                    child: IconButton(
                      iconSize: 30,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        provider.isPlaying ? LucideIcons.pause : LucideIcons.play,
                        color: UiColors.text,
                      ),
                      onPressed: () => provider.togglePlayPause(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10, color: UiColors.textDim, size: 26),
                    onPressed: () => provider.seekBy(10),
                    tooltip: 'Tua tới 10 giây',
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.skipForward, color: UiColors.text, size: 28),
                    onPressed: () => provider.playNext(),
                    tooltip: 'Bài sau',
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.provider});

  final PlayerProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: UiColors.surface,
        border: Border(bottom: BorderSide(color: UiColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: UiColors.accent, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(color: UiColors.textDim, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: UiColors.textFaint, size: 15),
            onPressed: provider.clearError,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _CoverArtwork extends StatelessWidget {
  const _CoverArtwork({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final Widget content =
        (song.coverPath.isNotEmpty
            ? localCoverImage(song.coverPath, fit: BoxFit.cover, cacheWidth: 1024)
            : null) ??
        _placeholder();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: UiColors.line, width: 0.5),
      ),
      child: content,
    );
  }

  Widget _placeholder() => Container(
        color: UiColors.surface,
        child: const Center(
          child: Icon(LucideIcons.music, size: 56, color: UiColors.textFaint),
        ),
      );
}
