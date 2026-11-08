import 'package:flutter/material.dart';

import '../models/track.dart';
import 'artwork.dart';

/// Satu baris lagu/video: di hasil Cari, Pustaka, dan antrean.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.onDownload,
    this.selected = false,
  });

  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;

  /// Sedang diputar: judulnya diwarnai aksen.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bawah = <String>[
      if (track.artist != null) track.artist!,
      if (track.duration != null) formatDuration(track.duration!),
    ].join('  ·  ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Artwork(url: track.thumbUrl, size: 48, radius: 6, isVideo: track.isVideo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: selected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  if (bawah.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        bawah,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
            if (track.isDownloaded)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.download_done, size: 18, color: cs.primary),
              )
            else if (onDownload != null)
              IconButton(
                tooltip: 'Unduh',
                icon: const Icon(Icons.download_outlined, size: 22),
                onPressed: onDownload,
              ),
          ],
        ),
      ),
    );
  }
}
