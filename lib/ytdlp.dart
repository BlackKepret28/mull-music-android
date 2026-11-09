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

  static Future<bool> deleteMedia(String uri) async =>
      (await _call('deleteMedia', {'uri': uri}))['deleted'] == true;

  /// Minta izin notifikasi (Android 13+). Tanpa ini, notifikasi pemutar dan
  /// kontrol di layar kunci nggak muncul.
  static Future<bool> ensureNotificationPermission() async =>
      (await _call('ensureNotificationPermission'))['granted'] == true;

  static Future<bool> autorun() async => (await _call('launchArgs'))['autorun'] == true;

  static Future<String> writeReport(String text) async =>
      (await _call('writeReport', {'text': text}))['value'] as String;
}
