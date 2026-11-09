import 'package:flutter/foundation.dart';

import '../models/track.dart';
import '../ytdlp.dart';

/// Isi Music/Mull dan Movies/Mull di HP, dibaca dari MediaStore.
///
/// Sengaja nggak nyimpan daftar sendiri: MediaStore sudah jadi sumber
/// kebenaran, jadi berkas yang dihapus lewat app lain ikut hilang di sini.
class LibraryService extends ChangeNotifier {
  LibraryService._();
  static final instance = LibraryService._();

  /// Instance bersih buat tes.
  @visibleForTesting
  factory LibraryService.baru() => LibraryService._();

  List<Track> _lagu = const [];
  List<Track> _video = const [];
  bool _memuat = false;
  String? _galat;

  List<Track> get lagu => _lagu;
  List<Track> get video => _video;
  bool get memuat => _memuat;
  String? get galat => _galat;
  bool get kosong => _lagu.isEmpty && _video.isEmpty;

  /// Baca ulang dari MediaStore.
  Future<void> muat() async {
    if (_memuat) return;
    _memuat = true;
    _galat = null;
    notifyListeners();

    try {
      final items = await YtDlp.listLibrary();
      final lagu = <Track>[];
      final video = <Track>[];

      for (final m in items) {
        final t = _dariMediaStore(m);
        (m['video'] == true ? video : lagu).add(t);
      }

      _lagu = lagu;
      _video = video;
    } catch (e) {
      _galat = 'Nggak bisa baca pustaka: $e';
    } finally {
      _memuat = false;
      notifyListeners();
    }
  }

  Future<bool> hapus(Track t) async {
    final uri = t.localPath;
    if (uri == null) return false;
    final ok = await YtDlp.deleteMedia(uri);
    if (ok) {
      _lagu = _lagu.where((e) => e.localPath != uri).toList();
      _video = _video.where((e) => e.localPath != uri).toList();
      notifyListeners();
    }
    return ok;
  }

  /// Judul yang kita tulis waktu mengunduh: `Judul [videoId].ext`.
  /// Dipakai buat memulihkan judul dan id asli dari nama berkas.
  static final _polaNama = RegExp(r'^(.*?)\s*\[([A-Za-z0-9_-]{6,})\]\.[^.]+$');

  static Track _dariMediaStore(Map<String, dynamic> m) {
    final nama = (m['name'] as String?) ?? 'Tanpa nama';
    final cocok = _polaNama.firstMatch(nama);

    final judulTag = (m['title'] as String?)?.trim();
    final judul = (judulTag != null && judulTag.isNotEmpty)
        ? judulTag
        : (cocok?.group(1) ?? nama);

    final ms = (m['durationMs'] as num?)?.toInt();

    return Track(
      // Id video asli kalau namanya masih berpola; kalau nggak, pakai uri.
      id: cocok?.group(2) ?? (m['uri'] as String? ?? nama),
      title: judul,
      artist: (m['artist'] as String?)?.trim(),
      duration: ms != null && ms > 0 ? Duration(milliseconds: ms) : null,
      localPath: m['uri'] as String?,
      isVideo: m['video'] == true,
    );
  }
}
