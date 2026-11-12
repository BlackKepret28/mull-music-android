import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/playlist_service.dart';
import '../theme.dart';
import 'artwork.dart';
import 'mull_ui.dart';

/// Kartu video 16:9 dengan badge durasi di pojok.
///
/// Video lebih enak dilihat sebagai kartu daripada baris daftar: gambarnya
/// yang jadi petunjuk utama, bukan judulnya.
class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.track, this.onTap, this.onMenu});

  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MullUkuran.sampul),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(MullUkuran.sampul),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: track.thumbUrl == null || track.thumbUrl!.isEmpty
                      ? ColoredBox(
                          color: cs.surfaceContainer,
                          child: Icon(
                            Icons.movie_rounded,
                            color: cs.onSurfaceVariant,
                            size: 26,
                          ),
                        )
                      : Image.network(
                          track.thumbUrl!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: cs.surfaceContainer,
                            child: Icon(
                              Icons.movie_rounded,
                              color: cs.onSurfaceVariant,
                              size: 26,
                            ),
                          ),
                        ),
                ),
              ),
              if (track.duration != null)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        formatDuration(track.duration!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              if (onMenu != null)
                SizedBox(
                  width: 26,
                  height: 26,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Opsi lain',
                    icon: const Icon(Icons.more_vert, size: 18),
                    onPressed: onMenu,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu playlist: mozaik empat sampul pertama + nama + jumlah lagu.
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({super.key, required this.playlist, this.onTap});

  final Playlist playlist;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final sampul = playlist.lagu
        .map((t) => t.thumbUrl)
        .where((u) => u != null && u.isNotEmpty)
        .cast<String>()
        .take(4)
        .toList();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MullUkuran.sampul),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MullUkuran.sampul),
              child: switch (sampul.length) {
                0 => ColoredBox(
                    color: context.mull.violetSoft,
                    child: Icon(Icons.queue_music_rounded, color: context.mull.violet, size: 30),
                  ),
                1 || 2 || 3 => Artwork(url: sampul.first, size: double.infinity, radius: 0),
                _ => GridView.count(
                    crossAxisCount: 2,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final u in sampul) Artwork(url: u, size: double.infinity, radius: 0),
                    ],
                  ),
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            playlist.nama,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            playlist.lagu.isEmpty ? 'Masih kosong' : '${playlist.lagu.length} lagu',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Kartu "bikin playlist baru", bentuknya sama dengan [PlaylistCard].
class PlaylistCardBaru extends StatelessWidget {
  const PlaylistCardBaru({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MullUkuran.sampul),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            // Kartu kosong ala MSA: isi kartu + garis tipis + ikon di kotak aksen.
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.mull.surface,
                borderRadius: BorderRadius.circular(MullUkuran.sampul),
                border: Border.all(color: context.mull.border),
              ),
              child: const Center(child: KotakIkon(ikon: Icons.add_rounded, ukuran: 48)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Playlist baru',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Kumpulkan lagu',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
