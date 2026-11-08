import 'package:flutter/material.dart';

/// Sampul lagu/video. Kotak, sudut membulat, ada penampung kalau gambarnya
/// belum ada atau gagal dimuat.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    this.url,
    this.size = 56,
    this.radius = 8,
    this.isVideo = false,
  });

  final String? url;
  final double size;
  final double radius;

  /// Video dibikin 16:9, bukan kotak.
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final w = isVideo ? size * 16 / 9 : size;
    final shape = BorderRadius.circular(radius);

    return ClipRRect(
      borderRadius: shape,
      child: SizedBox(
        width: w,
        height: size,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: url == null || url!.isEmpty
              ? _Placeholder(isVideo: isVideo)
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _Placeholder(isVideo: isVideo),
                  // Tanpa animasi muncul: biar daftar panjang nggak kedip-kedip.
                  gaplessPlayback: true,
                ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        isVideo ? Icons.movie_outlined : Icons.music_note_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 20,
      ),
    );
  }
}
