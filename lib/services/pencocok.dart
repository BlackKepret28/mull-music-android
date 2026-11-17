import '../models/track.dart';
import 'ytdlp_service.dart';

/// Mencari pasangan YouTube buat lagu yang cuma diketahui judul dan
/// artisnya (hasil Kenali lagu, lagu Spotify, baris teks). Logikanya ikut
/// `finder.find_on_youtube` versi Windows, tapi sumbernya pencarian YouTube
/// biasa (`ytsearch`), karena ytmusicapi nggak ada di Android.
class Pencocok {
  Pencocok._();

  static const _aksen = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c', 'ß': 'ss', 'ý': 'y', 'ÿ': 'y',
    '’': "'", '‘': "'",
  };

  static final _kurung = RegExp(r'\([^)]*\)|\[[^\]]*\]');
  static final _bukanHuruf = RegExp(r'[^a-z0-9]+');

  /// Huruf kecil, tanpa aksen, tanpa isi kurung, cuma huruf dan angka.
  static String norm(String? s) {
    var x = (s ?? '').toLowerCase();
    final b = StringBuffer();
    for (final r in x.runes) {
      final c = String.fromCharCode(r);
      b.write(_aksen[c] ?? c);
    }
    x = b.toString().replaceAll(_kurung, ' ');
    return x.replaceAll(_bukanHuruf, ' ').trim();
  }

  static Set<String> _kata(String? s) => norm(s).split(' ').where((w) => w.isNotEmpty).toSet();

  /// Berapa bagian kata [dicari] yang ada di [di] (0..1).
  static double termuat(String? dicari, String? di) {
    final a = _kata(dicari);
    if (a.isEmpty) return 0;
    final b = _kata(di);
    return a.where(b.contains).length / a.length;
  }

  static final _versi = RegExp(
    r'\b(live|remix|cover|karaoke|instrumental|acoustic|akustik|sped up|slowed|nightcore|8d)\b',
  );

  /// Artis pertama dari "A, B & C feat. D".
  static String artisPertama(String artis) =>
      artis.split(RegExp(r',|&| feat\.? | ft\.? | x ', caseSensitive: false)).first.trim();

  /// Skor 0..1 seberapa yakin [t] itu lagu [judul] oleh [artis].
  static double skor(String judul, String artis, Track t, {int? detik}) {
    final pertama = artisPertama(artis);
    final judulYt = t.title;
    final semua = '${t.title} ${t.artist ?? ''}';
    var s = termuat(judul, judulYt) * 0.65 + (pertama.isEmpty ? 0.5 : termuat(pertama, semua)) * 0.35;

    // Judul YouTube jauh lebih panjang dari judulnya: kemungkinan kompilasi.
    final lebih = _kata(judulYt).difference(_kata('$judul $artis'));
    if (lebih.length > 8) s -= 0.1;

    final d = t.duration?.inSeconds;
    if (detik != null && detik > 0 && d != null) {
      final beda = (detik - d).abs();
      s -= beda <= 4 ? 0 : (beda <= 15 ? 0.1 : 0.3);
    }

    final ekstra = _versi.allMatches(judulYt.toLowerCase()).map((m) => m[0]).toSet()
      ..removeAll(_versi.allMatches(judul.toLowerCase()).map((m) => m[0]));
    if (ekstra.isNotEmpty) s -= 0.2;
    return s.clamp(0.0, 1.0);
  }

  /// Pasangan YouTube terbaik + skornya. Track null kalau skornya di bawah
  /// [minimal].
  static Future<(Track?, double)> cari(
    String judul,
    String artis, {
    int? detik,
    double minimal = 0.5,
  }) async {
    final q = '$judul ${artisPertama(artis)}'.trim();
    if (q.isEmpty) return (null, 0.0);
    final hasil = await YtDlpService.instance.search(q, limit: 6);
    Track? terbaik;
    var nilai = 0.0;
    for (final t in hasil) {
      if (t.id.isEmpty) continue;
      final s = skor(judul, artis, t, detik: detik);
      if (s > nilai) {
        terbaik = t;
        nilai = s;
      }
    }
    if (nilai < minimal) terbaik = null;
    return (terbaik, double.parse(nilai.toStringAsFixed(3)));
  }
}
