import 'package:flutter/material.dart';

import '../models/track.dart';
import 'artwork.dart';

/// Rak kartu horizontal di Beranda (pola Spotify / YT Music).
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
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8, top: 20, bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (onSeeAll != null)
                TextButton(onPressed: onSeeAll, child: const Text('Lihat semua')),
            ],
          ),
        ),
        SizedBox(
          height: 186,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _ShelfCard(
              track: items[i],
              onTap: onTapItem == null ? null : () => onTapItem!(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.track, this.onTap});

  final Track track;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artwork(url: track.thumbUrl, size: 132, radius: 10, isVideo: false),
            const SizedBox(height: 10),
            Text(
              track.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, height: 1.25),
            ),
            if (track.artist != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  track.artist!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
