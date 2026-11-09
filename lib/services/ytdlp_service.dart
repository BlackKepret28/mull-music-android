import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/track.dart';
import '../ytdlp.dart';

enum EngineStatus { belum, nyiapin, siap, gagal }

/// Lapisan di atas [YtDlp]: nyiapin mesin sekali, cari lagu, dan simpan hasil
/// biar nggak ngulang kerja berat.
///
/// Kenapa pencarian cepat tapi pemutaran lambat: `--flat-playlist` cuma minta
/// metadata, jadi yt-dlp nggak perlu jalanin JavaScript. Begitu kita minta URL
/// stream sungguhan, QuickJS harus memecahkan tantangan YouTube dan itu makan
/// 25-35 detik di HP (terukur waktu spike).
class YtDlpService extends ChangeNotifier {
  YtDlpService._();
  static final instance = YtDlpService._();

  /// Instance bersih buat tes. Di app selalu pakai [instance].
  @visibleForTesting
  factory YtDlpService.baru() => YtDlpService._();

  EngineStatus _status = EngineStatus.belum;
  EngineStatus get status => _status;

  String? _version;
  String? get version => _version;

  String? _error;
  String? get error => _error;

  /// Apa yang sedang dikerjakan, buat ditampilkan ke pengguna.
  String _langkah = '';
  String get langkah => _langkah;

  Future<void>? _siapan;

  final _cacheCari = <String, List<Track>>{};
  final _cacheStream = <String, _UrlTersimpan>{};

  void _set(EngineStatus s, {String langkah = '', String? error}) {
    _status = s;
    _langkah = langkah;
    _error = error;
    notifyListeners();
  }

  /// Siapkan Python + yt-dlp + ffmpeg. Aman dipanggil berkali-kali:
  /// kerjaannya cuma jalan sekali per hidup app.
  Future<void> ensureReady() {
    return _siapan ??= _siapkan();
  }

  Future<void> _siapkan() async {
    try {
      _set(EngineStatus.nyiapin, langkah: 'Menyiapkan mesin unduh...');
      await YtDlp.init();

      _version = await YtDlp.version();
      // Null berarti masih yt-dlp bawaan paket, yang umurnya setahun dan
      // biasanya sudah ditolak YouTube. Wajib di-update sekali.
      if (_version == null) {
        _set(EngineStatus.nyiapin, langkah: 'Memperbarui yt-dlp...');
        final r = await YtDlp.update();
        _version = r['version'] as String?;
      }

      _set(EngineStatus.siap);
    } catch (e) {
      _siapan = null; // biar bisa dicoba ulang
      _set(EngineStatus.gagal, error: pesanRamah(e));
      rethrow;
    }
  }

  /// Paksa perbarui yt-dlp (dipanggil dari Pengaturan).
  Future<String?> perbaruiYtDlp() async {
    await ensureReady();
    _set(EngineStatus.nyiapin, langkah: 'Memperbarui yt-dlp...');
    try {
      final r = await YtDlp.update();
      _version = r['version'] as String?;
      _cacheCari.clear();
      _set(EngineStatus.siap);
      return _version;
    } catch (e) {
      _set(EngineStatus.siap);
      throw Exception(pesanRamah(e));
    }
  }

  static final _pola = RegExp(r'^https?://', caseSensitive: false);
  static bool isUrl(String s) => _pola.hasMatch(s.trim());

  /// Cari di YouTube. Cepat: cuma metadata, tanpa JavaScript.
  ///
  /// Kalau [query] ternyata tautan, yang diambil info tautan itu sendiri —
  /// dan ini LAMBAT (QuickJS), jadi tampilkan indikator yang jujur.
  Future<List<Track>> search(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final kunci = '$q|$limit';
    final tersimpan = _cacheCari[kunci];
    if (tersimpan != null) return tersimpan;

    await ensureReady();

    final hasil = isUrl(q) ? await _infoTautan(q) : await _cariKata(q, limit);
    _cacheCari[kunci] = hasil;
    return hasil;
  }

