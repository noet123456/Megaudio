import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import '../services/audio_handler.dart';
import '../services/audio_player_service.dart';
import '../services/widget_service.dart';
import '../utils/io_facade.dart';

/// Playlist playback strategy, cycled from the player screen:
/// sequential order -> repeat one track -> random shuffle.
enum PlayMode { sequential, repeatOne, shuffle }

class PlayerProvider with ChangeNotifier {
  static const _prefFolder = 'music_folder_path';
  static const _prefSpectrum = 'show_spectrum';
  static const _prefDsp = 'custom_dsp_enabled';
  static const _prefPlayMode = 'play_mode';
  static const _prefRecent = 'recent_entries_v1';
  static const _prefLastPlayed = 'last_played_map_v1';
  static const _prefPlayCounts = 'play_count_map_v1';
  static const _prefCustomAlbums = 'custom_albums_v1';
  static const _prefCustomPlaylists = 'custom_playlists_v1';

  final AudioPlayerService _audioService;
  final Random _rng = Random();

  // --- playback / queue ---
  List<Song> _playlist = []; // active queue (library or a filtered view)
  List<Song> _librarySongs = []; // the folder library (source of truth)
  int _currentIndex = -1;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _musicFolderPath;
  bool _showSpectrum = false;
  bool _isLoadingLibrary = false;
  String? _errorMessage;
  PlayMode _playMode = PlayMode.sequential;
  bool _coverExtracting = false;
  bool _askedNotificationPermission = false;

  // --- library state (history / stats / collections) ---
  List<RecentEntry> _recent = [];
  Map<String, int> _lastPlayedAt = {}; // path -> epoch ms
  Map<String, int> _playCounts = {};
  Map<String, List<String>> _customAlbums = {};
  Map<String, List<String>> _customPlaylists = {};

  AudioPlayerService get audioService => _audioService;
  List<Song> get playlist => _playlist;
  List<Song> get offlinePlaylist => _librarySongs;
  Song? get currentSong => _audioService.currentSong;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get musicFolderPath => _musicFolderPath;
  bool get showSpectrum => _showSpectrum;
  bool get isLoadingLibrary => _isLoadingLibrary;
  String? get errorMessage => _errorMessage;
  bool get isCustomDspEnabled => _audioService.isCustomDspEnabled;
  PlayMode get playMode => _playMode;

  List<RecentEntry> get recent => _recent;
  Map<String, List<String>> get customAlbums => _customAlbums;
  Map<String, List<String>> get customPlaylists => _customPlaylists;

  PlayerProvider({MegaudioAudioHandler? audioHandler})
      : _audioService = AudioPlayerService(handler: audioHandler) {
    // Headset / Bluetooth / lock-screen media buttons follow the same queue
    // logic as the in-app transport controls.
    _audioService.onMediaSkipNext = () => _playNext();
    _audioService.onMediaSkipPrevious = () => playPrevious();
    _init();
  }

