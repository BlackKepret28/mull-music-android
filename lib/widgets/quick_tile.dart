import 'package:flutter/material.dart';

import '../theme.dart';
import 'artwork.dart';

/// Petak akses cepat di Beranda: kartu pendek dua kolom berisi sampul (atau
/// ikon di kotak pastel ala MSA) di kiri dan satu-dua baris nama.
///
/// Sepadan dengan `hm-tiles` versi Windows, tapi di HP dibikin dua kolom
/// supaya jempol gampang menjangkau dan nama panjang masih kebaca.
class QuickTile extends StatelessWidget {
  const QuickTile({
    super.key,
    required this.label,
    this.icon,
    this.nada = NadaIkon.aksen,
    this.coverUrl,
    this.covers,
    this.onTap,
  });

  final String label;

  /// Dipakai kalau nggak ada sampul.
  final IconData? icon;

  /// Warna kotak ikonnya.
  final NadaIkon nada;

  final String? coverUrl;

  /// Empat sampul buat mozaik playlist.
  final List<String>? covers;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final sudut = BorderRadius.circular(18);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: sudut,
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: c.cardShadow, blurRadius: 24, offset: const Offset(0, 6))],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: sudut,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(width: 44, height: 44, child: _gambar(c)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, right: 4),
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gambar(MullColors c) {
    final mozaik = covers;
    if (mozaik != null && mozaik.length >= 4) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GridView.count(
          crossAxisCount: 2,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final u in mozaik.take(4)) Artwork(url: u, size: 22, radius: 0),
          ],
        ),
      );
    }
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return Artwork(url: coverUrl, size: 44, radius: 12);
    }
    final (latar, depan) = c.nada(nada);
    return DecoratedBox(
      decoration: BoxDecoration(color: latar, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon ?? Icons.music_note_rounded, color: depan, size: 22),
    );
  }
}
