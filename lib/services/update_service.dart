import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ytdlp.dart';

/// Info rilis terbaru di GitHub.
class InfoRilis {
  const InfoRilis({
    required this.versi,
    required this.catatan,
    required this.halaman,
    this.namaAset,
    this.urlAset,
    this.ukuran,
    this.sha256,
    this.urlSha256,
  });

  final String versi;
  final String catatan;
  final String halaman;
  final String? namaAset;
  final String? urlAset;
  final int? ukuran;

  /// Dari kolom `digest` aset GitHub ("sha256:...").
  final String? sha256;

  /// Cadangan: berkas `<apk>.sha256` yang dibuat workflow rilis.
  final String? urlSha256;
}

enum TahapUpdate { diam, cek, terbaru, ada, unduh, siap, gagal }

class UpdateGagal implements Exception {
  const UpdateGagal(this.pesan);
  final String pesan;

  @override
  String toString() => pesan;
}

/// Cek dan pasang update dari GitHub Releases, ikut `mull/updater.py`
/// versi Windows. Bedanya: di Android app nggak bisa menimpa dirinya
/// sendiri, jadi APK-nya diserahkan ke penginstal Android (pengguna tetap
/// menekan "Update" di dialog sistem).
///
/// Syarat biar Android mau: APK baru ditandatangani kunci yang SAMA dengan
/// yang terpasang, dan versionCode-nya lebih besar.
class UpdateService extends ChangeNotifier {
  UpdateService._();
  static final instance = UpdateService._();

  @visibleForTesting
  factory UpdateService.baru({http.Client? client}) {
    final s = UpdateService._();
    s._client = client;
    return s;
  }

  static const repo = 'BlackKepret28/mull-music-android';
  static const _api = 'https://api.github.com';

  http.Client? _client;
  http.Client get _http => _client ??= http.Client();

  TahapUpdate _tahap = TahapUpdate.diam;
  TahapUpdate get tahap => _tahap;

  String? _pesan;
  String? get pesan => _pesan;

  InfoRilis? _rilis;
  InfoRilis? get rilis => _rilis;

  String? _versiSekarang;
  String? get versiSekarang => _versiSekarang;

  /// Diisi CI lewat --dart-define=BUILD_SHA=<7 huruf commit>. Build lokal: 'lokal'.
  static const _sha = String.fromEnvironment('BUILD_SHA', defaultValue: 'lokal');

  /// "1.0.0 · build 12 · abc1234". Nomor build dan commit beda di tiap build
  /// CI, jadi ini cara tahu app yang terpasang itu yang paling baru atau bukan.
  /// (versionCode dari split-per-abi diawali 1000/2000/4000, jadi diambil sisanya.)
  Future<String> versiLengkap() async {
    final info = await YtDlp.appInfo();
    return '${info.versi} · build ${info.kode % 1000} · $_sha';
  }

  /// 0..1 selama mengunduh.
  double _progres = 0;
  double get progres => _progres;

  String? _berkas;
  bool _batal = false;

  bool get adaUpdate => _tahap == TahapUpdate.ada || _tahap == TahapUpdate.unduh || _tahap == TahapUpdate.siap;

  void _set(TahapUpdate t, [String? pesan]) {
    _tahap = t;
    _pesan = pesan;
    notifyListeners();
  }

  Future<String> versiApp() async {
    final v = _versiSekarang;
    if (v != null) return v;
    final info = await YtDlp.appInfo();
    _versiSekarang = info.versi;
    return info.versi;
  }

  /// "v1.2.0" -> [1, 2, 0]. Bagian non-angka (mis. "-beta") dibuang.
  @visibleForTesting
  static List<int> urai(String v) => v
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[+-]'))
      .first
      .split('.')
      .map((x) => int.tryParse(x) ?? 0)
      .toList();

  /// a > b?
  @visibleForTesting
  static bool lebihBaru(String a, String b) {
    final x = urai(a);
    final y = urai(b);
    for (var i = 0; i < max(x.length, y.length); i++) {
      final p = i < x.length ? x[i] : 0;
      final q = i < y.length ? y[i] : 0;
      if (p != q) return p > q;
    }
    return false;
  }

  static int max(int a, int b) => a > b ? a : b;

