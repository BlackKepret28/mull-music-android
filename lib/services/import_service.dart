import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/track.dart';
import '../ytdlp.dart';
import 'pencocok.dart';
import 'playlist_service.dart';
import 'ytdlp_service.dart';

/// Impor playlist dari tautan, ikut `mull/importer.py` versi Windows.
///
/// Sumber:
/// - Playlist YouTube Music / YouTube (`list=...`): dibaca yt-dlp
///   `--flat-playlist`. Lagunya langsung punya id video.
/// - Playlist/album Spotify: halaman embed publik (maks 100 lagu pertama).
/// - Daftar tautan lagu Spotify (satu per baris), buat playlist > 100 lagu.
/// - Teks "Judul - Artis" per baris.
/// - Kode bagikan Mull (`mull-playlist:1:...`), formatnya sama dengan
///   versi Windows, jadi kode dari laptop bisa ditempel di HP dan sebaliknya.
///
/// Lagu Spotify dan teks dicarikan pasangannya di YouTube ([Pencocok]).
class ImportService {
  ImportService._();

  static const okSkor = 0.72; // di bawah ini ditandai "ragu"
  static const embedLimit = 100;
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';

  static final _spUrl = RegExp(
    r'open\.spotify\.com/(?:intl-[a-z]{2}(?:-[a-z]{2})?/)?(?:embed/)?(playlist|album|track)/([A-Za-z0-9]{22})',
  );
  static final _spUri = RegExp(r'spotify:(playlist|album|track):([A-Za-z0-9]{22})');
  static final _list = RegExp(r'[?&]list=([\w-]+)');
  static final kodeRe = RegExp(r'mull-playlist:1:([A-Za-z0-9_-]+)');
  static const kodeAwalan = 'mull-playlist:1:';
  static final _vid = RegExp(r'^[\w-]{6,20}$');

  /// Teks tempelan ini kelihatan kayak playlist (bukan satu lagu)? Dipakai
  /// buat ngarahin tempelan di Beranda ke layar Impor, bukan ke Cari.
  static bool tampakPlaylist(String teks) {
    final t = teks.trim();
    if (kodeRe.hasMatch(t)) return true;
    for (final m in [..._spUrl.allMatches(t), ..._spUri.allMatches(t)]) {
      if (m[1] != 'track') return true;
    }
    if (_spUrl.allMatches(t).length + _spUri.allMatches(t).length > 1) return true;
    if (RegExp(r'(youtube\.com|youtu\.be)').hasMatch(t) && _list.hasMatch(t)) {
      // watch?v=...&list=RD... itu radio otomatis, bukan playlist sungguhan.
      final id = _list.firstMatch(t)![1]!;
      return !id.startsWith('RD') || t.contains('/playlist');
    }
    return false;
  }

  /// Teks tempelan -> jenis sumber. Lempar [ImporGagal] kalau nggak kebaca.
  @visibleForTesting
  static SumberImpor kenali(String teks) {
    final t = teks.trim();
    if (t.isEmpty) throw const ImporGagal('Tempel tautan playlist dulu.');
    if (kodeRe.hasMatch(t)) return SumberImpor(JenisImpor.mull, teks: t);

    final sp = [
      for (final m in _spUrl.allMatches(t)) (m[1]!, m[2]!),
      for (final m in _spUri.allMatches(t)) (m[1]!, m[2]!),
    ];
    final lagu = <String>[];
    for (final (k, id) in sp) {
      if (k == 'track' && !lagu.contains(id)) lagu.add(id);
    }
    final daftar = sp.where((e) => e.$1 != 'track').toList();
    if (daftar.isNotEmpty && lagu.isEmpty) {
      return SumberImpor(JenisImpor.spotify, tipe: daftar.first.$1, id: daftar.first.$2);
    }
    if (lagu.isNotEmpty) return SumberImpor(JenisImpor.spotifyLagu, idLagu: lagu);

    final m = _list.firstMatch(t);
    if (m != null && RegExp(r'(youtube\.com|youtu\.be)').hasMatch(t)) {
      return SumberImpor(
        t.contains('music.youtube.com') ? JenisImpor.ytm : JenisImpor.yt,
        id: m[1],
        url: RegExp(r'https?://\S+').firstMatch(t)?[0],
      );
    }
    if (RegExp(r'^https?://').hasMatch(t) && !t.contains('\n')) {
      throw const ImporGagal(
        'Tautan ini belum didukung. Pakai tautan playlist YouTube Music, YouTube, atau Spotify.',
      );
    }
    final baris = t
        .split('\n')
        .map((l) => l.trim().replaceAll(RegExp(r'^[-•*\s]+|[-•*\s]+$'), ''))
        .where((l) => l.isNotEmpty && !l.startsWith('http'))
        .take(1000)
        .toList();
    if (baris.isEmpty) throw const ImporGagal('Nggak ada lagu yang kebaca dari teks ini.');
    return SumberImpor(JenisImpor.teks, baris: baris);
  }

