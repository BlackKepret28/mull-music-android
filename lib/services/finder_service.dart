import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import '../ytdlp.dart';
import 'lyrics_service.dart';
import 'pencocok.dart';
import 'shazam_signature.dart';
import 'ytdlp_service.dart';

/// Lagu yang berhasil dikenali.
class LaguDikenali {
  LaguDikenali({
    required this.id,
    required this.key,
    required this.judul,
    required this.artis,
    required this.waktu,
    required this.sumber,
    this.album,
    this.tahun,
    this.genre,
    this.sampul,
    this.shazamUrl,
    this.lirik,
    this.yt,
  });

  final String id;
  final String key;
  final String judul;
  final String artis;
  final String? album;
  final String? tahun;
  final String? genre;
  final String? sampul;
  final String? shazamUrl;

  /// Lirik polos dari Shazam, kalau ada.
  final String? lirik;
  final DateTime waktu;

  /// `mic`, `file`, atau `link`.
  final String sumber;

  /// Pasangannya di YouTube, buat diputar/diunduh.
  Track? yt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'title': judul,
        'artist': artis,
        if (album != null) 'album': album,
        if (tahun != null) 'year': tahun,
        if (genre != null) 'genre': genre,
        if (sampul != null) 'cover': sampul,
        if (shazamUrl != null) 'shazamUrl': shazamUrl,
        'at': waktu.millisecondsSinceEpoch / 1000,
        'source': sumber,
        'yt': yt?.toJson(),
      };

  factory LaguDikenali.fromJson(Map<String, dynamic> j) => LaguDikenali(
        id: (j['id'] ?? '') as String,
        key: (j['key'] ?? '') as String,
        judul: (j['title'] ?? 'Tanpa judul') as String,
        artis: (j['artist'] ?? '') as String,
        album: j['album'] as String?,
        tahun: j['year'] as String?,
        genre: j['genre'] as String?,
        sampul: j['cover'] as String?,
        shazamUrl: j['shazamUrl'] as String?,
        waktu: DateTime.fromMillisecondsSinceEpoch((((j['at'] as num?) ?? 0) * 1000).round()),
        sumber: (j['source'] ?? 'mic') as String,
        yt: j['yt'] is Map ? Track.fromJson(Map<String, dynamic>.from(j['yt'] as Map)) : null,
      );

  /// Buat diputar: pasangan YouTube-nya, dengan sampul dari Shazam kalau ada.
  Track? get track => yt;
}

/// Hasil cari dari potongan lirik.
class HasilLirik {
  HasilLirik(this.track, {this.skor = 0, this.baris});
  final Track track;
  final double skor;
  final String? baris;
}

class FinderGagal implements Exception {
  const FinderGagal(this.pesan);
  final String pesan;

  @override
  String toString() => pesan;
}

/// Kenali lagu (mirip Shazam) dan cari dari potongan lirik. Ikut
/// `mull/finder.py` versi Windows.
///
/// Sidik jari dibuat di HP ([ShazamSignature]); yang dikirim ke server
/// Shazam cuma sidik jari itu, bukan rekamannya.
class FinderService extends ChangeNotifier {
  FinderService._();
  static final instance = FinderService._();

  @visibleForTesting
  factory FinderService.baru({http.Client? client, Directory? folder}) {
    final s = FinderService._();
    s._client = client;
    s._folderTes = folder;
    return s;
  }

  /// Shazam nggak mau mencocokkan potongan 15 detik ke atas.
  static const segmen = 12;
  static const _maks = 200;
  static const _uas = [
    'Dalvik/2.1.0 (Linux; U; Android 13; SM-A546E Build/TP1A.220624.014)',
    'Dalvik/2.1.0 (Linux; U; Android 14; Infinix X6833B Build/UP1A.231005.007)',
    'Dalvik/2.1.0 (Linux; U; Android 11; Redmi Note 9 Pro Build/RKQ1.200826.002)',
  ];

  http.Client? _client;
  http.Client get _http => _client ??= http.Client();
  Directory? _folderTes;
  final _acak = Random();

  List<LaguDikenali> _riwayat = [];
  bool _sudahMuat = false;
  List<LaguDikenali> get riwayat => List.unmodifiable(_riwayat);

  // ---------------------------------------------------------------- Shazam

  /// PCM 16 kHz mono -> lagu, atau null kalau nggak ketemu.
  Future<LaguDikenali?> kenaliPcm(Uint8List pcm, {String sumber = 'mic'}) async {
    if (pcm.lengthInBytes < 16000 * 2) return null; // < 1 detik
    final sig = await compute(ShazamSignature.dariBytes, pcm);
    if (sig.jumlahPuncak < 5) return null;
    final resp = await _shazam(sig);
    return parse(resp, sumber: sumber);
  }

