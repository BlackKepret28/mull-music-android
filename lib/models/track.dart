/// Satu lagu atau video, dari hasil cari maupun dari file yang sudah diunduh.
///
/// Dipakai di hasil Cari, antrean pemutar, Pustaka, dan playlist.
/// Bentuk JSON-nya dijaga mirip `playlists.json` versi Windows supaya
/// nanti gampang disinkronkan.
class Track {
  const Track({
    required this.id,
    required this.title,
    this.artist,
    this.thumbUrl,
    this.duration,
    this.webpageUrl,
    this.localPath,
    this.isVideo = false,
    this.iid,
  });

  /// Id item di playlist (sama dengan `iid` versi Windows). Dipakai sinkron
  /// akun supaya item yang sama di HP dan laptop dikenali sebagai satu item.
  final String? iid;

  /// Id sumber. Buat YouTube ini id video (11 karakter).
  final String id;
  final String title;
  final String? artist;
  final String? thumbUrl;
  final Duration? duration;

  /// Halaman asalnya, buat dikasih ke yt-dlp.
  final String? webpageUrl;

  /// Terisi kalau file-nya sudah ada di HP.
  final String? localPath;

  final bool isVideo;

  bool get isDownloaded => localPath != null;

  /// Url yang aman dikasih ke yt-dlp, walau `webpageUrl` kosong.
  String get resolvableUrl => webpageUrl ?? 'https://www.youtube.com/watch?v=$id';

  Track copyWith({
    String? title,
    String? artist,
    String? thumbUrl,
    Duration? duration,
    String? webpageUrl,
    String? localPath,
    bool? isVideo,
    String? iid,
  }) {
    return Track(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      duration: duration ?? this.duration,
      webpageUrl: webpageUrl ?? this.webpageUrl,
      localPath: localPath ?? this.localPath,
      isVideo: isVideo ?? this.isVideo,
      iid: iid ?? this.iid,
    );
  }

  /// Dari satu entri hasil `yt-dlp -J` (baik hasil cari maupun info satu video).
  factory Track.fromYtDlp(Map<String, dynamic> j) {
    final secs = j['duration'];
    return Track(
      id: (j['id'] ?? '') as String,
      title: (j['title'] ?? 'Tanpa judul') as String,
      artist: (j['artist'] ?? j['uploader'] ?? j['channel']) as String?,
      thumbUrl: _bestThumb(j),
      duration: secs is num && secs > 0 ? Duration(seconds: secs.round()) : null,
      webpageUrl: (j['webpage_url'] ?? j['url']) as String?,
      isVideo: j['vcodec'] != null && j['vcodec'] != 'none',
    );
  }

  static String? _bestThumb(Map<String, dynamic> j) {
    final one = j['thumbnail'];
    if (one is String && one.isNotEmpty) return one;
    final list = j['thumbnails'];
    if (list is List && list.isNotEmpty) {
      final last = list.last;
      if (last is Map && last['url'] is String) return last['url'] as String;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (artist != null) 'artist': artist,
        if (thumbUrl != null) 'thumb': thumbUrl,
        if (duration != null) 'duration': duration!.inSeconds,
        if (webpageUrl != null) 'url': webpageUrl,
        if (localPath != null) 'path': localPath,
        if (isVideo) 'video': true,
        if (iid != null) 'iid': iid,
      };

  factory Track.fromJson(Map<String, dynamic> j) {
    final secs = j['duration'];
    return Track(
      id: (j['id'] ?? '') as String,
      title: (j['title'] ?? 'Tanpa judul') as String,
      artist: j['artist'] as String?,
      thumbUrl: j['thumb'] as String?,
      duration: secs is num && secs > 0 ? Duration(seconds: secs.round()) : null,
      webpageUrl: j['url'] as String?,
      localPath: j['path'] as String?,
      isVideo: j['video'] == true,
      iid: j['iid'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is Track && other.id == id && other.localPath == localPath;

  @override
  int get hashCode => Object.hash(id, localPath);
}

/// Format durasi jadi `m:ss` atau `h:mm:ss`.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}
