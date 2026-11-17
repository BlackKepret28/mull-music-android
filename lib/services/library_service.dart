import 'package:flutter/foundation.dart';

import '../models/track.dart';
import '../ytdlp.dart';

enum HasilHapus { terhapus, dibatalkan, gagal }

/// Lagu dan video di HP, dibaca dari MediaStore.
///
/// Tanpa izin baca audio: cuma Music/Mull dan Movies/Mull (unduhan Mull).
/// Dengan izin: SEMUA lagu di HP ikut masuk Pustaka (permintaan Mulya,
/// 12 Nov), video tetap cuma Movies/Mull.
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
  Set<String> _milikMull = const {};
  Set<String> _milikApp = const {};
  bool _semua = false;
  bool _memuat = false;
  String? _galat;

  /// Semua lagu (unduhan Mull + lagu lain di HP kalau izinnya ada).
  List<Track> get lagu => _lagu;

  /// Cuma unduhan Mull (Music/Mull).
  List<Track> get laguMull => _lagu.where(milikMull).toList();

  /// Berkas ini hasil unduhan Mull (ada di Music/Mull atau Movies/Mull)?
  bool milikMull(Track t) => t.localPath != null && _milikMull.contains(t.localPath);

  /// Dibuat oleh pemasangan app yang sekarang, jadi bisa dihapus tanpa
  /// dialog konfirmasi dari Android. Lagu lain di HP (dan unduhan Mull dari
  /// sebelum app dipasang ulang) tetap bisa dihapus, tapi Android nanya dulu.
  bool milikApp(Track t) => t.localPath != null && _milikApp.contains(t.localPath);

  /// Izin baca semua lagu di HP sudah diberikan.
  bool get semuaLagu => _semua;

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
      _semua = await YtDlp.hasAudioPermission().catchError((_) => false);
      final items = await YtDlp.listLibrary();
      final lagu = <Track>[];
      final video = <Track>[];
      final milik = <String>{};
      final punyaApp = <String>{};

      for (final m in items) {
        final t = dariMediaStore(m);
        (m['video'] == true ? video : lagu).add(t);
        if (m['mull'] == true && t.localPath != null) milik.add(t.localPath!);
        if (m['own'] == true && t.localPath != null) punyaApp.add(t.localPath!);
      }

      _lagu = lagu;
      _video = video;
      _milikMull = milik;
      _milikApp = punyaApp;
    } catch (e) {
      _galat = 'Nggak bisa baca pustaka: $e';
    } finally {
      _memuat = false;
      notifyListeners();
    }
  }

  /// Minta izin baca semua lagu, lalu muat ulang kalau diizinkan.
  /// Balikin false kalau ditolak.
  Future<bool> mintaIzinSemua() async {
    final ok = await YtDlp.ensureAudioPermission().catchError((_) => false);
    if (ok) {
      _semua = true;
      await muat();
    }
    return ok;
  }

  /// Hapus berkas dari HP. Lagu yang bukan buatan app ini memunculkan
  /// dialog konfirmasi Android dulu.
  Future<HasilHapus> hapus(Track t) async {
    final uri = t.localPath;
    if (uri == null) return HasilHapus.gagal;
    final r = await YtDlp.deleteMedia(uri);
    if (r.dibatalkan) return HasilHapus.dibatalkan;
    if (!r.terhapus) return HasilHapus.gagal;
    lepas(uri);
    return HasilHapus.terhapus;
  }

  /// Buang satu berkas dari daftar di memori (sudah dihapus di luar).
  void lepas(String uri) {
    _lagu = _lagu.where((e) => e.localPath != uri).toList();
    _video = _video.where((e) => e.localPath != uri).toList();
    notifyListeners();
  }

  /// Judul yang kita tulis waktu mengunduh: `Judul [videoId].ext`.
  /// Dipakai buat memulihkan judul dan id asli dari nama berkas.
  static final _polaNama = RegExp(r'^(.*?)\s*\[([A-Za-z0-9_-]{6,})\]\.[^.]+$');

  @visibleForTesting
  static Track dariMediaStore(Map<String, dynamic> m) {
    final nama = (m['name'] as String?) ?? 'Tanpa nama';
    final cocok = _polaNama.firstMatch(nama);

    final judulTag = (m['title'] as String?)?.trim();
    final judul = (judulTag != null && judulTag.isNotEmpty)
        ? judulTag
        : (cocok?.group(1) ?? nama.replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,4}$'), ''));

    final ms = (m['durationMs'] as num?)?.toInt();

    return Track(
      // Id video asli kalau namanya masih berpola; kalau nggak, pakai uri.
      id: cocok?.group(2) ?? (m['uri'] as String? ?? nama),
      title: judul,
      artist: _artis(m['artist'] as String?),
      duration: ms != null && ms > 0 ? Duration(milliseconds: ms) : null,
      // Sampul bawaan berkas, dibaca lewat Android (lihat GambarSampul).
      thumbUrl: m['uri'] as String?,
      localPath: m['uri'] as String?,
      isVideo: m['video'] == true,
    );
  }

  /// MediaStore menulis `<unknown>` kalau tag artisnya kosong.
  static String? _artis(String? a) {
    final x = a?.trim();
    if (x == null || x.isEmpty || x == '<unknown>') return null;
    return x;
  }
}
