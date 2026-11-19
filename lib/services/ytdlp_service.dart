import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/track.dart';
import '../ytdlp.dart';
import 'innertube.dart';
import 'log_service.dart';

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

  /// Diisi dari pengaturan waktu start: yt-dlp terakhir diperbarui lebih dari
  /// seminggu lalu, jadi sebaiknya diperbarui lagi.
  bool perluUpdateBerkala = false;

  /// Dipanggil setelah update berhasil, buat nyatet tanggalnya.
  void Function()? onDiperbarui;

  final _cacheCari = <String, List<Track>>{};
  final _cacheStream = <String, _UrlTersimpan>{};

  /// Permintaan URL yang lagi dikerjakan. Kalau prefetch lagu berikutnya
  /// masih jalan lalu pengguna menekan lagu itu, dia menumpang di proses yang
  /// sama (dulu jadi dua proses yt-dlp, dua kali 30 detik).
  final _sedangDiambil = <String, _Permintaan>{};

  /// Header yang harus ikut waktu URL dari jalur kilat diputar (User-Agent
  /// klien yang dipakai waktu minta URL-nya).
  final _headerUrl = <String, Map<String, String>>{};
  Map<String, String>? headerUntuk(String url) => _headerUrl[url];

  /// Berapa kali berturut-turut jalur kilat gagal. Kalau sering, YouTube
  /// kemungkinan berubah: yt-dlp nggak perlu menunggu lagi.
  int _kilatGagalBeruntun = 0;

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
      // biasanya sudah ditolak YouTube. Yang ini WAJIB nunggu.
      if (_version == null) {
        _set(EngineStatus.nyiapin, langkah: 'Memperbarui yt-dlp...');
        final r = await YtDlp.update();
        _version = r['version'] as String?;
        onDiperbarui?.call();
        _set(EngineStatus.siap);
        return;
      }

      // Sudah punya yt-dlp yang kepakai: langsung dinyatakan siap, dan
      // update mingguannya dikerjakan di belakang layar. Dulu ini ikut
      // ditunggu, jadi pencarian pertama tiap minggu kena waktu unduh
      // yt-dlp yang nggak ada hubungannya sama pencarian itu.
      _set(EngineStatus.siap);
      if (perluUpdateBerkala) _updateDiamDiam();
    } catch (e) {
      _siapan = null; // biar bisa dicoba ulang
      _set(EngineStatus.gagal, error: pesanRamah(e));
      rethrow;
    }
  }

  /// Perbarui yt-dlp tanpa menahan siapa pun. Gagal (mis. internet mati)
  /// dibiarkan: yt-dlp yang lama masih bisa dipakai sampai minggu depan.
  Future<void> _updateDiamDiam() async {
    try {
      final r = await YtDlp.update();
      final baru = r['version'] as String?;
      if (baru != null && baru != _version) {
        _version = baru;
        // Hasil lama bisa jadi dari yt-dlp yang sudah usang.
        _cacheStream.clear();
        notifyListeners();
      }
      onDiperbarui?.call();
    } catch (_) {
      // Coba lagi lain kali.
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
      _cacheStream.clear();
      onDiperbarui?.call();
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

  /// Video buat DIPUTAR LANGSUNG harus satu URL yang sudah berisi gambar dan
  /// suara. Format `bv*+ba` ngasih dua URL terpisah (video saja + audio
  /// saja), dan pemutar cuma kebagian yang pertama = video bisu. HLS
  /// campuran (m3u8) YouTube bisa sampai 720p dan didukung ExoPlayer, jadi
  /// kualitasnya nggak turun ke 360p. Urutan: HLS H.264 -> HLS apa saja ->
  /// berkas campuran biasa.
  static const _formatVideo =
      'b[height<=720][protocol^=m3u8][vcodec^=avc1]/b[height<=720][protocol^=m3u8]/b[height<=720][vcodec^=avc1]/b[height<=720]/b';

  /// Klien YouTube yang biasanya nggak butuh JavaScript buat kasih URL.
  /// Kalau gagal, kita ulang tanpa ini dan biarkan QuickJS kerja (lambat).
  static const _klienCepat = ['--extractor-args', 'youtube:player_client=android_vr,web_safari'];

  /// URL stream langsung buat diputar just_audio.
  ///
  /// Audio YouTube: coba jalur kilat dulu ([Innertube], ~1 detik, tanpa
  /// Python). yt-dlp ikut jalan kalau jalur kilat gagal atau belum selesai
  /// dalam 2,5 detik, dan yang duluan dapat menang. Video selalu lewat
  /// yt-dlp. Hasilnya disimpan karena URL YouTube berlaku beberapa jam.
  Future<String> streamUrl(Track t, {bool video = false, bool boleYtDlp = true}) {
    final kunci = '${t.id}|$video';
    final tersimpan = _cacheStream[kunci];
    if (tersimpan != null && !tersimpan.kedaluwarsa) return Future.value(tersimpan.url);

    final jalan = _sedangDiambil[kunci];
    if (jalan != null) {
      // Prefetch "kilat saja" lagi jalan lalu pengguna menekan lagu itu:
      // numpang dulu, dan kalau gagal ulangi dengan yt-dlp penuh.
      if (boleYtDlp && !jalan.penuh) {
        return jalan.hasil.catchError((Object _) => _mulai(t, kunci, video, true).hasil);
      }
      return jalan.hasil;
    }
    return _mulai(t, kunci, video, boleYtDlp).hasil;
  }

  _Permintaan _mulai(Track t, String kunci, bool video, bool boleYtDlp) {
    final f = (video ? _ambilDariYtDlp(t, kunci, true) : _balapan(t, kunci, boleYtDlp))
        .whenComplete(() => _sedangDiambil.remove(kunci));
    final p = _Permintaan(f, video || boleYtDlp);
    _sedangDiambil[kunci] = p;
    return p;
  }

  /// Jalur kilat vs yt-dlp. yt-dlp baru dimulai kalau jalur kilat gagal atau
  /// lambat, jadi kalau jalur kilat sehat, HP nggak menjalankan Python sama
  /// sekali.
  Future<String> _balapan(Track t, String kunci, bool boleYtDlp) {
    if (!Innertube.bisaDipakai(t.id)) return _ambilDariYtDlp(t, kunci, false);

    final hasil = Completer<String>();
    var ytdlpJalan = false;

    void mulaiYtDlp() {
      if (ytdlpJalan || hasil.isCompleted) return;
      ytdlpJalan = true;
      final mulaiYt = DateTime.now();
      _ambilDariYtDlp(t, kunci, false).then((u) {
        LogService.instance.catat('url', 'yt-dlp OK ${DateTime.now().difference(mulaiYt).inMilliseconds} ms (${t.id})');
        if (!hasil.isCompleted) hasil.complete(u);
      }, onError: (Object e, StackTrace s) {
        if (!hasil.isCompleted) hasil.completeError(e, s);
      });
    }

    final mulai = DateTime.now();
    Innertube.audio(t.id).then((u) {
      LogService.instance.catat('url', 'kilat OK ${DateTime.now().difference(mulai).inMilliseconds} ms (${t.id})');
      _kilatGagalBeruntun = 0;
      _headerUrl[u] = const {'User-Agent': Innertube.userAgent};
      _cacheStream[kunci] = _UrlTersimpan(u);
      if (!hasil.isCompleted) hasil.complete(u);
    }, onError: (Object e, StackTrace s) {
      LogService.instance.catat('url', 'kilat GAGAL (${t.id}): $e');
      _kilatGagalBeruntun++;
      if (boleYtDlp) {
        mulaiYtDlp();
      } else if (!hasil.isCompleted) {
        hasil.completeError(e, s);
      }
    });

    if (boleYtDlp) {
      if (_kilatGagalBeruntun >= 3) {
        mulaiYtDlp();
      } else {
        Timer(const Duration(milliseconds: 2500), mulaiYtDlp);
      }
    }
    return hasil.future;
  }

  Future<String> _ambilDariYtDlp(Track t, String kunci, bool video) async {
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
          // Gagal cepat kalau jaringan macet, biar jalur cadangan nggak telat.
          '--socket-timeout',
          '10',
          '--retries',
          '1',
          if (cepat) ..._klienCepat,
          url,
        ];
        final r = await YtDlp.exec(args);
        if (r['exitCode'] != 0) {
          galatTerakhir = Exception((r['err'] as String?) ?? 'exit ${r['exitCode']}');
          continue;
        }
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
  /// Sengaja nggak melempar galat: ini cuma usaha tambahan. [boleYtDlp] false
  /// = cuma jalur kilat (murah), buat tebak-tebakan seperti hasil pencarian.
  void prefetch(Track t, {bool video = false, bool boleYtDlp = true}) {
    final kunci = '${t.id}|$video';
    final ada = _cacheStream[kunci];
    if (ada != null && !ada.kedaluwarsa) return;
    streamUrl(t, video: video, boleYtDlp: boleYtDlp).ignore();
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

/// Permintaan URL yang lagi jalan. [penuh] = sudah boleh jatuh ke yt-dlp.
class _Permintaan {
  _Permintaan(this.hasil, this.penuh);

  final Future<String> hasil;
  final bool penuh;
}