  Future<void> _init() async {
    _audioService.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _syncWidget(force: true);
      notifyListeners();
    });

    _audioService.positionStream.listen((pos) {
      _position = pos;
      _syncWidget();
      notifyListeners();
    });

    _audioService.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      _syncWidget();
      notifyListeners();
    });

    // Auto-advance to the next track when the current one completes.
    _audioService.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _playNext(autoAdvance: true);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    _showSpectrum = prefs.getBool(_prefSpectrum) ?? false;
    final dsp = prefs.getBool(_prefDsp);
    if (dsp != null) {
      _audioService.customDspEnabled = dsp;
    }
    final savedMode = prefs.getString(_prefPlayMode);
    for (final m in PlayMode.values) {
      if (m.name == savedMode) _playMode = m;
    }
    _loadLibraryState(prefs);

    final savedFolder = prefs.getString(_prefFolder);
    if (savedFolder != null && folderExists(savedFolder)) {
      _musicFolderPath = savedFolder;
      await _scanFolder(savedFolder, autoPlay: false);
    }
    _syncWidget(force: true);
    notifyListeners();
  }

  /// Feeds the Android home-screen widget with the current track.
  void _syncWidget({bool force = false}) {
    if (!WidgetService.isSupported) return;
    unawaited(WidgetService.push(
      song: _audioService.currentSong,
      playing: _isPlaying,
      position: _position,
      duration: _duration,
      force: force,
    ));
  }

  // ---------------------------------------------------------------------------
  // FOLDER-BASED PLAYLIST
  // ---------------------------------------------------------------------------
  Future<void> pickMusicFolder() async {
    // Android 11+ requires the all-files permission before we can list any
    // user-picked folder. Desktop/web skip this entirely.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final granted = await _ensureStoragePermission();
      if (!granted) {
        _errorMessage = 'Hãy cấp quyền "Music and audio / All files access" cho app trong Cài đặt Android.';
        notifyListeners();
        return;
      }
    }

    String? path;
    try {
      path = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Chọn thư mục nhạc');
    } catch (_) {
      _errorMessage = 'Không mở được hộp thoại chọn thư mục.';
      notifyListeners();
      return;
    }
    if (path == null) return; // user cancelled the dialog

    _musicFolderPath = path;
    _errorMessage = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefFolder, path);
    await _scanFolder(path, autoPlay: true);
    notifyListeners();
  }

  /// Re-scans the saved folder (user may have copied new files into it).
  /// The currently playing track is kept if it is still present.
  Future<void> rescanFolder() async {
    final folder = _musicFolderPath;
    if (folder == null) return;
    _errorMessage = null;
    await _scanFolder(folder, autoPlay: false);
  }

  Future<bool> _ensureStoragePermission() async {
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      final result = await Permission.manageExternalStorage.request();
      if (result.isGranted) return true;
    } catch (_) {}
    // Older Android versions (<= 10): fall back to classic storage permission.
    try {
      if (await Permission.storage.isGranted) return true;
      final result = await Permission.storage.request();
      return result.isGranted;
    } catch (_) {}
    return false;
  }

  /// Android 13+: ask once for notification permission so the media
  /// notification (now-playing card with cover and controls) is visible.
  Future<void> _ensureNotificationPermission() async {
    if (_askedNotificationPermission) return;
    _askedNotificationPermission = true;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }
    } catch (_) {}
  }

  Future<void> _scanFolder(String folderPath, {bool autoPlay = false}) async {
    _isLoadingLibrary = true;
    notifyListeners();
    try {
      if (!folderExists(folderPath)) {
        _playlist = [];
        _librarySongs = [];
        _musicFolderPath = null;
        _currentIndex = -1;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefFolder);
        _errorMessage = 'Thư mục nhạc không còn tồn tại.';
        return;
      }

      final currentPath = _audioService.currentSong?.path;
      final paths = await listAudioFiles(folderPath);
      final songs = <Song>[];
      for (final p in paths) {
        final song = await inspectAudioFile(p);
        if (song != null) songs.add(song);
      }

      _librarySongs = songs;
      // An empty folder is NOT an error: the user may copy music into it later
      // and press the rescan button.
      _playlist = songs;
      _currentIndex =
          currentPath != null ? _playlist.indexWhere((s) => s.path == currentPath) : -1;
      if (autoPlay && _librarySongs.isNotEmpty && _audioService.currentSong == null) {
        await playSong(_librarySongs.first);
      }
      // Extract embedded artwork for the whole playlist in the background so
      // every list row shows its album cover (not just the playing track).
      unawaited(_extractAllCovers());
    } catch (_) {
      _errorMessage = 'Không thể đọc thư mục nhạc (kiểm tra lại quyền truy cập trên thiết bị).';
    } finally {
      _isLoadingLibrary = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // LIBRARY GROUPING
  // ---------------------------------------------------------------------------
  List<Song> get _lib => _librarySongs;

  List<String> get artistNames {
    final set = _lib.map((s) => s.artist.trim()).where((a) => a.isNotEmpty).toSet();
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<Song> songsByArtist(String artist) {
    final list = _lib.where((s) => s.artist.trim() == artist).toList();
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  List<String> get albumNames {
    final set = _lib.map((s) => s.album.trim()).where((a) => a.isNotEmpty).toSet();
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<Song> songsInAlbum(String album) {
    final list = _lib.where((s) => s.album.trim() == album).toList();
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  List<String> get genreNames {
    final set = _lib.map((s) => s.genreLabel).toSet();
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<Song> songsInGenre(String genre) {
    final list = _lib.where((s) => s.genreLabel == genre).toList();
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  List<Song> get allSongsSorted {
    final list = List<Song>.of(_lib);
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  /// Songs ranked by "long time no listen": never played first, then oldest.
  List<Song> get forgottenSongs {
    final scored = _lib.map((s) => (song: s, last: _lastPlayedAt[s.path] ?? -1)).toList();
    scored.sort((a, b) {
      if (a.last == -1 && b.last == -1) {
        return a.song.title.toLowerCase().compareTo(b.song.title.toLowerCase());
      }
      if (a.last == -1) return -1;
      if (b.last == -1) return 1;
      return a.last.compareTo(b.last);
    });
    return scored.take(30).map((e) => e.song).toList();
  }

  // ---------------------------------------------------------------------------
  // CUSTOM COLLECTIONS (user-created albums & playlists)
  // ---------------------------------------------------------------------------
  List<Song> songsInCollection(List<String> paths) {
    final byPath = {for (final s in _lib) s.path: s};
    return paths.map((p) => byPath[p]).whereType<Song>().toList();
  }

  Future<void> createCustomAlbum(String name, List<Song> songs) async {
    final n = name.trim();
    if (n.isEmpty) return;
    _customAlbums[n] = songs.map((s) => s.path).toList();
    await _saveLibraryState();
    notifyListeners();
  }

  Future<void> deleteCustomAlbum(String name) async {
    _customAlbums.remove(name);
    await _saveLibraryState();
    notifyListeners();
  }

  Future<void> createPlaylist(String name, List<Song> songs) async {
    final n = name.trim();
    if (n.isEmpty) return;
    _customPlaylists[n] = songs.map((s) => s.path).toList();
    await _saveLibraryState();
    notifyListeners();
  }

  Future<void> deletePlaylist(String name) async {
    _customPlaylists.remove(name);
    await _saveLibraryState();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PLAYBACK CONTROL
  // ---------------------------------------------------------------------------
  Future<void> playSong(Song song, {List<Song>? queue}) async {
    unawaited(_ensureNotificationPermission());
    if (queue != null && queue.isNotEmpty) {
      _playlist = queue;
    }
    final index = _playlist.indexWhere((s) => s.path == song.path);
    if (index >= 0) {
      _currentIndex = index;
      _position = Duration.zero;
      _duration = song.duration;
    }
    notifyListeners();

    unawaited(_ensureCover(song));

    final ok = await _audioService.loadSong(song);
    if (ok) {
      await _audioService.setRepeatOne(_playMode == PlayMode.repeatOne);
      _recordPlay(song);
    } else {
      _isPlaying = false;
      _errorMessage = song.format == AudioFormat.dsf
          ? 'Stream DSD (.dsf) cần phần cứng giải mã DSD riêng — chưa phát được trực tiếp.'
          : 'Không phát được file: ${song.title}';
    }
    _syncWidget(force: true);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_audioService.currentSong == null) {
      if (_playlist.isNotEmpty) {
        await playSong(_playlist.first);
      }
      return;
    }
    if (_isPlaying) {
      await _audioService.pause();
    } else {
      await _audioService.play();
    }
    notifyListeners();
  }

  Future<void> playNext() => _playNext();

  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;
    // Restart current track when we are a few seconds in, like real players.
    if (_position > const Duration(seconds: 3) && _audioService.currentSong != null) {
      await _audioService.seek(Duration.zero);
      return;
    }
    if (_playMode == PlayMode.shuffle) {
      await _playShuffled();
      return;
    }
    final prev = _resolvePrevIndex();
    await playSong(_playlist[prev]);
  }

  Future<void> _playNext({bool autoAdvance = false}) async {
    if (_playlist.isEmpty) return;
    // Repeat-one: replay the current track (fallback when native loop is
    // unavailable — with LoopMode.one the backend loops before ever
    // reaching the completed state).
    if (autoAdvance && _playMode == PlayMode.repeatOne) {
      final current = _audioService.currentSong;
      if (current != null) {
        await _audioService.seek(Duration.zero);
        await _audioService.play();
        return;
      }
    }
    if (_playMode == PlayMode.shuffle) {
      await _playShuffled();
      return;
    }
    final next = _resolveNextIndex();
    await playSong(_playlist[next]);
  }

  /// Shuffle pool: every song sharing the current song's genre, so shuffle
  /// keeps playing the same style instead of only the opened album.
  /// Falls back to the active queue for tiny genre buckets.
  List<Song> _shufflePool() {
    final cur = _audioService.currentSong;
    if (cur == null) return _playlist;
    final genre = cur.genreLabel;
    final pool = _librarySongs.where((s) => s.genreLabel == genre).toList();
    return pool.length > 1 ? pool : _playlist;
  }

  Future<void> _playShuffled() async {
    final pool = _shufflePool();
    if (pool.isEmpty) return;
    _playlist = pool;
    final curId = _audioService.currentSong?.id;
    var idx = _rng.nextInt(pool.length);
    var guard = 0;
    while (pool.length > 1 && pool[idx].id == curId && guard++ < 10) {
      idx = _rng.nextInt(pool.length);
    }
    await playSong(pool[idx]);
  }

  int _resolveNextIndex() {
    return (_currentIndex + 1) % _playlist.length;
  }

  int _resolvePrevIndex() {
    return (_currentIndex - 1 + _playlist.length) % _playlist.length;
  }

  Future<void> seek(Duration pos) async {
    await _audioService.seek(pos);
  }

  /// Skip forward/backward by a relative amount of seconds (tua đi/tua lại).
  Future<void> seekBy(int seconds) async {
    if (_audioService.currentSong == null) return;
    await _audioService.seekBy(seconds);
  }

  // ---------------------------------------------------------------------------
  // OPTIONS
  // ---------------------------------------------------------------------------
  void cyclePlayMode() {
    switch (_playMode) {
      case PlayMode.sequential:
        _playMode = PlayMode.repeatOne;
      case PlayMode.repeatOne:
        _playMode = PlayMode.shuffle;
      case PlayMode.shuffle:
        _playMode = PlayMode.sequential;
    }
    _audioService.setRepeatOne(_playMode == PlayMode.repeatOne);
    SharedPreferences.getInstance().then((p) => p.setString(_prefPlayMode, _playMode.name));
    notifyListeners();
  }

  void toggleCustomDsp() {
    _audioService.toggleCustomDsp();
    SharedPreferences.getInstance().then((p) => p.setBool(_prefDsp, _audioService.isCustomDspEnabled));
    notifyListeners();
  }

  void toggleSpectrum() {
    _showSpectrum = !_showSpectrum;
    SharedPreferences.getInstance().then((p) => p.setBool(_prefSpectrum, _showSpectrum));
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // LISTENING HISTORY & STATS
  // ---------------------------------------------------------------------------
  void _recordPlay(Song song) {
    _recent.removeWhere((e) => e.song.path == song.path);
    _recent.insert(0, RecentEntry(song: song, playedAtMs: DateTime.now().millisecondsSinceEpoch));
    if (_recent.length > 50) _recent.removeRange(50, _recent.length);
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastPlayedAt[song.path] = now;
    _playCounts[song.path] = (_playCounts[song.path] ?? 0) + 1;
    unawaited(_saveLibraryState());
  }

  int? lastPlayedAtOf(Song song) {
    final v = _lastPlayedAt[song.path];
    return v == null || v <= 0 ? null : v;
  }

  void _loadLibraryState(SharedPreferences prefs) {
    try {
      final recent = prefs.getString(_prefRecent);
      if (recent != null && recent.isNotEmpty) {
        final list = jsonDecode(recent) as List;
        _recent = <RecentEntry>[];
        for (final raw in list) {
          final map = raw as Map<String, dynamic>;
          // Drop legacy entries saved by the removed online mode.
          final songJson = map['song'] as Map<String, dynamic>?;
          if (songJson != null && songJson['on'] == true) continue;
          try {
            _recent.add(RecentEntry.fromJson(map));
          } catch (_) {}
        }
      }
    } catch (_) {}
    try {
      final lp = prefs.getString(_prefLastPlayed);
      if (lp != null && lp.isNotEmpty) {
        final map = jsonDecode(lp) as Map<String, dynamic>;
        _lastPlayedAt = map.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
    } catch (_) {}
    try {
      final pc = prefs.getString(_prefPlayCounts);
      if (pc != null && pc.isNotEmpty) {
        final map = jsonDecode(pc) as Map<String, dynamic>;
        _playCounts = map.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
    } catch (_) {}
    try {
      final ca = prefs.getString(_prefCustomAlbums);
      if (ca != null && ca.isNotEmpty) {
        final map = jsonDecode(ca) as Map<String, dynamic>;
        _customAlbums = map.map((k, v) => MapEntry(k, List<String>.from(v as List)));
      }
      final cp = prefs.getString(_prefCustomPlaylists);
      if (cp != null && cp.isNotEmpty) {
        final map = jsonDecode(cp) as Map<String, dynamic>;
        _customPlaylists = map.map((k, v) => MapEntry(k, List<String>.from(v as List)));
      }
    } catch (_) {}
  }

  Future<void> _saveLibraryState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefRecent, jsonEncode(_recent.map((e) => e.toJson()).toList()));
      await prefs.setString(_prefLastPlayed, jsonEncode(_lastPlayedAt));
      await prefs.setString(_prefPlayCounts, jsonEncode(_playCounts));
      await prefs.setString(_prefCustomAlbums, jsonEncode(_customAlbums));
      await prefs.setString(_prefCustomPlaylists, jsonEncode(_customPlaylists));
    } catch (_) {
      // Library state persistence is best-effort.
    }
  }

  // ---------------------------------------------------------------------------
  // EMBEDDED COVER ART (FLAC PICTURE / ID3v2 APIC)
  // ---------------------------------------------------------------------------
  Future<void> _ensureCover(Song song) async {
    if (song.path.isEmpty || song.coverPath.isNotEmpty) return;
    try {
      final cover = await extractCoverArtFile(song.path);
      if (cover == null) return;
      final updated = song.copyWith(coverPath: cover);
      final idx = _playlist.indexWhere((s) => s.path == song.path);
      if (idx >= 0) {
        _playlist[idx] = updated;
      }
      final libIdx = _librarySongs.indexWhere((s) => s.path == song.path);
      if (libIdx >= 0) {
        _librarySongs[libIdx] = updated;
      }
      if (_audioService.currentSong?.path == song.path) {
        _audioService.currentSong = updated;
        _syncWidget(force: true);
      }
      notifyListeners();
    } catch (_) {
      // Cover art is optional — ignore failures silently.
    }
  }

  /// Walks the library and extracts embedded artwork for every track that
  /// does not have one yet. Runs entirely in the background with a hard cap
  /// so a huge folder cannot hog IO forever, and a re-entrancy guard so a
  /// rescan never starts a second parallel extraction pass.
  Future<void> _extractAllCovers() async {
    if (_coverExtracting) return;
    _coverExtracting = true;
    try {
      final snapshot = List<Song>.of(_librarySongs);
      var processed = 0;
      for (final song in snapshot) {
        if (processed >= 1000) break; // hard cap
        if (song.coverPath.isNotEmpty) continue;
        final cover = await extractCoverArtFile(song.path);
        processed++;
        if (cover == null) continue;
        final idx = _librarySongs.indexWhere((s) => s.path == song.path);
        if (idx < 0) continue; // song was removed by a rescan meanwhile
        final updated = _librarySongs[idx].copyWith(coverPath: cover);
        _librarySongs[idx] = updated;
        if (_playlist != _librarySongs) {
          final qIdx = _playlist.indexWhere((s) => s.path == song.path);
          if (qIdx >= 0) _playlist[qIdx] = updated;
        }
        if (_audioService.currentSong?.path == song.path) {
          _audioService.currentSong = updated;
          _syncWidget(force: true);
        }
        notifyListeners();
      }
    } catch (_) {
      // Cover art is optional — ignore failures silently.
    } finally {
      _coverExtracting = false;
    }
  }
}