  // ---------------------------------------------------------------- utama

  static http.Client? klienTes;
  static http.Client? _klien;
  static http.Client get _http => klienTes ?? (_klien ??= http.Client());

  /// Baca isi playlist (belum dicocokkan).
  static Future<PratinjauImpor> pratinjau(String teks, {void Function(int, int)? progres}) async {
    final s = kenali(teks);
    switch (s.jenis) {
      case JenisImpor.mull:
        return bacaKode(s.teks!);
      case JenisImpor.spotify:
        final html = await _ambil('https://open.spotify.com/embed/${s.tipe}/${s.id}');
        return bacaEmbedSpotify(html, s.tipe!, s.id!);
      case JenisImpor.spotifyLagu:
        if (s.idLagu!.length > 1000) throw const ImporGagal('Maksimal 1.000 lagu sekali impor.');
        return _laguSpotify(s.idLagu!, progres);
      case JenisImpor.ytm:
      case JenisImpor.yt:
        return _playlistYouTube(s);
      case JenisImpor.teks:
        return dariTeks(s.baris!);
    }
  }

  static Future<String> _ambil(String url) async {
    final http.Response r;
    try {
      r = await _http
          .get(Uri.parse(url), headers: {'User-Agent': _ua, 'Accept-Language': 'en-US,en;q=0.8'})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ImporGagal('Nggak bisa nyambung. Cek internet lalu coba lagi.');
    }
    if (r.statusCode == 404) {
      throw const ImporGagal('Playlist-nya nggak ketemu. Mungkin privat atau sudah dihapus.');
    }
    if (r.statusCode != 200) throw ImporGagal('Spotify menolak permintaan (HTTP ${r.statusCode}). Coba lagi nanti.');
    return utf8.decode(r.bodyBytes, allowMalformed: true);
  }

  // ---------------------------------------------------------------- Spotify

  static Iterable<Object?> _jsonDiHalaman(String html) sync* {
    for (final m in RegExp(r'<script[^>]*>(.*?)</script>', dotAll: true).allMatches(html)) {
      var isi = m[1]!.trim();
      if (isi.isEmpty) continue;
      if (isi.startsWith('%7B') || isi.startsWith('%7b')) isi = Uri.decodeComponent(isi);
      if (isi[0] != '{' && isi[0] != '[') continue;
      try {
        yield jsonDecode(isi);
      } catch (_) {
        continue;
      }
    }
  }

  static Map? _cari(Object? o, bool Function(Map) cocok, [int dalam = 0]) {
    if (dalam > 14) return null;
    if (o is Map) {
      if (cocok(o)) return o;
      for (final v in o.values) {
        final r = _cari(v, cocok, dalam + 1);
        if (r != null) return r;
      }
    } else if (o is List) {
      for (final v in o) {
        final r = _cari(v, cocok, dalam + 1);
        if (r != null) return r;
      }
    }
    return null;
  }

  static String _artis(Map t) {
    final sub = t['subtitle'];
    if (sub is String && sub.isNotEmpty) return _unescape(sub).replaceAll(' ', ' ');
    final nama = <String>[];
    for (final a in (t['artists'] as List?) ?? const []) {
      if (a is! Map) continue;
      final n = a['name'] ?? (a['profile'] is Map ? a['profile']['name'] : null);
      if (n is String && n.isNotEmpty) nama.add(n);
    }
    return nama.join(', ');
  }

