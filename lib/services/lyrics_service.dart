import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';

/// Satu baris lirik bertanda waktu.
class BarisLirik {
  const BarisLirik(this.waktu, this.teks);

  final Duration waktu;
  final String teks;
}

/// Hasil pencarian lirik.
class Lirik {
  const Lirik({required this.tersinkron, required this.polos, required this.sumber});

  /// Kosong kalau yang ketemu cuma lirik tanpa penanda waktu.
  final List<BarisLirik> tersinkron;
  final String polos;
  final String sumber;

  bool get adaWaktu => tersinkron.isNotEmpty;
  bool get kosong => tersinkron.isEmpty && polos.trim().isEmpty;
}

/// Ambil lirik dari LRCLIB (lrclib.net), sama dengan versi Windows.
///
/// Hasilnya disimpan sebagai `.lrc` di folder app. Versi Windows menaruh
/// `.lrc` di sebelah berkas lagunya, tapi di Android berkasnya ada di
/// MediaStore dan kita nggak bisa bikin berkas tetangga di situ.
class LyricsService {
  LyricsService._();
  static final instance = LyricsService._();

  /// Instance bersih buat tes, boleh pakai client palsu.
  @visibleForTesting
  factory LyricsService.baru({http.Client? client}) {
    final s = LyricsService._();
    s._client = client;
    return s;
  }

  static const _dasar = 'https://lrclib.net/api';
  static const _ua = 'Mull Music App Android (github.com/BlackKepret28)';

  http.Client? _client;
  http.Client get _http => _client ??= http.Client();

  final _memori = <String, Lirik?>{};

  /// Null berarti memang nggak ketemu liriknya.
  Future<Lirik?> untuk(Track t) async {
    if (_memori.containsKey(t.id)) return _memori[t.id];

    final dariDisk = await _bacaDisk(t.id);
    if (dariDisk != null) {
      _memori[t.id] = dariDisk;
      return dariDisk;
    }

    final (judul, artis) = bersihkanJudul(t.title, t.artist ?? '');
    final detik = t.duration?.inSeconds ?? 0;

    // Urutan sama dengan versi Windows: paling tepat dulu, baru melebar.
    final percobaan = <(String, Map<String, String>)>[
      if (artis.isNotEmpty)
        ('get', {
          'track_name': judul,
          'artist_name': artis,
          if (detik > 0) 'duration': '$detik',
        }),
      if (artis.isNotEmpty) ('search', {'track_name': judul, 'artist_name': artis}),
      ('search', {'q': '$artis $judul'.trim()}),
    ];

    for (final (ep, params) in percobaan) {
      final hasil = await _coba(ep, params, detik);
      if (hasil != null) {
        _memori[t.id] = hasil;
        await _tulisDisk(t.id, hasil);
        return hasil;
      }
    }

    _memori[t.id] = null;
    return null;
  }

  Future<Lirik?> _coba(String ep, Map<String, String> params, int detik) async {
    try {
      final uri = Uri.parse('$_dasar/$ep').replace(queryParameters: params);
      final r = await _http
          .get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;

      final body = jsonDecode(utf8.decode(r.bodyBytes));

      if (ep == 'get') return _dariObjek(body is Map ? body : null);

      if (body is! List) return null;

      // Pilih yang durasinya paling dekat, dan utamakan yang bertanda waktu.
      ({int beda, bool tanpaWaktu, Lirik lirik})? terbaik;
      for (final o in body) {
        if (o is! Map) continue;
        final l = _dariObjek(o);
        if (l == null) continue;
        final d = (o['duration'] as num?)?.round() ?? 0;
        final beda = detik > 0 ? (d - detik).abs() : 0;
        if (detik > 0 && beda > 6) continue;
        final calon = (beda: beda, tanpaWaktu: !l.adaWaktu, lirik: l);
        if (terbaik == null ||
            (calon.tanpaWaktu ? 1 : 0) < (terbaik.tanpaWaktu ? 1 : 0) ||
            ((calon.tanpaWaktu == terbaik.tanpaWaktu) && calon.beda < terbaik.beda)) {
          terbaik = calon;
        }
      }
      return terbaik?.lirik;
    } catch (_) {
      // Lirik itu bonus, bukan fitur utama. Gagal ya sudah.
      return null;
    }
  }

  static Lirik? _dariObjek(Map? o) {
    if (o == null) return null;
    if (o['instrumental'] == true) return null;

    final tersinkron = parseLrc(o['syncedLyrics'] as String?);
    final polos = (o['plainLyrics'] as String?)?.trim().isNotEmpty == true
        ? o['plainLyrics'] as String
        : tersinkron.map((b) => b.teks).join('\n');

    if (tersinkron.isEmpty && polos.trim().isEmpty) return null;
    return Lirik(tersinkron: tersinkron, polos: polos, sumber: 'LRCLIB');
  }

