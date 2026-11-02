import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../screens/player_screen.dart';
import '../theme/app_colors.dart';
import '../utils/app_icons.dart';
import 'cover_image.dart';

/// Compact now-playing bar pinned to the bottom of every browsing screen.
/// Tap it to open the full player. Renders nothing when no track is loaded.
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final song = provider.currentSong;
    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
      },
      child: Container(
        decoration: const BoxDecoration(
          color: UiColors.surface,
          border: Border(top: BorderSide(color: UiColors.line, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                CoverImage(path: song.coverPath, size: 42, radius: 3),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: UiColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.specsLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: UiColors.textFaint),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.skipBack, size: 20, color: UiColors.textDim),
                  onPressed: () => provider.playPrevious(),
                ),
                IconButton(
                  icon: Icon(
                    provider.isPlaying ? LucideIcons.pause : LucideIcons.play,
                    size: 26,
                    color: UiColors.text,
                  ),
                  onPressed: () => provider.togglePlayPause(),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.skipForward, size: 20, color: UiColors.textDim),
                  onPressed: () => provider.playNext(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a scrollable screen body and pins the mini player underneath it.
class WithMiniPlayer extends StatelessWidget {
  const WithMiniPlayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: child),
        const MiniPlayerBar(),
      ],
    );
  }
}