  static int? _detik(Object? v) {
    if (v is! num) return null;
    return v > 3600 ? (v / 1000).round() : v.round();
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  @visibleForTesting
  static PratinjauImpor bacaEmbedSpotify(String html, String tipe, String id) {
    Map? ent;
    for (final blob in _jsonDiHalaman(html)) {
      ent = _cari(blob, (d) => d['trackList'] is List);
      if (ent != null) break;
    }
    if (ent == null) {
      throw const ImporGagal(
        'Isi playlist Spotify nggak kebaca. Mungkin playlist-nya privat, atau Spotify mengubah halamannya. '
        'Coba tempel daftar tautan lagunya.',
      );
    }
    final lagu = <LaguImpor>[];
    for (final t in ent['trackList'] as List) {
      if (t is! Map) continue;
      final uri = (t['uri'] as String?) ?? '';
      if (!uri.startsWith('spotify:track:')) continue; // episode podcast dsb.
      lagu.add(LaguImpor(
        judul: _unescape((t['title'] ?? t['name'] ?? '') as String),
        artis: _artis(t),
        detik: _detik(t['duration']),
      ));
    }
    final nama = (ent['name'] ?? ent['title'] ?? 'Playlist Spotify') as String;
    final pemilik = ent['subtitle'];
    return PratinjauImpor(
      nama: _unescape(nama),
      pemilik: pemilik is String ? _unescape(pemilik) : null,
      url: 'https://open.spotify.com/$tipe/$id',
      lagu: lagu,
      terbatas: lagu.length >= embedLimit,
      perluCocok: true,
    );
  }

  static Future<PratinjauImpor> _laguSpotify(List<String> ids, void Function(int, int)? progres) async {
    final hasil = List<LaguImpor?>.filled(ids.length, null);
    var selesai = 0;
    var berikut = 0;
    Future<void> pekerja() async {
      while (berikut < ids.length) {
        final i = berikut++;
        try {
          final html = await _ambil('https://open.spotify.com/embed/track/${ids[i]}');
          for (final blob in _jsonDiHalaman(html)) {
            final e = _cari(
              blob,
              (d) => d['uri'] == 'spotify:track:${ids[i]}' && (d['name'] ?? d['title']) != null,
            );
            if (e != null) {
              hasil[i] = LaguImpor(
                judul: _unescape((e['name'] ?? e['title']) as String),
                artis: _artis(e),
                detik: _detik(e['duration']),
              );
              break;
            }
          }
        } catch (_) {
          // Lagu ini dilewati, ditandai nggak ketemu.
        }
        selesai++;
        progres?.call(selesai, ids.length);
      }
    }

    await Future.wait(List.generate(4, (_) => pekerja()));
    return PratinjauImpor(
      nama: 'Lagu dari Spotify',
      lagu: [
        for (var i = 0; i < ids.length; i++)
          hasil[i] ?? LaguImpor(judul: 'Lagu Spotify ${ids[i]}', artis: '', tidakDikenal: true),
      ],
      perluCocok: true,
    );
  }

  // ---------------------------------------------------------------- YouTube

  static Future<PratinjauImpor> _playlistYouTube(SumberImpor s) async {
    await YtDlpService.instance.ensureReady();
    final musik = s.jenis == JenisImpor.ytm;
    final Map<String, dynamic> info;
    try {
      final r = await YtDlp.getInfo(
        'https://www.youtube.com/playlist?list=${s.id}',
        args: const ['--flat-playlist', '--no-warnings'],
      );
      info = r.info;
    } catch (e) {
      throw ImporGagal(YtDlpService.pesanRamah(e));
    }
    final lagu = <LaguImpor>[];
    for (final e in (info['entries'] as List?) ?? const []) {
      if (e is! Map || e['id'] is! String) continue;
      var t = Track.fromYtDlp(Map<String, dynamic>.from(e));
      final artis = t.artist?.replaceFirst(RegExp(r' - Topic$'), '');
      t = t.copyWith(
        artist: artis,
        thumbUrl: t.thumbUrl ?? 'https://i.ytimg.com/vi/${t.id}/hqdefault.jpg',
        webpageUrl: musik
            ? 'https://music.youtube.com/watch?v=${t.id}'
            : 'https://www.youtube.com/watch?v=${t.id}',
      );
      lagu.add(LaguImpor(judul: t.title, artis: artis ?? '', detik: t.duration?.inSeconds, yt: t, status: StatusCocok.ok));
    }
    if (lagu.isEmpty) throw const ImporGagal('Playlist-nya kosong atau privat.');
    final uploader = info['uploader'] ?? info['channel'];
    return PratinjauImpor(
      nama: (info['title'] as String?) ?? 'Playlist',
      pemilik: uploader is String ? uploader : null,
      url: s.url,
      lagu: lagu,
      perluCocok: false,
    );
  }

  // ---------------------------------------------------------------- teks

  @visibleForTesting
  static PratinjauImpor dariTeks(List<String> baris) {
    final lagu = <LaguImpor>[];
    for (final b in baris) {
      var judul = b;
      var artis = '';
      for (final pisah in const [' - ', ' – ', ' — ', '\t', ';']) {
        final i = b.indexOf(pisah);
        if (i > 0) {
          judul = b.substring(0, i).trim();
          artis = b.substring(i + pisah.length).trim();
          break;
        }
      }
      lagu.add(LaguImpor(judul: judul, artis: artis, dariTeks: true));
    }
    return PratinjauImpor(nama: 'Playlist impor', lagu: lagu, perluCocok: true);
  }

  // ---------------------------------------------------------------- cocokkan

  /// Cari pasangan YouTube buat lagu yang belum punya. [onUbah] dipanggil
  /// tiap satu lagu selesai. Berhenti kalau [batal] jadi true.
  static Future<void> cocokkan(
    PratinjauImpor p, {
    required VoidCallback onUbah,
    required bool Function() batal,
  }) async {
    final antre = [
      for (final l in p.lagu)
        if (l.status == StatusCocok.menunggu) l,
    ];
    var i = 0;
    Future<void> pekerja() async {
      while (i < antre.length && !batal()) {
        final l = antre[i++];
        await cocokkanSatu(l);
        if (!batal()) onUbah();
      }
    }

    await Future.wait(List.generate(3, (_) => pekerja()));
  }

  static Future<void> cocokkanSatu(LaguImpor l) async {
    if (l.tidakDikenal || l.judul.isEmpty) {
      l.status = StatusCocok.nggakAda;
      return;
    }
    try {
      var (t, s) = await Pencocok.cari(l.judul, l.artis, detik: l.detik, minimal: 0.35);
      if (t == null && l.dariTeks && l.artis.isNotEmpty) {
        // Teks bebas: mungkin urutannya "Artis - Judul".
        (t, s) = await Pencocok.cari(l.artis, l.judul, minimal: 0.35);
      }
      l.skor = s;
      l.yt = t;
      l.status = t == null ? StatusCocok.nggakAda : (s >= okSkor ? StatusCocok.ok : StatusCocok.ragu);
    } catch (_) {
      l.status = StatusCocok.nggakAda;
    }
  }

  /// Simpan hasil ke playlist (baru atau yang sudah ada). Balikin jumlah
  /// lagu yang masuk.
  static Future<(Playlist, int)> simpan(PratinjauImpor p, {Playlist? ke, String? namaBaru}) async {
    final service = PlaylistService.instance;
    if (!service.sudahMuat) await service.muat();
    final tujuan = ke ?? await service.buat(namaBaru ?? p.nama);
    final lagu = [
      for (final l in p.lagu)
        if (l.yt != null && l.dipakai) l.yt!,
    ];
    final n = await service.tambahLagu(tujuan, lagu);
    return (tujuan, n);
  }

  // ---------------------------------------------------------------- bagikan

  /// Kode bagikan, sama formatnya dengan `playlists.share` versi Windows:
  /// `mull-playlist:1:` + base64url(zlib(JSON)).
  static ({String kode, String teks, int jumlah, int dilewati}) bagikan(Playlist p) {
    final entri = <Map<String, Object>>[];
    final baris = <String>[];
    var dilewati = 0;
    for (final t in p.lagu) {
      final id = _vid.hasMatch(t.id) && !t.id.startsWith('content') ? t.id : null;
      final url = (t.webpageUrl?.startsWith('http') ?? false) ? t.webpageUrl : null;
      if (id == null && url == null) {
        dilewati++;
        continue;
      }
      entri.add({
        't': t.title.length > 300 ? t.title.substring(0, 300) : t.title,
        if (id != null) 'v': id else 'u': url!,
        if (t.artist != null && t.artist!.isNotEmpty) 'a': t.artist!,
        if (t.duration != null) 'd': t.duration!.inSeconds,
        if (t.isVideo) 'm': 'v',
      });
      final tautan = url ?? 'https://music.youtube.com/watch?v=$id';
      baris.add('${[t.title, if (t.artist != null) t.artist].join(' - ')}\n$tautan');
    }
    final mentah = utf8.encode(jsonEncode({'n': p.nama, 'i': entri}));
    final kode = kodeAwalan +
        base64Url.encode(ZLibCodec(level: 9).encode(mentah)).replaceAll('=', '');
    final teks = '${p.nama} (${entri.length} lagu)\n\n${baris.join('\n\n')}';
    return (kode: kode, teks: teks, jumlah: entri.length, dilewati: dilewati);
  }

  /// Kode bagikan (boleh di tengah teks lain) -> pratinjau.
  @visibleForTesting
  static PratinjauImpor bacaKode(String teks) {
    final m = kodeRe.firstMatch(teks);
    if (m == null) throw const ImporGagal('Kode playlist-nya nggak ketemu.');
    final Map data;
    try {
      final b = m[1]!;
      final pad = '=' * ((4 - b.length % 4) % 4);
      final mentah = ZLibCodec().decode(base64Url.decode(b + pad));
      data = jsonDecode(utf8.decode(mentah)) as Map;
      if (data['i'] is! List) throw const FormatException();
    } catch (_) {
      throw const ImporGagal('Kode playlist-nya rusak atau kepotong. Minta temanmu salin ulang kodenya.');
    }
    final lagu = <LaguImpor>[];
    for (final e in (data['i'] as List).take(5000)) {
      if (e is! Map) continue;
      final vid = e['v'] is String && _vid.hasMatch(e['v'] as String) ? e['v'] as String : null;
      var url = e['u'] is String && (e['u'] as String).startsWith('http') ? e['u'] as String : null;
      if (vid == null && url == null) continue;
      final video = e['m'] == 'v';
      if (vid != null) {
        url = video ? 'https://www.youtube.com/watch?v=$vid' : 'https://music.youtube.com/watch?v=$vid';
      }
      final d = e['d'];
      final judul = '${e['t'] ?? vid ?? url}';
      final artis = '${e['a'] ?? ''}';
      final t = Track(
        id: vid ?? url!,
        title: judul,
        artist: artis.isEmpty ? null : artis,
        duration: d is num && d > 0 && d < 360000 ? Duration(seconds: d.round()) : null,
        thumbUrl: vid == null ? null : 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
        webpageUrl: url,
        isVideo: video,
      );
      lagu.add(LaguImpor(judul: judul, artis: artis, detik: t.duration?.inSeconds, yt: t, status: StatusCocok.ok));
    }
    if (lagu.isEmpty) throw const ImporGagal('Kode ini nggak berisi lagu yang bisa diimpor.');
    return PratinjauImpor(nama: '${data['n'] ?? 'Playlist'}', lagu: lagu, perluCocok: false);
  }
}

enum JenisImpor { mull, spotify, spotifyLagu, ytm, yt, teks }

enum StatusCocok { menunggu, ok, ragu, nggakAda }

class SumberImpor {
  const SumberImpor(this.jenis, {this.id, this.tipe, this.url, this.idLagu, this.baris, this.teks});

