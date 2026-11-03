enum AudioFormat { mp3, flac, wav, dsf, aac, ogg, m4a, unknown }

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String path; // local file path
  final Duration duration;
  final AudioFormat format;
  final int sampleRate; // e.g., 44100, 96000, 192000, 2822400 (for DSD64)
  final int bitDepth;   // e.g., 16, 24, 32, 1 (for DSD)
  final bool isHiRes;
  final String coverPath; // Extracted embedded artwork (FLAC PICTURE / ID3v2 APIC)
  final String genre;     // Parsed genre tag (VORBIS_COMMENT / ID3v2 TCON)

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.duration,
    required this.format,
    required this.sampleRate,
    required this.bitDepth,
    required this.isHiRes,
    this.coverPath = '',
    this.genre = '',
  });

  Song copyWith({
    String? coverPath,
    Duration? duration,
    String? path,
  }) =>
      Song(
        id: id,
        title: title,
        artist: artist,
        album: album,
        path: path ?? this.path,
        duration: duration ?? this.duration,
        format: format,
        sampleRate: sampleRate,
        bitDepth: bitDepth,
        isHiRes: isHiRes,
        coverPath: coverPath ?? this.coverPath,
        genre: genre,
      );

  String get genreLabel => genre.trim().isEmpty ? 'Chưa phân loại' : genre.trim();

  String get formatString {
    switch (format) {
      case AudioFormat.dsf:
        return sampleRate >= 5644800 ? 'DSD128 (5.6MHz)' : 'DSD64 (2.8MHz)';
      case AudioFormat.flac:
        return 'FLAC Hi-Res';
      case AudioFormat.wav:
        return 'WAV Master';
      case AudioFormat.mp3:
        return 'MP3 Lossy';
      default:
        return format.name.toUpperCase();
    }
  }

  String get specsLabel {
    if (format == AudioFormat.dsf) {
      return '1-bit / ${sampleRate ~/ 1000} kHz DSD Stream';
    }
    return '$bitDepth-bit / ${sampleRate / 1000} kHz';
  }

  String get durationLabel {
    if (duration <= Duration.zero) return '';
    final m = duration.inMinutes.remainder(60).toString();
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'path': path,
        'ms': duration.inMilliseconds,
        'fmt': format.name,
        'sr': sampleRate,
        'bd': bitDepth,
        'hr': isHiRes,
        'cov': coverPath,
        'gen': genre,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        artist: (j['artist'] ?? '') as String,
        album: (j['album'] ?? '') as String,
        path: (j['path'] ?? '') as String,
        duration: Duration(milliseconds: (j['ms'] ?? 0) as int),
        format: AudioFormat.values
            .firstWhere((f) => f.name == (j['fmt'] ?? ''), orElse: () => AudioFormat.unknown),
        sampleRate: (j['sr'] ?? 44100) as int,
        bitDepth: (j['bd'] ?? 16) as int,
        isHiRes: (j['hr'] ?? false) as bool,
        coverPath: (j['cov'] ?? '') as String,
        genre: (j['gen'] ?? '') as String,
      );
}

/// One entry of the listening history: the song plus when it was played.
class RecentEntry {
  final Song song;
  final int playedAtMs;

  const RecentEntry({required this.song, required this.playedAtMs});

  Map<String, dynamic> toJson() => {'song': song.toJson(), 'at': playedAtMs};

  factory RecentEntry.fromJson(Map<String, dynamic> j) => RecentEntry(
        song: Song.fromJson((j['song'] ?? const {}) as Map<String, dynamic>),
        playedAtMs: (j['at'] ?? 0) as int,
      );
}
