import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/track.dart';
import '../ytdlp.dart';
import 'library_service.dart';
import 'ytdlp_service.dart';

enum StatusUnduhan { antre, jalan, selesai, gagal, dibatalkan }

/// Satu baris di layar Unduhan.
class Unduhan {
  Unduhan({required this.track, required this.video});

  final Track track;
  final bool video;

  StatusUnduhan status = StatusUnduhan.antre;

  /// 0..100, atau -1 kalau yt-dlp belum ngasih angka.
  double progress = -1;

  /// Perkiraan sisa detik dari yt-dlp.
  int eta = 0;

  String? galat;

  /// Nama berkas hasil, terisi kalau sudah selesai.
  String? namaBerkas;
  int? ukuran;

  /// Id yang dipakai yt-dlp buat membatalkan proses.
  String get id => '${video ? 'v' : 'a'}_${track.id}';

  bool get sedangJalan => status == StatusUnduhan.jalan;
  bool get bisaDibatalkan => status == StatusUnduhan.antre || status == StatusUnduhan.jalan;
}

/// Antrean unduhan. Satu berkas sekali jalan, karena yt-dlp + ffmpeg di HP
/// sudah cukup berat dan unduhan paralel malah bikin semuanya lambat.
class DownloadService extends ChangeNotifier {
  DownloadService._() {
    // Kalau channel-nya nggak ada (mis. di tes) atau putus, antreannya tetap
    // jalan; cuma angka progresnya yang hilang.
    _sub = YtDlp.progress.listen(_kabarProgres, onError: (Object _) {});
  }
  static final instance = DownloadService._();

  /// Instance bersih buat tes.
  @visibleForTesting
  factory DownloadService.baru() => DownloadService._();

  final _yt = YtDlpService.instance;
  late final StreamSubscription<YtDlpProgress> _sub;

  final List<Unduhan> _antrean = [];
  List<Unduhan> get antrean => List.unmodifiable(_antrean);

  bool _sibuk = false;

  /// Format audio pilihan pengguna (`m4a` atau `opus`).
  String formatAudio = 'm4a';

  Unduhan? _cari(bool Function(Unduhan) cocok) {
    for (final u in _antrean) {
      if (cocok(u)) return u;
    }
    return null;
  }

  void _kabarProgres(YtDlpProgress p) {
    final u = _cari((e) => e.id == p.id);
    if (u == null) return;
    u.progress = p.progress;
    u.eta = p.eta;
    notifyListeners();
  }

  /// Masukkan ke antrean. Kalau lagu itu sudah antre, nggak digandakan.
  void tambah(Track t, {bool video = false}) {
    final id = '${video ? 'v' : 'a'}_${t.id}';
    final ada = _cari((e) => e.id == id);
    if (ada != null && ada.bisaDibatalkan) return;

    _antrean.insert(0, Unduhan(track: t, video: video));
    notifyListeners();
    _jalanin();
  }

  Future<void> batal(Unduhan u) async {
    if (u.status == StatusUnduhan.jalan) {
      await YtDlp.cancel(u.id);
    }
    u.status = StatusUnduhan.dibatalkan;
    notifyListeners();
  }

  void hapusDariDaftar(Unduhan u) {
    _antrean.remove(u);
    notifyListeners();
  }

  void bersihkanSelesai() {
    _antrean.removeWhere((e) => e.status == StatusUnduhan.selesai);
    notifyListeners();
  }

  Future<void> ulangi(Unduhan u) async {
    u
      ..status = StatusUnduhan.antre
      ..progress = -1
      ..galat = null;
    notifyListeners();
    await _jalanin();
  }

  Future<void> _jalanin() async {
    if (_sibuk) return;
    _sibuk = true;
    try {
      while (true) {
        // Yang paling bawah = paling lama antre (baru selalu disisipkan di atas).
        Unduhan? u;
        for (final e in _antrean) {
          if (e.status == StatusUnduhan.antre) u = e;
        }
        if (u == null) break;
        await _kerjakan(u);
      }
    } finally {
      _sibuk = false;
    }
  }

  Future<void> _kerjakan(Unduhan u) async {
    u
      ..status = StatusUnduhan.jalan
      ..progress = -1;
    notifyListeners();

    try {
      await _yt.ensureReady();

      final r = await YtDlp.downloadMedia(
        u.id,
        u.track.resolvableUrl,
        video: u.video,
        args: u.video ? _argsVideo : _argsAudio(formatAudio),
      );

      final files = ((r['files'] as List?) ?? const []).whereType<Map>().toList();
      if (files.isEmpty) {
        throw Exception((r['err'] as String?) ?? 'yt-dlp nggak menghasilkan berkas');
      }

      final f = files.first;
      u
        ..status = StatusUnduhan.selesai
        ..progress = 100
        ..namaBerkas = f['name'] as String?
        ..ukuran = (f['size'] as num?)?.toInt();

      // Berkas baru sudah masuk MediaStore, jadi Pustaka perlu dibaca ulang.
      LibraryService.instance.muat().ignore();
    } catch (e) {
      // Dibatalkan pengguna bukan kegagalan.
      if (u.status == StatusUnduhan.dibatalkan) return;
      u
        ..status = StatusUnduhan.gagal
        ..galat = YtDlpService.pesanRamah(e);
    } finally {
      notifyListeners();
    }
  }

  static List<String> _argsAudio(String format) => [
        '-f',
        format == 'opus'
            ? 'bestaudio[acodec=opus]/bestaudio[ext=m4a]/bestaudio'
            : 'bestaudio[ext=m4a]/bestaudio[acodec=opus]/bestaudio',
        // Tanam judul dan artis ke berkasnya biar app musik lain bisa baca.
        '--embed-metadata',
        '--embed-thumbnail',
      ];

  /// 720p H.264 supaya aman diputar HP lama (AV1 sering patah-patah).
  static const _argsVideo = [
    '-f',
    'bv*[height<=720][vcodec^=avc1]+ba[ext=m4a]/b[height<=720][vcodec^=avc1]/bv*[height<=720]+ba/b[height<=720]',
    '--merge-output-format',
    'mp4',
    '--embed-metadata',
  ];

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