  final JenisImpor jenis;
  final String? id;
  final String? tipe;
  final String? url;
  final List<String>? idLagu;
  final List<String>? baris;
  final String? teks;
}

class LaguImpor {
  LaguImpor({
    required this.judul,
    required this.artis,
    this.detik,
    this.yt,
    this.status = StatusCocok.menunggu,
    this.tidakDikenal = false,
    this.dariTeks = false,
  });

  final String judul;
  final String artis;
  final int? detik;
  Track? yt;
  StatusCocok status;
  double skor = 0;
  final bool tidakDikenal;
  final bool dariTeks;

  /// Lagu yang ragu bisa dicentang/batal centang sendiri oleh pengguna.
  bool dipakai = true;
}

class PratinjauImpor {
  PratinjauImpor({
    required this.nama,
    required this.lagu,
    required this.perluCocok,
    this.pemilik,
    this.url,
    this.terbatas = false,
  });

  final String nama;
  final String? pemilik;
  final String? url;
  final List<LaguImpor> lagu;

  /// Halaman embed Spotify cuma ngasih 100 lagu pertama.
  final bool terbatas;
  final bool perluCocok;

  String? get sampul {
    for (final l in lagu) {
      final u = l.yt?.thumbUrl;
      if (u != null) return u;
    }
    return null;
  }
}

class ImporGagal implements Exception {
  const ImporGagal(this.pesan);
  final String pesan;

  @override
  String toString() => pesan;
}
