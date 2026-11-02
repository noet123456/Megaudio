import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/cover_image.dart';
import '../widgets/mini_player_bar.dart';
import '../widgets/song_row.dart';
import 'player_screen.dart';

// =============================================================================
// ALL SONGS (A -> Z, with in-list search)
// =============================================================================
class AllSongsScreen extends StatefulWidget {
  const AllSongsScreen({super.key, this.search = false});

  final bool search;

  @override
  State<AllSongsScreen> createState() => _AllSongsScreenState();
}

class _AllSongsScreenState extends State<AllSongsScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.search) {
      WidgetsBinding.instance.addPostFrameCallback((_) {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final all = provider.allSongsSorted;
    final q = _controller.text.trim().toLowerCase();
    final list = q.isEmpty
        ? all
        : all
            .where((s) =>
                s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q))
            .toList();

    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: flatAppBar(context, 'TẤT CẢ BÀI HÁT'),
      bottomNavigationBar: const MiniPlayerBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: UiColors.surface,
                border: Border.all(color: UiColors.line, width: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: UiColors.textFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: widget.search,
                      style: const TextStyle(fontSize: 13, color: UiColors.textDim),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Tìm trong thư viện...',
                        hintStyle: TextStyle(fontSize: 12.5, color: UiColors.textFaint),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('Không có bài nào.', style: TextStyle(color: UiColors.textFaint)),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final song = list[index];
                      return SongRow(
                        song: song,
                        isPlaying: provider.currentSong?.path == song.path,
                        onTap: () {
                          provider.playSong(song, queue: list);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PlayerScreen()),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ARTISTS (A -> Z)
// =============================================================================
class ArtistsScreen extends StatelessWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final artists = provider.artistNames;
    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: flatAppBar(context, 'NGHỆ SĨ'),
      bottomNavigationBar: const MiniPlayerBar(),
      body: artists.isEmpty
          ? const Center(
              child: Text('Không có dữ liệu.', style: TextStyle(color: UiColors.textFaint)),
            )
          : ListView.builder(
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artist = artists[index];
                final count = provider.songsByArtist(artist).length;
                return _NameRow(
                  icon: Icons.person_outline,
                  name: artist,
                  count: '$count bài',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: artist)),
                  ),
                );
              },
            ),
    );
  }
}

class ArtistDetailScreen extends StatelessWidget {
  const ArtistDetailScreen({super.key, required this.artist});

  final String artist;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final songs = provider.songsByArtist(artist);
    return _SongListScreen(
      title: artist.toUpperCase(),
      songs: songs,
      emptyText: 'Không có bài nào của nghệ sĩ này.',
    );
  }
}

// =============================================================================
// ALBUMS (built-in from tags/folders + user-created)
// =============================================================================
class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final albums = provider.albumNames;
    final custom = provider.customAlbums.keys.toList()..sort();

    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: flatAppBar(context, 'ALBUM'),
      bottomNavigationBar: const MiniPlayerBar(),
      body: ListView(
        children: [
          // --- user-created albums ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'ALBUM TỰ TẠO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: UiColors.textFaint,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateCollectionScreen(isAlbum: true)),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: UiColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('TẠO', style: TextStyle(fontSize: 11, letterSpacing: 1)),
                ),
              ],
            ),
          ),
          if (custom.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Chưa có album tự tạo — gom các bài bạn chọn vào một album riêng.',
                style: TextStyle(color: UiColors.textFaint, fontSize: 11),
              ),
            )
          else
            for (final name in custom)
              _NameRow(
                icon: Icons.album_outlined,
                name: name,
                count: '${provider.songsInCollection(provider.customAlbums[name]!).length} bài',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomCollectionDetailScreen(name: name, isAlbum: true),
                  ),
                ),
              ),
          const Divider(height: 0.5, thickness: 0.5, color: UiColors.line),

          // --- albums found in the library ---
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'TRONG THƯ VIỆN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: UiColors.textFaint,
              ),
            ),
          ),
          for (final album in albums)
            _AlbumRow(
              album: album,
              songs: provider.songsInAlbum(album),
            ),
        ],
      ),
    );
  }
}