  /// Pilih APK yang cocok dengan arsitektur HP. Workflow rilis bikin satu
  /// APK per ABI (`app-arm64-v8a-release.apk`, dst.).
  @visibleForTesting
  static Map? pilihAset(List assets, List<String> abi) {
    final apk = [
      for (final a in assets)
        if (a is Map && '${a['name']}'.toLowerCase().endsWith('.apk')) a,
    ];
    for (final x in abi) {
      for (final a in apk) {
        if ('${a['name']}'.contains(x)) return a;
      }
    }
    // APK gabungan (tanpa nama ABI) kalau ada.
    for (final a in apk) {
      final n = '${a['name']}';
      if (!RegExp(r'arm64|armeabi|x86').hasMatch(n)) return a;
    }
    return null;
  }

  /// Cek rilis terbaru. [diam]: dipanggil otomatis waktu app dibuka, jadi
  /// galat jaringan nggak perlu ditampilkan.
  Future<void> cek({bool diam = false}) async {
    if (_tahap == TahapUpdate.cek || _tahap == TahapUpdate.unduh) return;
    _set(TahapUpdate.cek);
    try {
      final sekarang = await versiApp();
      final info = await YtDlp.appInfo();
      final abi = info.abi;
      // Nomor build terpasang (versionCode dikurangi awalan ABI split).
      final buildSekarang = info.kode % 1000;
      final prefs = await SharedPreferences.getInstance();
      final ikutUji = prefs.getBool('ikutUji') ?? false;
      final http.Response r;
      try {
        r = await _http.get(
          Uri.parse(ikutUji ? '$_api/repos/$repo/releases?per_page=8' : '$_api/repos/$repo/releases/latest'),
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'MullMusicAndroid/$sekarang',
          },
        ).timeout(const Duration(seconds: 20));
      } catch (_) {
        throw const UpdateGagal('Nggak bisa nyambung ke GitHub. Cek internet lalu coba lagi.');
      }
      if (r.statusCode == 404) throw const UpdateGagal('Belum ada rilis yang diterbitkan.');
      if (r.statusCode == 403 || r.statusCode == 429) {
        throw const UpdateGagal('Terlalu sering cek update. Coba lagi beberapa menit lagi.');
      }
      if (r.statusCode != 200) throw UpdateGagal('GitHub menolak permintaan (HTTP ${r.statusCode}).');

      final jawaban = jsonDecode(utf8.decode(r.bodyBytes));
      final Map rel;
      if (jawaban is List) {
        // Mode build uji: ambil rilis terbaru apa pun jenisnya (resmi atau uji).
        final daftar = jawaban.whereType<Map>().where((e) => e['draft'] != true).toList();
        if (daftar.isEmpty) throw const UpdateGagal('Belum ada rilis yang diterbitkan.');
        rel = daftar.first;
      } else {
        rel = jawaban as Map;
      }
      final tag = '${rel['tag_name'] ?? ''}';
      // Tag `uji-N`: N = nomor build CI, dibandingkan dengan nomor build terpasang.
      final uji = RegExp(r'^uji-(\d+)$').firstMatch(tag);
      final versi = tag.replaceFirst(RegExp(r'^[vV]'), '');
      final assets = (rel['assets'] as List?) ?? const [];
      final aset = pilihAset(assets, abi);
      String? sha;
      final dg = '${aset?['digest'] ?? ''}';
      if (dg.startsWith('sha256:')) sha = dg.substring(7).toLowerCase();
      String? urlSha;
      if (aset != null) {
        for (final a in assets) {
          if (a is Map && a['name'] == '${aset['name']}.sha256') urlSha = a['browser_download_url'] as String?;
        }
      }
      _rilis = InfoRilis(
        versi: versi,
        catatan: '${rel['body'] ?? ''}'.trim(),
        halaman: '${rel['html_url'] ?? 'https://github.com/$repo/releases'}',
        namaAset: aset?['name'] as String?,
        urlAset: aset?['browser_download_url'] as String?,
        ukuran: (aset?['size'] as num?)?.toInt(),
        sha256: sha,
        urlSha256: urlSha,
      );
      final adaYangBaru = uji != null ? int.parse(uji.group(1)!) > buildSekarang : lebihBaru(versi, sekarang);
      if (!adaYangBaru) {
        _set(
          TahapUpdate.terbaru,
          uji != null
              ? 'Kamu sudah pakai build terbaru (build $buildSekarang).'
              : 'Kamu sudah pakai versi terbaru ($sekarang).',
        );
      } else if (aset == null) {
        _set(TahapUpdate.gagal, 'Versi $versi ada, tapi APK buat HP ini belum tersedia.');
      } else {
        _set(TahapUpdate.ada, 'Versi $versi tersedia.');
      }
    } on UpdateGagal catch (e) {
      _set(diam ? TahapUpdate.diam : TahapUpdate.gagal, diam ? null : e.pesan);
    } catch (e) {
      _set(diam ? TahapUpdate.diam : TahapUpdate.gagal, diam ? null : 'Gagal cek update: $e');
    }
  }

  /// Unduh APK, cek SHA-256, lalu buka penginstal Android.
  Future<void> unduhDanPasang() async {
    final rel = _rilis;
    if (rel == null || rel.urlAset == null) return;
    if (_tahap == TahapUpdate.siap && _berkas != null) {
      await pasang();
      return;
    }
    if (_tahap == TahapUpdate.unduh) return;
    _batal = false;
    _progres = 0;
    _set(TahapUpdate.unduh, 'Mengunduh versi ${rel.versi}...');

    final folder = Directory('${(await getTemporaryDirectory()).path}/update');
    IOSink? keluar;
    File? f;
    try {
      if (await folder.exists()) await folder.delete(recursive: true);
      await folder.create(recursive: true);
      f = File('${folder.path}/${rel.namaAset ?? 'mull-update.apk'}');

      var shaHarap = rel.sha256;
      if (shaHarap == null && rel.urlSha256 != null) {
        final r = await _http.get(Uri.parse(rel.urlSha256!)).timeout(const Duration(seconds: 20));
        if (r.statusCode == 200) {
          shaHarap = RegExp(r'[0-9a-fA-F]{64}').firstMatch(r.body)?[0]?.toLowerCase();
        }
      }

      final req = http.Request('GET', Uri.parse(rel.urlAset!));
      final resp = await _http.send(req).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) throw UpdateGagal('Unduhan gagal (HTTP ${resp.statusCode}).');
      final total = resp.contentLength ?? rel.ukuran ?? 0;

      final hasilHash = _Kotak();
      final hasher = sha256.startChunkedConversion(hasilHash);
      keluar = f.openWrite();
      var dapat = 0;
      var terakhir = DateTime.now();
      await for (final potong in resp.stream) {
        if (_batal) throw const UpdateGagal('Unduhan dibatalkan.');
        keluar.add(potong);
        hasher.add(potong);
        dapat += potong.length;
        if (total > 0 && DateTime.now().difference(terakhir).inMilliseconds > 150) {
          terakhir = DateTime.now();
          _progres = dapat / total;
          notifyListeners();
        }
      }
      await keluar.flush();
      await keluar.close();
      keluar = null;
      hasher.close();

      final hash = hasilHash.nilai.toString();
      if (shaHarap != null && hash != shaHarap) {
        throw const UpdateGagal('Berkas update rusak (hash SHA-256 nggak cocok). Coba unduh ulang.');
      }
      _berkas = f.path;
      _progres = 1;
      _set(TahapUpdate.siap, 'Versi ${rel.versi} siap dipasang.');
      await pasang();
    } on UpdateGagal catch (e) {
      await keluar?.close();
      _set(TahapUpdate.ada, e.pesan);
    } catch (e) {
      await keluar?.close();
      _set(TahapUpdate.ada, e is SocketException || e is TimeoutException
          ? 'Unduhan terputus. Cek internet lalu coba lagi.'
          : 'Unduhan gagal: $e');
    }
  }

  void batalkan() => _batal = true;

  /// Serahkan APK ke penginstal Android. Kalau izin "Instal aplikasi tak
  /// dikenal" belum ada, buka halaman izinnya dulu.
  Future<bool> pasang() async {
    final f = _berkas;
    if (f == null) return false;
    if (!await YtDlp.canInstall()) {
      _set(TahapUpdate.siap, 'Izinkan Mull memasang aplikasi, lalu ketuk Pasang lagi.');
      await YtDlp.openInstallPermission();
      return false;
    }
    await YtDlp.installApk(f);
    return true;
  }
}

class _Kotak implements Sink<Digest> {
  late Digest nilai;

  @override
  void add(Digest data) => nilai = data;

  @override
  void close() {}
}
