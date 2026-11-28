import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Saran ketikan di kolom Cari, dari layanan saran pencarian YouTube
/// (yang sama dipakai kolom cari di youtube.com). Nggak resmi dan nggak
/// butuh kunci. Gagal atau lambat = daftar kosong, jadi cari tetap jalan.
class SaranCari {
  SaranCari._();

  static Future<List<String>> ambil(String q) async {
    final kueri = q.trim();
    if (kueri.length < 2) return const [];
    try {
      final r = await http
          .get(Uri.https('suggestqueries.google.com', '/complete/search', {
            'client': 'firefox',
            'ds': 'yt',
            'hl': 'id',
            'q': kueri,
          }))
          .timeout(const Duration(seconds: 4));
      if (r.statusCode != 200) return const [];
      return urai(utf8.decode(r.bodyBytes));
    } catch (_) {
      return const [];
    }
  }

  /// Bentuk jawabannya: `["kata", ["saran 1", "saran 2", ...]]`.
  @visibleForTesting
  static List<String> urai(String badan) {
    try {
      final j = jsonDecode(badan);
      if (j is List && j.length > 1 && j[1] is List) {
        return [
          for (final e in j[1] as List)
            if (e is String && e.trim().isNotEmpty) e.trim(),
        ].take(8).toList();
      }
    } catch (_) {}
    return const [];
  }
}
