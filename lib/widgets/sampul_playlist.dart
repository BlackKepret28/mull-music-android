import 'package:flutter/material.dart';

import '../services/playlist_service.dart';
import '../theme.dart';
import 'artwork.dart';

/// Sampul playlist yang ikut isinya, sama dengan versi Windows
/// (`mosaic()` di `ui/playlists.js`): 4 sampul unik pertama jadi mozaik
/// 2x2; kalau cuma 1-3, sampul pertama; kalau belum ada, ikon playlist.
/// Karena dihitung dari lagu, sampulnya otomatis berubah tiap lagu
/// ditambah, dibuang, atau diurutkan ulang.
class SampulPlaylist extends StatelessWidget {
  const SampulPlaylist({
    super.key,
    required this.playlist,
    this.ukuran,
    this.radius = MullUkuran.sampul,
  });

  final Playlist playlist;

  /// Sisi kotak. Null = ikut ruang yang tersedia (pakai di dalam
  /// AspectRatio atau SizedBox).
  final double? ukuran;
  final double radius;

  /// Sampul unik (urutan lagu), maksimal 4.
  static List<String> dari(Playlist p) {
    final hasil = <String>[];
    for (final t in p.lagu) {
      final u = t.thumbUrl;
      if (u == null || u.isEmpty || hasil.contains(u)) continue;
      hasil.add(u);
      if (hasil.length == 4) break;
    }
    return hasil;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final sampul = dari(playlist);
    final ikon = ColoredBox(
      color: c.violetSoft,
      child: Center(
        child: Icon(
          Icons.queue_music_rounded,
          color: c.violet,
          size: ukuran == null ? 30 : (ukuran! * 0.38).clamp(18.0, 64.0),
        ),
      ),
    );
    Widget gambar(String u) => GambarSampul(url: u, cadangan: ColoredBox(color: c.chipBg));

    final isi = switch (sampul.length) {
      0 => ikon,
      1 || 2 || 3 => gambar(sampul.first),
      _ => Column(
          children: [
            for (final baris in [sampul.sublist(0, 2), sampul.sublist(2, 4)])
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final u in baris) Expanded(child: gambar(u))],
                ),
              ),
          ],
        ),
    };

    final kotak = ClipRRect(borderRadius: BorderRadius.circular(radius), child: isi);
    if (ukuran == null) return kotak;
    return SizedBox(width: ukuran, height: ukuran, child: kotak);
  }
}
