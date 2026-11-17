import 'package:flutter/material.dart';

import '../models/track.dart';
import '../theme.dart';
import 'artwork.dart';
import 'mull_ui.dart';

/// Rak kartu horizontal di Beranda, dibungkus kartu besar ala MSA:
/// judul bagian + tautan "Lihat semua", lalu deretan sampul yang bisa digeser.
class RakKartu extends StatelessWidget {
  const RakKartu({
    super.key,
    required this.judul,
    required this.jumlah,
    required this.itemBuilder,
    this.onLihatSemua,
    this.tinggi = 196,
  });

  final String judul;
  final int jumlah;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback? onLihatSemua;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    if (jumlah == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KartuMull(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(18, onLihatSemua == null ? 16 : 6, 8, onLihatSemua == null ? 12 : 2),
              child: KepalaKartu(
                judul: judul,
                aksi: onLihatSemua == null ? null : TautanAksi(label: 'Lihat semua', onTap: onLihatSemua),
              ),
            ),
            SizedBox(
              height: tinggi,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                itemCount: jumlah,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: itemBuilder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rak lagu (Baru diputar, Baru diunduh).
class Shelf extends StatelessWidget {
  const Shelf({
    super.key,
    required this.title,
    required this.items,
    this.onTapItem,
    this.onSeeAll,
  });

  final String title;
  final List<Track> items;
  final void Function(Track track)? onTapItem;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return RakKartu(
      judul: title,
      jumlah: items.length,
      onLihatSemua: onSeeAll,
      itemBuilder: (_, i) => _ShelfCard(
        track: items[i],
        onTap: onTapItem == null ? null : () => onTapItem!(items[i]),
      ),
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.track, this.onTap});

  final Track track;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MullUkuran.sampul),
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artwork(url: track.thumbUrl, size: 132, radius: MullUkuran.sampul, isVideo: false),
            const SizedBox(height: 10),
            Text(
              track.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.25),
            ),
            if (track.artist != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  track.artist!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
