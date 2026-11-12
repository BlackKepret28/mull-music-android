import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ytdlp.dart';

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

  /// `https://...` (YouTube) atau `content://...` (berkas di HP).
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
          child: GambarSampul(url: url, cadangan: _Placeholder(isVideo: isVideo)),
        ),
      ),
    );
  }
}

/// Gambar sampul dari web atau dari berkas lokal.
///
/// Berkas di HP (`content://`) nggak bisa dibaca `Image.network`, jadi
/// sampulnya diminta ke Android (`loadThumbnail`) dan disimpan di memori
/// biar daftar panjang nggak minta ulang tiap kali digulir.
class GambarSampul extends StatefulWidget {
  const GambarSampul({super.key, required this.url, this.cadangan, this.fit = BoxFit.cover});

  final String? url;
  final Widget? cadangan;
  final BoxFit fit;

  static bool lokal(String? url) => url != null && url.startsWith('content://');

  /// Ambil sampul berkas lokal (dengan cache). Dipakai juga oleh CoverColor.
  static Future<Uint8List?> bacaLokal(String uri) {
    final ada = _cache.remove(uri);
    if (ada != null) {
      _cache[uri] = ada; // naikkan jadi yang paling baru dipakai
      return ada;
    }
    final f = YtDlp.thumbnail(uri).catchError((_) => null);
    _cache[uri] = f;
    while (_cache.length > 300) {
      _cache.remove(_cache.keys.first);
    }
    return f;
  }

  static final _cache = <String, Future<Uint8List?>>{};

  @override
  State<GambarSampul> createState() => _GambarSampulState();
}

class _GambarSampulState extends State<GambarSampul> {
  Future<Uint8List?>? _lokal;

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  @override
  void didUpdateWidget(GambarSampul lama) {
    super.didUpdateWidget(lama);
    if (lama.url != widget.url) _siapkan();
  }

  void _siapkan() {
    final u = widget.url;
    _lokal = GambarSampul.lokal(u) ? GambarSampul.bacaLokal(u!) : null;
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.url;
    final cadangan = widget.cadangan ?? const SizedBox.shrink();
    if (u == null || u.isEmpty) return cadangan;

    final lokal = _lokal;
    if (lokal != null) {
      return FutureBuilder<Uint8List?>(
        future: lokal,
        builder: (context, snap) {
          final b = snap.data;
          if (b == null) return cadangan;
          return Image.memory(b, fit: widget.fit, gaplessPlayback: true);
        },
      );
    }

    return Image.network(
      u,
      fit: widget.fit,
      errorBuilder: (_, _, _) => cadangan,
      // Tanpa animasi muncul: biar daftar panjang nggak kedip-kedip.
      gaplessPlayback: true,
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