  Future<List<Track>> _cariKata(String q, int limit) async {
    try {
      final r = await YtDlp.getInfo(
        'ytsearch$limit:$q',
        args: const ['--flat-playlist', '--no-warnings'],
      );
      final entries = (r.info['entries'] as List? ?? const []);
      return entries
          .whereType<Map>()
          .map((e) => Track.fromYtDlp(Map<String, dynamic>.from(e)))
          .where((t) => t.id.isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      throw Exception(pesanRamah(e));
    }
  }

  Future<List<Track>> _infoTautan(String url) async {
    try {
      final r = await YtDlp.getInfo(url, args: const ['--no-playlist', '--no-warnings']);
      final info = r.info;
      // Tautan playlist tetap bisa masuk sini kalau --no-playlist diabaikan.
      final entries = info['entries'] as List?;
      if (entries != null) {
        return entries
            .whereType<Map>()
            .map((e) => Track.fromYtDlp(Map<String, dynamic>.from(e)))
            .where((t) => t.id.isNotEmpty)
            .toList(growable: false);
      }
      return [Track.fromYtDlp(info)];
    } catch (e) {
      throw Exception(pesanRamah(e));
    }
  }

  /// Format audio yang diminta: utamakan m4a (paling aman diputar Android),
  /// baru opus, baru apa pun yang ada.
  static const _formatAudio = 'bestaudio[ext=m4a]/bestaudio[acodec=opus]/bestaudio';

  /// Video: utamakan H.264 (avc1) daripada AV1 supaya HP lama nggak tersiksa.
  static const _formatVideo =
      'bv*[height<=720][vcodec^=avc1]+ba[ext=m4a]/b[height<=720][vcodec^=avc1]/bv*[height<=720]+ba/b[height<=720]';

  /// Klien YouTube yang biasanya nggak butuh JavaScript buat kasih URL.
  /// Kalau gagal, kita ulang tanpa ini dan biarkan QuickJS kerja (lambat).
  static const _klienCepat = ['--extractor-args', 'youtube:player_client=android_vr,web_safari'];

  /// URL stream langsung buat diputar just_audio.
  ///
  /// Ini bagian yang mahal: tanpa jalur cepat, QuickJS butuh 25-35 detik.
  /// Hasilnya disimpan karena URL YouTube berlaku beberapa jam.
  Future<String> streamUrl(Track t, {bool video = false}) async {
    final kunci = '${t.id}|$video';
    final tersimpan = _cacheStream[kunci];
    if (tersimpan != null && !tersimpan.kedaluwarsa) return tersimpan.url;

    await ensureReady();

    final format = video ? _formatVideo : _formatAudio;
    final url = t.resolvableUrl;

    // Coba jalur cepat dulu, baru jalur QuickJS.
    Object? galatTerakhir;
    for (final cepat in [true, false]) {
      try {
        final args = <String>[
          '-g',
          '-f',
          format,
          '--no-playlist',
          '--no-warnings',
          if (cepat) ..._klienCepat,
          url,
        ];
        final r = await YtDlp.exec(args);
        if (r['exitCode'] != 0) {
          galatTerakhir = Exception((r['err'] as String?) ?? 'exit ${r['exitCode']}');
          continue;
        }
        // `-g` nyetak satu URL per baris. Buat audio cuma ada satu;
        // buat video bisa dua (video + audio terpisah).
        final baris = (r['out'] as String? ?? '')
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.startsWith('http'))
            .toList();
        if (baris.isEmpty) {
          galatTerakhir = Exception('yt-dlp nggak ngasih URL');
          continue;
        }
        _cacheStream[kunci] = _UrlTersimpan(baris.first);
        return baris.first;
      } catch (e) {
        galatTerakhir = e;
      }
    }

    throw Exception(pesanRamah(galatTerakhir ?? 'Gagal ambil URL'));
  }

  /// Siapkan URL di latar belakang supaya lagu berikutnya nggak nunggu.
  /// Sengaja nggak melempar galat: ini cuma usaha tambahan.
  void prefetch(Track t, {bool video = false}) {
    final kunci = '${t.id}|$video';
    final ada = _cacheStream[kunci];
    if (ada != null && !ada.kedaluwarsa) return;
    streamUrl(t, video: video).ignore();
  }

  /// Ubah pesan error yt-dlp jadi bahasa yang kebaca pengguna.
  static String pesanRamah(Object e) {
    final s = e.toString();
    final l = s.toLowerCase();

    if (l.contains('unable to download') || l.contains('failed to resolve') || l.contains('network')) {
      return 'Nggak bisa nyambung ke internet. Cek koneksi kamu.';
    }
    if (l.contains('no space') || l.contains('enospc')) {
      return 'Ruang penyimpanan HP habis. Hapus beberapa file dulu.';
    }
    if (l.contains('no supported javascript runtime')) {
      return 'Mesin JavaScript nggak kebaca. Coba buka ulang app.';
    }
    if (l.contains('sign in to confirm') || l.contains('bot')) {
      return 'YouTube minta verifikasi buat video ini. Coba lagu lain dulu.';
    }
    if (l.contains('video unavailable') || l.contains('private')) {
      return 'Video ini nggak tersedia atau disetel privat.';
    }
    if (l.contains('unsupported url')) {
      return 'Tautan ini belum didukung.';
    }
    // Sisanya: tampilkan ringkas, jangan buang info buat diagnosa.
    final bersih = s.replaceFirst('Exception: ', '').trim();
    return bersih.length > 160 ? '${bersih.substring(0, 160)}...' : bersih;
  }
}

/// URL stream + kapan dia dianggap basi.
class _UrlTersimpan {
  _UrlTersimpan(this.url) : dibuat = DateTime.now();

  final String url;
  final DateTime dibuat;

  /// URL YouTube biasanya tahan ~6 jam. Dipotong 3 jam biar aman.
  bool get kedaluwarsa => DateTime.now().difference(dibuat) > const Duration(hours: 3);
}