class _AlbumRow extends StatelessWidget {
  const _AlbumRow({required this.album, required this.songs});

  final String album;
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: UiColors.line, width: 0.5)),
        ),
        child: Row(
          children: [
            CoverImage(path: songs.first.coverPath, size: 44, radius: 3),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: UiColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${songs.first.artist}  ·  ${songs.length} bài',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: UiColors.textDim),
                  ),
                ],
              ),
            ),
            if (provider.currentSong != null && songs.any((s) => s.path == provider.currentSong!.path))
              const Icon(Icons.graphic_eq, size: 16, color: UiColors.accent),
          ],
        ),
      ),
    );
  }
}

class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({super.key, required this.album});

  final String album;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final songs = provider.songsInAlbum(album);
    return _SongListScreen(
      title: album.toUpperCase(),
      songs: songs,
      emptyText: 'Album này không còn bài nào.',
    );
  }
}

class CustomCollectionDetailScreen extends StatelessWidget {
  const CustomCollectionDetailScreen({super.key, required this.name, required this.isAlbum});

  final String name;
  final bool isAlbum;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final paths = isAlbum ? provider.customAlbums[name] : provider.customPlaylists[name];
    final songs = provider.songsInCollection(paths ?? const []);

    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: flatAppBar(
        context,
        name.toUpperCase(),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: UiColors.textDim),
            tooltip: 'Xóa ${isAlbum ? 'album' : 'playlist'}',
            onPressed: () {
              if (isAlbum) {
                provider.deleteCustomAlbum(name);
              } else {
                provider.deletePlaylist(name);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayerBar(),
      body: songs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Các bài trong collection này không còn trong thư viện.\nQuét lại thư mục hoặc thêm lại bài.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: UiColors.textFaint, fontSize: 11, height: 1.6),
                ),
              ),
            )
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongRow(
                  song: song,
                  isPlaying: provider.currentSong?.path == song.path,
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
// GENRES
// =============================================================================
class GenresScreen extends StatelessWidget {
  const GenresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final genres = provider.genreNames;
    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: flatAppBar(context, 'THỂ LOẠI'),
      bottomNavigationBar: const MiniPlayerBar(),
      body: genres.isEmpty
          ? const Center(
              child: Text('Không có dữ liệu.', style: TextStyle(color: UiColors.textFaint)),
            )
          : ListView.builder(
              itemCount: genres.length,
              itemBuilder: (context, index) {
                final genre = genres[index];
                final count = provider.songsInGenre(genre).length;
                return _NameRow(
                  icon: Icons.category_outlined,
                  name: genre,
                  count: '$count bài',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GenreDetailScreen(genre: genre)),
                  ),
                );
              },
            ),
    );
  }
}

class GenreDetailScreen extends StatelessWidget {
  const GenreDetailScreen({super.key, required this.genre});

  final String genre;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final songs = provider.songsInGenre(genre);
    return _SongListScreen(
      title: genre.toUpperCase(),
      songs: songs,
      emptyText: 'Không có bài nào thuộc thể loại này.',
    );
  }
}

