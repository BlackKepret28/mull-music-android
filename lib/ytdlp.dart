import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// Progres unduhan dari sisi Kotlin (youtubedl-android).
class YtDlpProgress {
  YtDlpProgress(this.id, this.progress, this.eta, this.line);

  final String id;

  /// 0..100, atau -1 kalau belum diketahui.
  final double progress;

  /// Perkiraan sisa waktu dalam detik.
  final int eta;
  final String line;
}

/// Pembungkus platform channel "mull/ytdlp".
class YtDlp {
  YtDlp._();

  static const _method = MethodChannel('mull/ytdlp');
  static const _events = EventChannel('mull/ytdlp/progress');

  static final Stream<YtDlpProgress> progress = _events
      .receiveBroadcastStream()
      .map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return YtDlpProgress(
          m['id'] as String,
          (m['progress'] as num).toDouble(),
          (m['eta'] as num).toInt(),
          (m['line'] as String?) ?? '',
        );
      })
      .asBroadcastStream();

  static Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? args]) async {
    final r = await _method.invokeMethod<dynamic>(name, args);
    if (r is Map) return Map<String, dynamic>.from(r);
    return {'value': r};
  }

  /// Siapkan Python + yt-dlp + ffmpeg. Kembalikan lama init (ms).
  static Future<int> init() async => ((await _call('init'))['ms'] as num).toInt();

  /// Versi yt-dlp yang tercatat. Null kalau masih pakai bawaan AAR (belum pernah di-update).
  static Future<String?> version() async => (await _call('version'))['version'] as String?;

  /// Perbarui yt-dlp. [channel]: stable, nightly, master.
  static Future<Map<String, dynamic>> update({String channel = 'stable'}) =>
      _call('updateYtDlp', {'channel': channel});

  /// Hasil `yt-dlp -J` (sudah di-decode) plus lama proses.
  static Future<({Map<String, dynamic> info, int ms})> getInfo(String url, {List<String> args = const []}) async {
    final r = await _call('getInfo', {'url': url, 'args': args});
    return (
      info: Map<String, dynamic>.from(jsonDecode(r['json'] as String) as Map),
      ms: (r['ms'] as num).toInt(),
    );
  }

  static Future<Map<String, dynamic>> download(String id, String url, {List<String> args = const []}) =>
      _call('download', {'id': id, 'url': url, 'args': args});

  static Future<bool> cancel(String id) async => (await _call('cancel', {'id': id}))['value'] == true;

  /// Jalankan yt-dlp dengan argumen mentah (buat diagnosa).
  static Future<Map<String, dynamic>> exec(List<String> args) => _call('exec', {'args': args});

  /// Unduh lalu pindahkan ke penyimpanan bersama (Music/Mull atau Movies/Mull).
  /// Balikin `{exitCode, ms, files: [{name, size, uri, video}], err}`.
  static Future<Map<String, dynamic>> downloadMedia(
    String id,
    String url, {
    List<String> args = const [],
    bool video = false,
  }) =>
      _call('downloadMedia', {'id': id, 'url': url, 'args': args, 'video': video});

  /// Isi Music/Mull dan Movies/Mull menurut MediaStore.
  static Future<List<Map<String, dynamic>>> listLibrary() async {
    final r = await _call('listLibrary');
    return ((r['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  /// Sudah boleh baca semua lagu di HP (READ_MEDIA_AUDIO)?
  static Future<bool> hasAudioPermission() async =>
      (await _call('hasAudioPermission'))['granted'] == true;

  /// Minta izin baca lagu. Dialognya dari sistem, jawabannya datang belakangan.
  static Future<bool> ensureAudioPermission() async =>
      (await _call('ensureAudioPermission'))['granted'] == true;

  /// Sampul bawaan berkas lokal (JPEG). Null kalau berkasnya nggak punya gambar.
  static Future<Uint8List?> thumbnail(String uri, {int size = 256}) async {
    final r = await _call('thumbnail', {'uri': uri, 'size': size});
    final b = r['bytes'];
    return b is Uint8List ? b : null;
  }

  /// Hapus satu berkas. Berkas yang bukan milik app memunculkan dialog
  /// konfirmasi dari Android; `dibatalkan` true kalau pengguna menolak.
  static Future<({bool terhapus, bool dibatalkan})> deleteMedia(String uri) async {
    final r = await _call('deleteMedia', {'uri': uri});
    return (terhapus: r['deleted'] == true, dibatalkan: r['canceled'] == true);
  }

  // ---- Kenali lagu -------------------------------------------------------

  /// Potongan audio jadi PCM 16-bit mono 16 kHz. [source]: uri content://,
  /// path berkas, atau URL http (boleh pakai [headers]).
  static Future<({Uint8List pcm, int? durasiMs})> decodePcm(
    String source, {
    Map<String, String>? headers,
    int startMs = 0,
    int lengthMs = 12000,
  }) async {
    final r = await _call('decodePcm', {
      'source': source,
      'headers': headers,
      'startMs': startMs,
      'lengthMs': lengthMs,
    });
    return (
      pcm: (r['pcm'] as Uint8List?) ?? Uint8List(0),
      durasiMs: (r['durationMs'] as num?)?.toInt(),
    );
  }

  static Future<bool> ensureMicPermission() async =>
      (await _call('ensureMicPermission'))['granted'] == true;

  static Future<void> micStart() => _call('micStart');
  static Future<void> micStop() => _call('micStop');

  static Future<({double level, double detik})> micStatus() async {
    final r = await _call('micStatus');
    return (
      level: (r['level'] as num?)?.toDouble() ?? 0,
      detik: (r['seconds'] as num?)?.toDouble() ?? 0,
    );
  }

  /// PCM [detik] detik terakhir dari mikrofon.
  static Future<Uint8List> micSnapshot(double detik) async =>
      ((await _call('micSnapshot', {'seconds': detik}))['pcm'] as Uint8List?) ?? Uint8List(0);

  // ---- Update app ----------------------------------------------------------

  static Future<({String versi, int kode, List<String> abi})> appInfo() async {
    final r = await _call('appInfo');
    return (
      versi: (r['versionName'] as String?) ?? '0.0.0',
      kode: (r['versionCode'] as num?)?.toInt() ?? 0,
      abi: ((r['abis'] as List?) ?? const []).cast<String>(),
    );
  }

  /// Sudah boleh memasang APK dari app ini ("Instal aplikasi tak dikenal")?
  static Future<bool> canInstall() async => (await _call('canInstall'))['granted'] == true;

  /// Buka halaman izin "Instal aplikasi tak dikenal" buat Mull.
  static Future<void> openInstallPermission() => _call('openInstallPermission');

  /// Serahkan APK di [path] (harus di folder cache/update) ke penginstal Android.
  static Future<void> installApk(String path) => _call('installApk', {'path': path});

  /// Buka tautan di browser HP.
  static Future<void> openUrl(String url) => _call('openUrl', {'url': url});

  /// Lembar Bagikan Android.
  static Future<void> shareText(String text, {String title = 'Bagikan'}) =>
      _call('shareText', {'text': text, 'title': title});

  /// Minta izin notifikasi (Android 13+). Tanpa ini, notifikasi pemutar dan
  /// kontrol di layar kunci nggak muncul.
  static Future<bool> ensureNotificationPermission() async =>
      (await _call('ensureNotificationPermission'))['granted'] == true;

  static Future<bool> hasNotificationPermission() async =>
      (await _call('hasNotificationPermission'))['granted'] == true;

  static Future<void> openNotificationSettings() => _call('openNotificationSettings');

  /// Daftar "Optimalisasi baterai" Android, buat mengecualikan Mull supaya
  /// ROM yang agresif (Infinix/XOS dkk.) nggak mematikan pemutar di latar.
  static Future<void> openBatterySettings() => _call('openBatterySettings');

  /// Bawa app ke depan (dipakai tombol logo di notifikasi pemutar).
  static Future<void> bukaApp() => _call('bukaApp');

  /// Status notifikasi + layanan pemutar buat layar Diagnostik.
  static Future<Map<String, dynamic>> diagNotifikasi() => _call('diagNotifikasi');

  /// Kirim notifikasi biasa (bukan pemutar) buat ngetes izin dan kanal.
  static Future<void> testNotification() => _call('testNotification');

  /// Log sistem milik app ini, sudah disaring (error, layanan, notifikasi).
  static Future<String> getLogcat() async => ((await _call('getLogcat'))['log'] as String?) ?? '';

  static bool _izinNotifDiminta = false;

  /// Minta izin notifikasi (Android 13+). Satu pintu buat semua layar.
  /// Cuma "dikunci" kalau sudah diizinkan, jadi kalau tadinya ditolak atau
  /// dialognya nggak sempat muncul, putar lagu berikutnya mencoba lagi
  /// (Android sendiri yang membatasi berapa kali dialog boleh tampil).
  static Future<bool> mintaIzinNotifikasi() async {
    if (_izinNotifDiminta) return true;
    try {
      final ok = await ensureNotificationPermission();
      _izinNotifDiminta = ok;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> autorun() async => (await _call('launchArgs'))['autorun'] == true;

  static Future<String> writeReport(String text) async =>
      (await _call('writeReport', {'text': text}))['value'] as String;
}
