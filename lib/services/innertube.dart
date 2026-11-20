import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'log_service.dart';

/// Jalur kilat buat ambil URL audio YouTube: satu permintaan HTTP langsung ke
/// API internal YouTube (cara yang sama dipakai app YouTube di headset VR),
/// tanpa menjalankan Python/yt-dlp. Hasilnya ~1 detik, bukan 10-30 detik.
///
/// Ini cuma jalur cepat. Kalau YouTube mengubah aturannya dan permintaan ini
/// gagal (atau URL-nya ditolak), pemanggil jatuh ke yt-dlp seperti biasa,
/// jadi paling buruk app kembali ke kecepatan lama. Nilai klien di bawah ini
/// sama dengan yang dipakai yt-dlp untuk klien `android_vr`.
class Innertube {
  Innertube._();

  static const versiKlien = '1.65.10';
  static const userAgent =
      'com.google.android.apps.youtube.vr.oculus/$versiKlien (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';

  static final _idYoutube = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// Cuma id video YouTube asli (11 karakter) yang bisa lewat jalur ini.
  static bool bisaDipakai(String id) => _idYoutube.hasMatch(id);

  static Map<String, dynamic> badanPermintaan(String videoId) => {
        'context': {
          'client': {
            'clientName': 'ANDROID_VR',
            'clientVersion': versiKlien,
            'deviceMake': 'Oculus',
            'deviceModel': 'Quest 3',
            'androidSdkVersion': 32,
            'userAgent': userAgent,
            'osName': 'Android',
            'osVersion': '12L',
            'hl': 'en',
            'timeZone': 'UTC',
            'utcOffsetMinutes': 0,
          },
        },
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
      };

  /// Pilih URL audio terbaik dari jawaban API: m4a (AAC) dengan bitrate
  /// tertinggi, sama seperti pilihan utama yt-dlp di app ini. Trek dubbing
  /// bahasa lain dilewati. Null kalau nggak ada yang bisa dipakai.
  static String? pilihAudio(Map<String, dynamic> json) {
    final status = json['playabilityStatus'];
    if (status is! Map || status['status'] != 'OK') return null;
    final data = json['streamingData'];
    if (data is! Map) return null;
    final formats = data['adaptiveFormats'];
    if (formats is! List) return null;

    Map? terbaik;
    var bitrateTerbaik = -1;
    for (final f in formats.whereType<Map>()) {
      final url = f['url'];
      if (url is! String || url.isEmpty) continue;
      final mime = f['mimeType']?.toString() ?? '';
      if (!mime.startsWith('audio/mp4')) continue;
      final trek = f['audioTrack'];
      if (trek is Map && trek['audioIsDefault'] == false) continue;
      final bitrate = (f['bitrate'] as num?)?.toInt() ?? 0;
      if (bitrate > bitrateTerbaik) {
        terbaik = f;
        bitrateTerbaik = bitrate;
      }
    }
    return terbaik?['url'] as String?;
  }

  /// Cadangan: berkas campuran (gambar + suara, biasanya itag 18, 360p). Sejak
  /// Juli 2026 klien android_vr cuma ngasih URL buat format ini tanpa PO token,
  /// sedangkan format audio-saja nggak punya URL. Pemutar cuma memakai suaranya,
  /// jadi kuota terpakai lebih banyak daripada audio-saja. Dipilih yang
  /// bitrate-nya paling kecil.
  static String? pilihCampuran(Map<String, dynamic> json) {
    final status = json['playabilityStatus'];
    if (status is! Map || status['status'] != 'OK') return null;
    final data = json['streamingData'];
    if (data is! Map) return null;
    final formats = data['formats'];
    if (formats is! List) return null;

    Map? terbaik;
    var bitrateTerkecil = 1 << 62;
    for (final f in formats.whereType<Map>()) {
      final url = f['url'];
      if (url is! String || url.isEmpty) continue;
      final mime = f['mimeType']?.toString() ?? '';
      if (!mime.startsWith('video/mp4') || f['audioQuality'] == null) continue;
      final bitrate = (f['bitrate'] as num?)?.toInt() ?? bitrateTerkecil - 1;
      if (bitrate < bitrateTerkecil) {
        terbaik = f;
        bitrateTerkecil = bitrate;
      }
    }
    return terbaik?['url'] as String?;
  }

  /// Ringkasan kenapa nggak ada URL, buat log.
  static String alasan(Map<String, dynamic> json) {
    final status = json['playabilityStatus'];
    final st = status is Map ? '${status['status']} ${status['reason'] ?? ''}'.trim() : 'tanpa status';
    final data = json['streamingData'];
    int hitung(Object? l, {bool denganUrl = false}) => l is List
        ? l.whereType<Map>().where((f) => !denganUrl || (f['url'] is String)).length
        : 0;
    final adaptif = data is Map ? data['adaptiveFormats'] : null;
    final campuran = data is Map ? data['formats'] : null;
    return 'status=$st adaptif=${hitung(adaptif)} (berURL=${hitung(adaptif, denganUrl: true)}) '
        'campuran=${hitung(campuran)} (berURL=${hitung(campuran, denganUrl: true)})';
  }

  /// Ambil URL audio. Melempar kalau gagal atau URL-nya ditolak server.
  static Future<String> audio(String videoId) async {
    final klien = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await klien
          .postUrl(Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false'))
          .timeout(const Duration(seconds: 6));
      req.headers
        ..set('Content-Type', 'application/json')
        ..set('User-Agent', userAgent)
        ..set('X-YouTube-Client-Name', '28')
        ..set('X-YouTube-Client-Version', versiKlien)
        ..set('Origin', 'https://www.youtube.com');
      req.add(utf8.encode(jsonEncode(badanPermintaan(videoId))));

      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw Exception('Jalur kilat ditolak (HTTP ${res.statusCode})');
      }
      final teks = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 8));
      final json = jsonDecode(teks);
      final peta = json is Map<String, dynamic> ? json : <String, dynamic>{};
      var url = pilihAudio(peta);
      if (url == null) {
        url = pilihCampuran(peta);
        if (url == null) throw Exception('Jalur kilat kosong: ${alasan(peta)}');
        LogService.instance.catat('kilat', 'audio-saja nggak ada, pakai berkas campuran 360p (${alasan(peta)})');
      }

      await _periksa(klien, url);
      return url;
    } finally {
      klien.close(force: true);
    }
  }

  /// Minta 2 byte pertama. Kalau server menolak (mis. 403), lebih baik tahu
  /// sekarang lalu jatuh ke yt-dlp, daripada pemutar error di tengah jalan.
  static Future<void> _periksa(HttpClient klien, String url) async {
    final req = await klien.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 6));
    req.headers
      ..set('User-Agent', userAgent)
      ..set('Range', 'bytes=0-1');
    final res = await req.close().timeout(const Duration(seconds: 6));
    await res.drain<void>();
    if (res.statusCode != 200 && res.statusCode != 206) {
      throw Exception('URL audio ditolak (HTTP ${res.statusCode})');
    }
  }
}