// =============================================================================
// PLAYLISTS (user-created only)
// =============================================================================
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final playlists = provider.customPlaylists.keys.toList()..sort();

    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: flatAppBar(context, 'PLAYLIST'),
      bottomNavigationBar: const MiniPlayerBar(),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'PLAYLIST CỦA BẠN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: UiColors.textFaint,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateCollectionScreen(isAlbum: false)),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: UiColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('TẠO', style: TextStyle(fontSize: 11, letterSpacing: 1)),
                ),
              ],
            ),
          ),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Chưa có playlist — tạo một list riêng từ các bài bạn thích.',
                style: TextStyle(color: UiColors.textFaint, fontSize: 11),
              ),
            )
          else
            for (final name in playlists)
              _NameRow(
                icon: Icons.queue_music,
                name: name,
                count: '${provider.songsInCollection(provider.customPlaylists[name]!).length} bài',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomCollectionDetailScreen(name: name, isAlbum: false),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// =============================================================================
// CREATE COLLECTION (name + song picker) — for custom albums & playlists
// =============================================================================
class CreateCollectionScreen extends StatefulWidget {
  const CreateCollectionScreen({super.key, required this.isAlbum});

  final bool isAlbum;

  @override
  State<CreateCollectionScreen> createState() => _CreateCollectionScreenState();
}

class _CreateCollectionScreenState extends State<CreateCollectionScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<String> _selected = {};

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _save(PlayerProvider provider) {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selected.isEmpty) return;
    final songs = provider.offlinePlaylist.where((s) => _selected.contains(s.path)).toList();
    if (widget.isAlbum) {
      provider.createCustomAlbum(name, songs);
    } else {
      provider.createPlaylist(name, songs);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final all = provider.allSongsSorted;
    final q = _searchController.text.trim().toLowerCase();
    final list = q.isEmpty
        ? all
        : all.where((s) => s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q)).toList();

    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: flatAppBar(
        context,
        widget.isAlbum ? 'TẠO ALBUM MỚI' : 'TẠO PLAYLIST',
        actions: [
          TextButton(
            onPressed: () => _save(provider),
            style: TextButton.styleFrom(foregroundColor: UiColors.accent),
            child: const Text('LƯU', style: TextStyle(fontSize: 12, letterSpacing: 1.5)),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayerBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: UiColors.surface,
                border: Border.all(color: UiColors.line, width: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isAlbum ? Icons.album_outlined : Icons.queue_music,
                    size: 18,
                    color: UiColors.textFaint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 13, color: UiColors.text),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: widget.isAlbum ? 'Tên album...' : 'Tên playlist...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: UiColors.textFaint),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: UiColors.surface,
                border: Border.all(color: UiColors.line, width: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: UiColors.textFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 12.5, color: UiColors.textDim),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Lọc bài hát...',
                        hintStyle: TextStyle(fontSize: 11.5, color: UiColors.textFaint),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Đã chọn ${_selected.length} bài',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: UiColors.textFaint),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('Thư viện trống.', style: TextStyle(color: UiColors.textFaint)),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final song = list[index];
                      final checked = _selected.contains(song.path);
                      return InkWell(
                        onTap: () => setState(() {
                          checked ? _selected.remove(song.path) : _selected.add(song.path);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          color: checked ? UiColors.surface : Colors.transparent,
                          child: Row(
                            children: [
                              CoverImage(path: song.coverPath, size: 40, radius: 3),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: checked ? UiColors.accent : UiColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10.5, color: UiColors.textDim),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                checked ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 20,
                                color: checked ? UiColors.accent : UiColors.textFaint,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SHARED PIECES
// =============================================================================
class _NameRow extends StatelessWidget {
  const _NameRow({
    required this.icon,
    required this.name,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String name;
  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: UiColors.line, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: UiColors.textFaint),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, color: UiColors.text),
              ),
            ),
            Text(
              count,
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

/// Scaffold with a flat title bar and a plain song list (used by artist /
/// album / genre detail screens).
class _SongListScreen extends StatelessWidget {
  const _SongListScreen({
    required this.title,
    required this.songs,
    required this.emptyText,
  });

  final String title;
  final List<Song> songs;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    return Scaffold(
      backgroundColor: UiColors.bg,
      appBar: flatAppBar(context, title),
      bottomNavigationBar: const MiniPlayerBar(),
      body: songs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(emptyText, style: const TextStyle(color: UiColors.textFaint, fontSize: 12)),
              ),
            )
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongRow(
                  song: song,
                  isPlaying: provider.currentSong?.path == song.path,
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
