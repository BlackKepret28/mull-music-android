import 'package:flutter/material.dart';

import 'artwork.dart';

/// Petak akses cepat di Beranda: kotak pendek dua kolom berisi sampul atau
/// ikon di kiri dan satu baris nama.
///
/// Sepadan dengan `hm-tiles` versi Windows, tapi di HP dibikin dua kolom
/// supaya jempol gampang menjangkau dan nama panjang masih kebaca.
class QuickTile extends StatelessWidget {
  const QuickTile({
    super.key,
    required this.label,
    this.icon,
    this.coverUrl,
    this.covers,
    this.onTap,
  });

  final String label;

  /// Dipakai kalau nggak ada sampul.
  final IconData? icon;

  final String? coverUrl;

  /// Empat sampul buat mozaik playlist.
  final List<String>? covers;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(width: 52, height: 52, child: _gambar(cs)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gambar(ColorScheme cs) {
    final mozaik = covers;
    if (mozaik != null && mozaik.length >= 4) {
      return GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final u in mozaik.take(4)) Artwork(url: u, size: 26, radius: 0),
        ],
      );
    }
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return Artwork(url: coverUrl, size: 52, radius: 0);
    }
    return ColoredBox(
      color: cs.primary.withValues(alpha: 0.14),
      child: Icon(icon ?? Icons.music_note_rounded, color: cs.primary, size: 22),
    );
  }
}