  Future<Map<String, dynamic>> _shazam(ShazamSignature sig) async {
    String uuid() {
      const h = '0123456789ABCDEF';
      final b = List.generate(32, (_) => h[_acak.nextInt(16)]).join();
      return '${b.substring(0, 8)}-${b.substring(8, 12)}-4${b.substring(13, 16)}-'
          '${h[8 + _acak.nextInt(4)]}${b.substring(17, 20)}-${b.substring(20)}';
    }

    final perangkat = const ['iphone', 'android', 'web'][_acak.nextInt(3)];
    final url = Uri.parse(
      'https://amp.shazam.com/discovery/v5/en-US/ID/$perangkat/-/tag/${uuid()}/${uuid()}'
      '?sync=true&webv3=true&sampling=true&connected=&shazamapiversion=v3&sharehub=true'
      '&hubv5minorversion=v5.1&hidelb=true&video=v3',
    );
    final body = jsonEncode({
      'timezone': 'Asia/Jakarta',
      'signature': {'uri': sig.uri, 'samplems': sig.sampleMs},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'context': {},
      'geolocation': {},
    });
    final http.Response r;
    try {
      r = await _http
          .post(url, body: body, headers: {
            'Content-Type': 'application/json',
            'Accept': '*/*',
            'Accept-Language': 'en-US',
            'User-Agent': _uas[_acak.nextInt(_uas.length)],
            'X-Shazam-Platform': 'IPHONE',
            'X-Shazam-AppVersion': '14.1.0',
          })
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const FinderGagal('Nggak bisa nyambung ke server pengenal lagu. Cek internet lalu coba lagi.');
    }
    if (r.statusCode == 429) throw const FinderGagal('Terlalu sering mencoba. Tunggu sebentar, lalu coba lagi.');
    if (r.statusCode != 200) {
      throw FinderGagal('Server pengenal lagu menolak permintaan (HTTP ${r.statusCode}). Coba lagi nanti.');
    }
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      return j is Map ? Map<String, dynamic>.from(j) : {};
    } catch (_) {
      throw const FinderGagal('Jawaban server pengenal lagu nggak kebaca. Coba lagi nanti.');
    }
  }

  static String? _sampulBesar(String? u) => u?.replaceFirstMapped(
        RegExp(r'/\d+x\d+(cc|bb)?\.(jpg|png|webp)$'),
        (m) => '/800x800${m[1] ?? ''}.${m[2]}',
      );

  /// Jawaban Shazam -> lagu. Null kalau nggak ada yang cocok.
  @visibleForTesting
  static LaguDikenali? parse(Map<String, dynamic> resp, {String sumber = 'mic'}) {
    final track = resp['track'];
    final matches = resp['matches'];
    if (track is! Map || matches is! List || matches.isEmpty) return null;
    final meta = <String, String>{};
    String? lirik;
    for (final sec in (track['sections'] as List?) ?? const []) {
      if (sec is! Map) continue;
      if (sec['type'] == 'SONG') {
        for (final m in (sec['metadata'] as List?) ?? const []) {
          if (m is Map && m['title'] is String && m['text'] is String) {
            meta[(m['title'] as String).toLowerCase()] = m['text'] as String;
          }
        }
      } else if (sec['type'] == 'LYRICS' && sec['text'] is List) {
        lirik = (sec['text'] as List).join('\n');
      }
    }
    final img = track['images'] is Map ? track['images'] as Map : const {};
    final genres = track['genres'];
    return LaguDikenali(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      key: '${track['key'] ?? ''}',
      judul: (track['title'] as String?) ?? 'Tanpa judul',
      artis: (track['subtitle'] as String?) ?? '',
      album: meta['album'],
      tahun: meta['released'],
      genre: genres is Map ? genres['primary'] as String? : null,
      sampul: _sampulBesar((img['coverarthq'] ?? img['coverart']) as String?),
      shazamUrl: track['url'] as String?,
      lirik: lirik,
      waktu: DateTime.now(),
      sumber: sumber,
    );
  }

  // ---------------------------------------------------------------- sumber

  /// Titik-titik yang dicoba (detik). Kalau pengguna nunjuk posisi (dari
  /// pemutar), itu duluan; kalau nggak, tengah dulu (biasanya reff).
  @visibleForTesting
  static List<double> titikMulai(double? durasi, {double? di}) {
    if (di != null) return [max(0, di - 2)];
    if (durasi == null || durasi <= segmen + 2) return [0];
    return [
      for (final f in const [0.4, 0.2, 0.65]) min(max(0.0, durasi * f - segmen / 2), durasi - segmen),
    ];
  }

  /// RMS 0..1 dari PCM, buat ngecek bukan cuma hening.
  static double kerasnya(Uint8List pcm) {
    final d = ByteData.sublistView(pcm);
    final n = pcm.lengthInBytes ~/ 2;
    if (n == 0) return 0;
    final langkah = max(1, n ~/ 40000);
    var jumlah = 0.0;
    var k = 0;
    for (var i = 0; i < n; i += langkah) {
      final v = d.getInt16(i * 2, Endian.little);
      jumlah += v * v.toDouble();
      k++;
    }
    return sqrt(jumlah / k) / 32768;
  }

  /// Naikkan volume rekaman pelan sampai RMS sekitar 0,1 (maks 16x, tanpa
  /// pecah). Rekaman mentah (UNPROCESSED) memang pelan karena tanpa penguat
  /// otomatis; sidik jari punya ambang energi minimal per puncak.
  @visibleForTesting
  static Uint8List kuatkan(Uint8List pcm) {
    final r = kerasnya(pcm);
    if (r <= 0 || r >= 0.1) return pcm;
    final d = ByteData.sublistView(pcm);
    final n = pcm.lengthInBytes ~/ 2;
    var puncak = 1;
    for (var i = 0; i < n; i++) {
      puncak = max(puncak, d.getInt16(i * 2, Endian.little).abs());
    }
    final g = min(min(0.1 / r, 16.0), 30000 / puncak);
    if (g <= 1.05) return pcm;
    final out = ByteData(n * 2);
    for (var i = 0; i < n; i++) {
      out.setInt16(i * 2, (d.getInt16(i * 2, Endian.little) * g).round().clamp(-32768, 32767), Endian.little);
    }
    return out.buffer.asUint8List();
  }

  /// Kenali dari berkas lokal (uri content://) atau URL stream.
  Future<LaguDikenali?> kenaliSumber(
    String source, {
    Map<String, String>? headers,
    Duration? durasi,
    Duration? di,
    String sumber = 'file',
    void Function(int ke, int dari)? progres,
  }) async {
    final titik = titikMulai(
      durasi == null ? null : durasi.inMilliseconds / 1000,
      di: di == null ? null : di.inMilliseconds / 1000,
    );
    var adaSuara = false;
    for (var i = 0; i < titik.length; i++) {
      progres?.call(i, titik.length);
      final ({Uint8List pcm, int? durasiMs}) r;
      try {
        r = await YtDlp.decodePcm(
          source,
          headers: headers,
          startMs: (titik[i] * 1000).round(),
          lengthMs: segmen * 1000,
        );
      } catch (e) {
        if (i == 0) throw FinderGagal('Suaranya nggak bisa dibaca: ${YtDlpService.pesanRamah(e)}');
        continue;
      }
      if (r.pcm.lengthInBytes < 16000 || kerasnya(r.pcm) < 0.003) continue;
      adaSuara = true;
      final hasil = await kenaliPcm(r.pcm, sumber: sumber);
      if (hasil != null) return hasil;
    }
    if (!adaSuara) throw const FinderGagal('Nggak ada suara yang bisa dibaca dari sini.');
    return null;
  }

  /// Kenali dari tautan (YouTube, TikTok, Reels, dll), atau lagu stream yang
  /// lagi diputar ([di] = posisi yang ditunjuk). Balikin juga judul sumbernya.
  ///
  /// Audionya diunduh dulu ke folder sementara (cuma audio, biasanya beberapa
  /// MB), baru potongannya dibaca. Dites 12 Nov di Infinix: membaca URL
  /// stream YouTube langsung lewat MediaExtractor ditolak servernya
  /// (MediaHTTPConnection IOException, "Failed to instantiate extractor"),
  /// padahal URL yang sama jalan di pemutar.
  Future<(LaguDikenali?, String)> kenaliTautan(
    String url, {
    Duration? di,
    void Function(String langkah)? langkah,
  }) async {
    await YtDlpService.instance.ensureReady();
    langkah?.call('Mengambil audio dari tautan...');
    final id = 'kenali-${DateTime.now().millisecondsSinceEpoch}';
    Map<String, dynamic>? hasilUnduh;
    Object? galat;
    // Jalur cepat (klien YouTube tanpa JavaScript) dulu, baru jalur biasa.
    for (final cepat in [true, false]) {
      try {
        final r = await YtDlp.download(id, url, args: [
          '-f',
          'ba[ext=m4a]/ba/wa/w/b',
          '--max-filesize',
          '60M',
          '--write-info-json',
          '--no-write-playlist-metafiles',
          '--no-warnings',
          if (cepat) ...['--extractor-args', 'youtube:player_client=android_vr,web_safari'],
        ]);
        final files = (r['files'] as List?) ?? const [];
        if (r['exitCode'] == 0 && files.any((f) => !'${(f as Map)['name']}'.endsWith('.json'))) {
          hasilUnduh = r;
          break;
        }
        galat = r['err'];
      } catch (e) {
        galat = e;
      }
    }
    if (hasilUnduh == null) {
      final pesan = '$galat'.toLowerCase();
      if (pesan.contains('playlist')) {
        throw const FinderGagal('Ini tautan playlist atau profil. Tempel tautan satu video saja.');
      }
      if (pesan.contains('max-filesize') || pesan.contains('larger than')) {
        throw const FinderGagal('Audionya terlalu besar. Pakai tautan yang lebih pendek.');
      }
      throw FinderGagal(YtDlpService.pesanRamah(galat ?? 'Gagal mengambil audio'));
    }

    final files = [for (final f in hasilUnduh['files'] as List) Map<String, dynamic>.from(f as Map)];
    final folder = File(files.first['path'] as String).parent;
    try {
      String judul = url;
      double? durasi;
      for (final f in files) {
        if (!'${f['name']}'.endsWith('.info.json')) continue;
        try {
          final info = jsonDecode(await File(f['path'] as String).readAsString()) as Map;
          judul = (info['title'] as String?) ?? url;
          durasi = (info['duration'] as num?)?.toDouble();
        } catch (_) {}
      }
      final audio = files.firstWhere((f) => !'${f['name']}'.endsWith('.json'));
      langkah?.call('Mendengarkan "$judul"...');
      final hasil = await kenaliSumber(
        audio['path'] as String,
        durasi: durasi == null ? null : Duration(milliseconds: (durasi * 1000).round()),
        di: di,
        sumber: 'link',
      );
      return (hasil, judul);
    } finally {
      folder.delete(recursive: true).ignore();
    }
  }

  // ---------------------------------------------------------------- mikrofon

  /// Dengarkan lewat mikrofon, coba cocokkan di detik 4, 8, dan 12.
  /// [onLevel] dipanggil tiap 0,1 detik (0..1). Selesai dengan lagu, null
  /// (nggak ketemu), atau [FinderGagal]. Hentikan lewat [batal].
  Future<LaguDikenali?> dengarkan({
    required void Function(double level, double detik, bool mencocokkan) onLevel,
    required bool Function() batal,
  }) async {
    if (!await YtDlp.ensureMicPermission()) {
      throw const FinderGagal(
        'Izin mikrofon belum dikasih. Bisa diatur lewat Pengaturan HP > Aplikasi > Mull Music > Izin.',
      );
    }
    try {
      await YtDlp.micStart();
    } catch (e) {
      throw FinderGagal(YtDlpService.pesanRamah(e));
    }
    final cek = [4.0, 8.0, segmen.toDouble()];
    var terdengar = false;
    try {
      while (!batal()) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final s = await YtDlp.micStatus();
        terdengar = terdengar || s.level > 0.004;
        onLevel(min(1, s.level * 6), s.detik, false);
        if (cek.isEmpty || s.detik < cek.first) continue;
        final akhir = cek.length == 1;
        cek.removeAt(0);
        final pcm = await YtDlp.micSnapshot(segmen.toDouble());
        if (kerasnya(pcm) < 0.003) {
          if (akhir) {
            throw FinderGagal(terdengar
                ? 'Suaranya terlalu pelan. Dekatkan HP ke sumber suara.'
                : 'Mikrofon nggak nangkep suara apa pun.');
          }
          continue;
        }
        onLevel(min(1, s.level * 6), s.detik, true);
        final hasil = await kenaliPcm(kuatkan(pcm), sumber: 'mic');
        if (hasil != null || akhir) return hasil;
      }
      return null;
    } finally {
      await YtDlp.micStop().catchError((_) {});
    }
  }

  // ---------------------------------------------------------------- YouTube

  /// Cari pasangan YouTube buat diputar/diunduh, lalu simpan ke riwayat.
  Future<Track?> pasangkan(LaguDikenali l) async {
    if (l.yt != null) return l.yt;
    try {
      final (t, _) = await Pencocok.cari(l.judul, l.artis, minimal: 0.45);
      if (t != null) {
        l.yt = t;
        notifyListeners();
        await _simpan();
      }
      return t;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- lirik

  /// Cari baris lirik yang paling mirip potongan yang diketik.
  /// (skor 0..1, baris) atau null.
  @visibleForTesting
  static (double, String)? cocokBaris(String potongan, String? polos) {
    final q = Pencocok.norm(potongan).split(' ').where((w) => w.isNotEmpty).toList();
    if (q.length < 2 || polos == null || polos.trim().isEmpty) return null;
    final baris = polos.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final normal = baris.map(Pencocok.norm).toList();
    final kalimat = q.join(' ');
    (double, String)? terbaik;
    for (final rentang in const [1, 2]) {
      for (var i = 0; i + rentang <= baris.length; i++) {
        final jendela = normal.sublist(i, i + rentang).join(' ');
        final teks = baris.sublist(i, i + rentang).join(' / ');
        if (jendela.contains(kalimat)) return (1.0, teks);
        final kata = jendela.split(' ').toSet();
        var s = q.where(kata.contains).length / q.length;
        if (rentang == 2) s -= 0.05;
        if (terbaik == null || s > terbaik.$1) terbaik = (s, teks);
      }
    }
    return terbaik != null && terbaik.$1 >= 0.6 ? terbaik : null;
  }

  /// Cari lagu dari potongan lirik: pencarian YouTube, lalu lirik tiap
  /// hasil dicek di LRCLIB. Yang liriknya memuat potongan itu naik ke atas.
  Future<List<HasilLirik>> cariLirik(String teks) async {
    final q = teks.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (Pencocok.norm(q).split(' ').where((w) => w.isNotEmpty).length < 2) {
      throw const FinderGagal('Ketik minimal dua kata dari liriknya.');
    }
    final List<Track> hasil;
    try {
      hasil = await YtDlpService.instance.search('$q lirik', limit: 10);
    } catch (e) {
      throw FinderGagal(YtDlpService.pesanRamah(e));
    }
    final dicek = await Future.wait(hasil.take(8).map((t) async {
      try {
        final l = await LyricsService.instance
            .untuk(t, simpan: false)
            .timeout(const Duration(seconds: 10));
        final c = cocokBaris(q, l?.polos);
        return HasilLirik(t, skor: c?.$1 ?? 0, baris: c?.$2);
      } catch (_) {
        return HasilLirik(t);
      }
    }));
    final sisa = hasil.skip(8).map(HasilLirik.new);
    final semua = [...dicek, ...sisa];
    final urutan = {for (var i = 0; i < semua.length; i++) semua[i]: i};
    semua.sort((a, b) {
      final s = b.skor.compareTo(a.skor);
      return s != 0 ? s : urutan[a]!.compareTo(urutan[b]!);
    });
    return semua;
  }

  // ---------------------------------------------------------------- riwayat

  Future<File> _berkas() async {
    final dasar = _folderTes ?? await getApplicationSupportDirectory();
    if (!await dasar.exists()) await dasar.create(recursive: true);
    return File('${dasar.path}/finds.json');
  }

  Future<void> muat() async {
    if (_sudahMuat) return;
    try {
      final f = await _berkas();
      if (await f.exists()) {
        final isi = jsonDecode(await f.readAsString());
        _riwayat = (isi is List ? isi : const [])
            .whereType<Map>()
            .map((e) => LaguDikenali.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {
      _riwayat = [];
    }
    _sudahMuat = true;
    notifyListeners();
  }

  Future<void> _simpan() async {
    try {
      final f = await _berkas();
      await f.writeAsString(jsonEncode(_riwayat.map((e) => e.toJson()).toList()));
    } catch (_) {
      // Gagal nulis: riwayat di memori tetap benar sampai app ditutup.
    }
  }

  /// Masukkan ke riwayat. Lagu yang sama dikenali lagi naik ke atas.
  Future<void> catat(LaguDikenali l) async {
    if (!_sudahMuat) await muat();
    _riwayat = [
      l,
      ..._riwayat.where((x) => !(l.key.isNotEmpty && x.key == l.key) && x.id != l.id),
    ];
    if (_riwayat.length > _maks) _riwayat = _riwayat.sublist(0, _maks);
    notifyListeners();
    await _simpan();
  }

  /// Ganti riwayat dengan hasil sinkron akun.
  Future<void> gantiSemua(List<LaguDikenali> baru) async {
    _riwayat = baru.take(_maks).toList();
    _sudahMuat = true;
    notifyListeners();
    await _simpan();
  }

  Future<void> hapus(LaguDikenali l) async {
    _riwayat = _riwayat.where((x) => x.id != l.id).toList();
    notifyListeners();
    await _simpan();
  }

  Future<void> bersihkan() async {
    _riwayat = [];
    notifyListeners();
    await _simpan();
  }
}