  // ---- Pembersih judul -------------------------------------------------

  static final _polaFeat = RegExp(r'\s*[(\[]\s*(?:feat|ft)\.?[^)\]]*[)\]]', caseSensitive: false);
  static final _polaEmbel = RegExp(
    r'\s*[(\[][^)\]]*(?:official|video|audio|lyrics?|hd|hq|mv|m/v|no copyright|'
    r'music video|visualizer|remaster\w*)[^)\]]*[)\]]',
    caseSensitive: false,
  );

  /// Ubah judul YouTube jadi (judul, artis) yang masuk akal buat LRCLIB.
  /// Contoh: "Carefree - Kevin MacLeod (No Copyright Music)" -> ("Carefree", "Kevin MacLeod").
  @visibleForTesting
  static (String, String) bersihkanJudul(String judulAwal, String artisAwal) {
    var judul = judulAwal.replaceAll(_polaEmbel, '').trim();
    var artis = artisAwal.trim();

    // Kanal YouTube sering bernama "X - Topic".
    if (artis.endsWith(' - Topic')) {
      artis = artis.substring(0, artis.length - ' - Topic'.length).trim();
    }

    for (final pemisah in [' - ', ' – ', ' — ']) {
      final i = judul.indexOf(pemisah);
      if (i <= 0) continue;
      final kiri = judul.substring(0, i).trim();
      final kanan = judul.substring(i + pemisah.length).trim();
      if (kiri.isEmpty || kanan.isEmpty) continue;
      // Kalau kiri memang nama artisnya, berarti polanya "Artis - Judul".
      final cocok = artis.isEmpty ||
          artis.toLowerCase().contains(kiri.toLowerCase()) ||
          kiri.toLowerCase().contains(artis.toLowerCase());
      if (cocok) {
        if (artis.isEmpty) artis = kiri;
        judul = kanan;
      }
      break;
    }

    judul = judul.replaceAll(_polaFeat, '').trim();
    return (judul, artis);
  }

  // ---- LRC -------------------------------------------------------------

  static final _polaStempel = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]');

  /// Ubah teks LRC jadi daftar baris bertanda waktu, terurut.
  @visibleForTesting
  static List<BarisLirik> parseLrc(String? lrc) {
    if (lrc == null || lrc.trim().isEmpty) return const [];

    final hasil = <BarisLirik>[];
    for (final baris in lrc.split('\n')) {
      final stempel = _polaStempel.allMatches(baris).toList();
      if (stempel.isEmpty) continue;

      final teks = baris.substring(stempel.last.end).trim();
      for (final m in stempel) {
        final menit = int.parse(m.group(1)!);
        final detik = int.parse(m.group(2)!);
        final pecahan = m.group(3);
        // ".5" berarti 500 ms, ".50" juga, ".500" juga.
        final ms = pecahan == null
            ? 0
            : (double.parse('0.$pecahan') * 1000).round();
        hasil.add(BarisLirik(
          Duration(minutes: menit, seconds: detik, milliseconds: ms),
          teks,
        ));
      }
    }

    hasil.sort((a, b) => a.waktu.compareTo(b.waktu));
    return hasil;
  }

  /// Susun ulang jadi teks LRC, buat disimpan.
  static String keLrc(Lirik l) {
    if (!l.adaWaktu) return l.polos;
    final b = StringBuffer();
    for (final baris in l.tersinkron) {
      final m = baris.waktu.inMinutes.toString().padLeft(2, '0');
      final d = baris.waktu.inSeconds.remainder(60).toString().padLeft(2, '0');
      final cs = (baris.waktu.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
      b.writeln('[$m:$d.$cs]${baris.teks}');
    }
    return b.toString();
  }

  // ---- Simpanan di disk ------------------------------------------------

  Future<Directory> _folder() async {
    final dasar = await getApplicationSupportDirectory();
    final d = Directory('${dasar.path}/lirik');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<Lirik?> _bacaDisk(String id) async {
    try {
      final f = File('${(await _folder()).path}/$id.lrc');
      if (!await f.exists()) return null;
      final isi = await f.readAsString();
      final tersinkron = parseLrc(isi);
      if (tersinkron.isEmpty && isi.trim().isEmpty) return null;
      return Lirik(
        tersinkron: tersinkron,
        polos: tersinkron.isEmpty ? isi : tersinkron.map((b) => b.teks).join('\n'),
        sumber: 'Tersimpan',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _tulisDisk(String id, Lirik l) async {
    try {
      final f = File('${(await _folder()).path}/$id.lrc');
      await f.writeAsString(keLrc(l));
    } catch (_) {
      // Nggak bisa nyimpan bukan alasan buat gagal nampilin lirik.
    }
  }
}
