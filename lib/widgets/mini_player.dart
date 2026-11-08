import 'package:flutter/material.dart';

import '../models/track.dart';
import 'artwork.dart';

/// Bar pemutar mini yang nempel di atas navigasi bawah.
///
/// Widget ini cuma menampilkan; semua keadaan datang dari luar supaya gampang
/// dites dan nanti disambung ke just_audio/audio_service.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.track,
    required this.playing,
    this.progress = 0,
    this.buffering = false,
    this.onTap,
    this.onTogglePlay,
    this.onNext,
  });

  final Track track;
  final bool playing;

  /// 0..1. Dipakai buat garis tipis di bawah bar.
  final double progress;

  /// Lagi nyiapin stream (yt-dlp butuh beberapa detik karena QuickJS lambat).
  final bool buffering;

  final VoidCallback? onTap;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainer,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 60,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Artwork(url: track.thumbUrl, size: 44, radius: 6, isVideo: track.isVideo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        if (track.artist != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            buffering ? 'Menyiapkan...' : track.artist!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: buffering ? null : onTogglePlay,
                    tooltip: playing ? 'Jeda' : 'Putar',
                    icon: buffering
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurfaceVariant),
                          )
                        : Icon(playing ? Icons.pause : Icons.play_arrow, size: 28),
                  ),
                  if (onNext != null)
                    IconButton(
                      onPressed: onNext,
                      tooltip: 'Lagu berikutnya',
                      icon: const Icon(Icons.skip_next, size: 26),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                backgroundColor: cs.outlineVariant,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
