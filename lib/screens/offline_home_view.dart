import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import 'collection_screens.dart';

/// Offline home: grid of square category tiles — all songs, artists, albums,
/// genres, and user-created playlists.
class OfflineHomeView extends StatelessWidget {
  const OfflineHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);

    if (provider.isLoadingLibrary) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: UiColors.textDim),
            ),
            SizedBox(height: 12),
            Text('Đang đọc thư viện...', style: TextStyle(color: UiColors.textFaint, fontSize: 12)),
          ],
        ),
      );
    }

    if (provider.offlinePlaylist.isEmpty) {
      return _EmptyState(provider: provider);
    }

    final tiles = <_TileData>[
      _TileData(
        label: 'TẤT CẢ BÀI HÁT',
        icon: Icons.music_note_outlined,
        count: provider.offlinePlaylist.length,
        unit: 'bài',
        builder: () => const AllSongsScreen(),
      ),
      _TileData(
        label: 'NGHỆ SĨ',
        icon: Icons.person_outline,
        count: provider.artistNames.length,
        unit: 'nghệ sĩ',
        builder: () => const ArtistsScreen(),
      ),
      _TileData(
        label: 'ALBUM',
        icon: Icons.album_outlined,
        count: provider.albumNames.length + provider.customAlbums.length,
        unit: 'album',
        builder: () => const AlbumsScreen(),
      ),
      _TileData(
        label: 'THỂ LOẠI',
        icon: Icons.category_outlined,
        count: provider.genreNames.length,
        unit: 'thể loại',
        builder: () => const GenresScreen(),
      ),
      _TileData(
        label: 'PLAYLIST',
        icon: Icons.queue_music,
        count: provider.customPlaylists.length,
        unit: 'list',
        builder: () => const PlaylistsScreen(),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.0,
      children: [
        for (final t in tiles)
          _CategoryTile(
            data: t,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => t.builder()),
            ),
          ),
      ],
    );
  }
}

class _TileData {
  const _TileData({
    required this.label,
    required this.icon,
    required this.count,
    required this.unit,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final int count;
  final String unit;
  final Widget Function() builder;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.data, required this.onTap});

  final _TileData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: UiColors.surface,
          border: Border.all(color: UiColors.line, width: 0.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(data.icon, size: 22, color: UiColors.textDim),
            const Spacer(),
            Text(
              data.label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: UiColors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${data.count} ${data.unit}',
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: UiColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.provider});

  final PlayerProvider provider;

  @override
  Widget build(BuildContext context) {
    final hasFolder = provider.musicFolderPath != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFolder ? Icons.library_music_outlined : Icons.folder_outlined,
              color: UiColors.textFaint,
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              hasFolder ? 'Thư mục chưa có file nhạc' : 'Chưa có nhạc trong thư viện',
              style: const TextStyle(color: UiColors.textDim, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              hasFolder
                  ? 'Copy file .mp3 / .flac / .wav / .dsf vào (kể cả trong subfolder)\nrồi quét lại từ menu bên trái'
                  : 'Chọn thư mục chứa file .mp3, .flac, .wav, .dsf',
              textAlign: TextAlign.center,
              style: const TextStyle(color: UiColors.textFaint, fontSize: 11, height: 1.5),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: hasFolder ? provider.rescanFolder : provider.pickMusicFolder,
              style: OutlinedButton.styleFrom(
                foregroundColor: UiColors.text,
                side: const BorderSide(color: UiColors.line),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: Icon(hasFolder ? Icons.refresh : Icons.create_new_folder_outlined, size: 18),
              label: Text(hasFolder ? 'Quét lại' : 'Chọn thư mục nhạc'),
            ),
          ],
        ),
      ),
    );
  }
}
