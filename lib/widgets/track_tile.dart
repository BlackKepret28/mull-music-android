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
    this.onDownloadVideo,
    this.onTambahKePlaylist,
    this.onMenu,
    this.selected = false,
  });

  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onDownloadVideo;
  final VoidCallback? onTambahKePlaylist;

  /// Kalau diisi, tombol titik tiga cuma meneruskan ketukan ke sini dan
  /// pemanggil yang nentuin isi menunya.
  final VoidCallback? onMenu;

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
              ),
            if (onMenu != null)
              IconButton(
                tooltip: 'Opsi lain',
                icon: const Icon(Icons.more_vert, size: 20),
                onPressed: onMenu,
              )
            else if (onDownload != null || onTambahKePlaylist != null)
              PopupMenuButton<String>(
                tooltip: 'Opsi lain',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) => switch (v) {
                  'unduh' => onDownload?.call(),
                  'video' => onDownloadVideo?.call(),
                  'playlist' => onTambahKePlaylist?.call(),
                  _ => null,
                },
                itemBuilder: (_) => [
                  if (onDownload != null && !track.isDownloaded)
                    const PopupMenuItem(value: 'unduh', child: Text('Unduh lagu')),
                  if (onDownloadVideo != null && !track.isDownloaded)
                    const PopupMenuItem(value: 'video', child: Text('Unduh video 720p')),
                  if (onTambahKePlaylist != null)
                    const PopupMenuItem(value: 'playlist', child: Text('Tambah ke playlist')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
