import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Ambil satu warna yang mewakili sampul lagu.
///
/// Ini yang bikin layar Sedang diputar di Spotify dan YouTube Music kelihatan
/// "nyambung" sama lagunya: latarnya ikut warna sampul, bukan abu-abu terus.
///
/// Sengaja dihitung sendiri, bukan pakai paket: `palette_generator` sudah
/// dihentikan tim Flutter, dan yang kita butuh cuma satu warna. Sampulnya
/// di-decode kecil (24x24) jadi murah banget.
abstract final class CoverColor {
  static final _cache = <String, Color?>{};
  static final _sedangJalan = <String, Future<Color?>>{};

  /// Null kalau sampulnya nggak ada atau gagal dibaca.
  static Future<Color?> dari(String? url) {
    if (url == null || url.isEmpty) return Future.value();
    if (_cache.containsKey(url)) return Future.value(_cache[url]);
    // Dua pemanggil buat sampul yang sama cukup satu kerjaan.
    return _sedangJalan[url] ??= _hitung(url).whenComplete(() {
      _sedangJalan.remove(url);
    });
  }

  static Future<Color?> _hitung(String url) async {
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return _simpan(url, null);

      // Decode langsung ke ukuran kecil: kita cuma butuh warnanya.
      final codec = await ui.instantiateImageCodec(
        r.bodyBytes,
        targetWidth: 24,
        targetHeight: 24,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      codec.dispose();
      if (data == null) return _simpan(url, null);

      return _simpan(url, _dominan(data.buffer.asUint8List()));
    } catch (_) {
      return _simpan(url, null);
    }
  }

  static Color? _simpan(String url, Color? c) {
    _cache[url] = c;
    return c;
  }

  /// Kelompokkan piksel ke kotak warna kasar, lalu pilih kotak dengan skor
  /// terbaik. Skor mengutamakan warna yang pekat dan sering muncul, dan
  /// menghindari yang terlalu gelap atau terlalu pucat (sampul sering punya
  /// banyak hitam/putih yang nggak mewakili apa-apa).
  static Color? _dominan(Uint8List rgba) {
    final jumlah = <int, int>{};
    final totalR = <int, int>{};
    final totalG = <int, int>{};
    final totalB = <int, int>{};

    for (var i = 0; i + 3 < rgba.length; i += 4) {
      final a = rgba[i + 3];
      if (a < 128) continue;

      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];

      final maks = r > g ? (r > b ? r : b) : (g > b ? g : b);
      final min = r < g ? (r < b ? r : b) : (g < b ? g : b);

      // Buang yang hampir hitam atau hampir putih.
      if (maks < 36 || min > 232) continue;

      // Kuantisasi 4 bit per kanal: cukup buat ngelompokkan warna senada.
      final kunci = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      jumlah[kunci] = (jumlah[kunci] ?? 0) + 1;
      totalR[kunci] = (totalR[kunci] ?? 0) + r;
      totalG[kunci] = (totalG[kunci] ?? 0) + g;
      totalB[kunci] = (totalB[kunci] ?? 0) + b;
    }

    if (jumlah.isEmpty) return null;

    int? terbaik;
    var skorTerbaik = -1.0;

    for (final e in jumlah.entries) {
      final n = e.value;
      final r = totalR[e.key]! / n;
      final g = totalG[e.key]! / n;
      final b = totalB[e.key]! / n;

      final maks = [r, g, b].reduce((a, c) => a > c ? a : c);
      final min = [r, g, b].reduce((a, c) => a < c ? a : c);
      final saturasi = maks <= 0 ? 0.0 : (maks - min) / maks;

      // Warna pekat dihargai jauh lebih tinggi daripada abu-abu yang kebetulan
      // banyak, tapi jumlah tetap ikut dihitung biar nggak kepilih satu piksel
      // nyentrik di pojok.
      final skor = n * (0.25 + saturasi * 1.75);
      if (skor > skorTerbaik) {
        skorTerbaik = skor;
        terbaik = e.key;
      }
    }

    if (terbaik == null) return null;
    final n = jumlah[terbaik]!;
    return Color.fromARGB(
      255,
      (totalR[terbaik]! / n).round(),
      (totalG[terbaik]! / n).round(),
      (totalB[terbaik]! / n).round(),
    );
  }

  /// Versi warna yang aman dipakai jadi latar, dengan teks terang di atasnya.
  ///
  /// Warna sampul mentah sering terlalu menyala buat jadi latar selayar penuh.
  /// Di tema gelap digelapkan, di tema terang dibikin pucat.
  static Color latar(Color asal, Brightness brightness) {
    final hsl = HSLColor.fromColor(asal);
    return brightness == Brightness.dark
        ? hsl.withSaturation((hsl.saturation * 0.72).clamp(0.0, 0.52)).withLightness(0.20).toColor()
        : hsl.withSaturation((hsl.saturation * 0.70).clamp(0.0, 0.60)).withLightness(0.86).toColor();
  }

  @visibleForTesting
  static Color? dominanUntukTes(Uint8List rgba) => _dominan(rgba);

  @visibleForTesting
  static void bersihkanCache() {
    _cache.clear();
    _sedangJalan.clear();
  }
}
