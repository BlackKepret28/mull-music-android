import 'package:flutter/material.dart';

import '../models/track.dart';
import '../theme.dart';
import 'artwork.dart';
import 'mull_ui.dart';

/// Isi kapsul pemutar mini yang melayang di atas navigasi bawah.
/// Panel kacanya dipasang di [AppShell].
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

  /// 0..1. Dipakai buat garis tipis di bawah kapsul.
  final double progress;

  /// Lagi nyiapin stream (yt-dlp butuh beberapa detik karena QuickJS lambat).
  final bool buffering;

  final VoidCallback? onTap;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Artwork(url: track.thumbUrl, size: 44, radius: 12, isVideo: track.isVideo),
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
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        if (track.artist != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            buffering ? 'Menyiapkan...' : track.artist!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: c.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TombolPutar(
                    ikon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    tooltip: playing ? 'Jeda' : 'Putar',
                    ukuran: 44,
                    onPressed: buffering ? null : onTogglePlay,
                    child: buffering
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: c.onAccent),
                          )
                        : null,
                  ),
                  if (onNext != null)
                    IconButton(
                      onPressed: onNext,
                      tooltip: 'Lagu berikutnya',
                      icon: Icon(Icons.skip_next_rounded, size: 28, color: c.icon),
                    )
                  else
                    const SizedBox(width: 10),
                ],
              ),
            ),
            // Garis progres tipis di dasar kapsul, menjorok dari sudutnya.
            Positioned(
              left: 24,
              right: 24,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 2.5,
                  backgroundColor: c.track,
                  color: c.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
