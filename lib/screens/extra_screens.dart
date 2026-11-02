import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/mini_player_bar.dart';
import '../widgets/song_row.dart';
import 'player_screen.dart';

// =============================================================================
// RECENTLY PLAYED (drawer)
// =============================================================================
class RecentScreen extends StatelessWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final entries = provider.recent;
    final songs = entries.map((e) => e.song).toList();

    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: flatAppBar(context, 'NGHE GẦN ĐÂY'),
      bottomNavigationBar: const MiniPlayerBar(),
      body: entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Chưa nghe bài nào.\nLịch sử nghe sẽ hiện ở đây.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: UiColors.textFaint, fontSize: 12, height: 1.6),
                ),
              ),
            )
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final song = entry.song;
                return SongRow(
                  song: song,
                  isPlaying: provider.currentSong?.id == song.id,
                  subtitle:
                      '${timeAgoLabel(entry.playedAtMs)}  ·  ${song.formatString}',
                  onTap: () {
                    provider.playSong(song, queue: songs);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlayerScreen()),
                    );
                  },
                );
              },
            ),
    );
  }
}

// =============================================================================
// LONG TIME NO LISTEN (drawer)
// =============================================================================
class ForgottenScreen extends StatelessWidget {
  const ForgottenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final songs = provider.forgottenSongs;

    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: flatAppBar(context, 'LÂU CHƯA NGHE'),
      bottomNavigationBar: const MiniPlayerBar(),
      body: songs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Chưa có dữ liệu nghe.\nBài nào bạn chưa mở bao giờ sẽ hiện ở đây.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: UiColors.textFaint, fontSize: 12, height: 1.6),
                ),
              ),
            )
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                final last = provider.lastPlayedAtOf(song);
                return SongRow(
                  song: song,
                  isPlaying: provider.currentSong?.path == song.path,
                  subtitle:
                      last == null ? 'Chưa từng nghe' : 'Lần cuối: ${timeAgoLabel(last)}',
                  onTap: () {
                    provider.playSong(song, queue: songs);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlayerScreen()),
                    );
                  },
                );
              },
            ),
    );
  }
}
