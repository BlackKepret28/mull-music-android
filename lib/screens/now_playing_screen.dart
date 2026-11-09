import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/player_service.dart';
import '../widgets/artwork.dart';
import '../widgets/lyrics_view.dart';

/// Layar Sedang diputar, muncul dari bawah waktu bar pemutar mini diketuk.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final _player = MullAudioHandler.instance;
  bool _lirik = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Tutup',
          icon: const Icon(Icons.keyboard_arrow_down, size: 30),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          _lirik ? 'Lirik' : 'Sedang diputar',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _lirik ? 'Tampilkan sampul' : 'Tampilkan lirik',
            icon: Icon(_lirik ? Icons.album_outlined : Icons.lyrics_outlined),
            onPressed: () => setState(() => _lirik = !_lirik),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<MediaItem?>(
        stream: _player.mediaItem,
        builder: (context, snap) {
          final item = snap.data;
          if (item == null) {
            return const Center(child: Text('Nggak ada yang diputar.'));
          }
          return _Isi(player: _player, item: item, lirik: _lirik);
        },
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.player, required this.item, required this.lirik});

  final MullAudioHandler player;
  final MediaItem item;
  final bool lirik;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lebar = MediaQuery.sizeOf(context).width;
    final sisiSampul = (lebar - 80).clamp(160.0, 360.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: lirik
                  ? _PanelLirik(player: player, item: item)
                  : Center(
                      child: Artwork(
                        url: item.artUri?.toString(),
                        size: sisiSampul,
                        radius: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Text(
              item.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            if (item.artist != null) ...[
              const SizedBox(height: 6),
              Text(
                item.artist!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 28),
            _Galat(player: player),
            _Seekbar(player: player, total: item.duration),
            const SizedBox(height: 8),
            _Kontrol(player: player),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

/// Lirik yang ikut posisi lagu.
class _PanelLirik extends StatelessWidget {
  const _PanelLirik({required this.player, required this.item});

  final MullAudioHandler player;
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        return LyricsView(
          track: Track(
            id: item.id,
            title: item.title,
            artist: item.artist,
            duration: item.duration,
          ),
          posisi: snap.data ?? Duration.zero,
          onSeek: player.seek,
        );
      },
    );
  }
}

/// Pesan galat + tombol coba lagi, cuma muncul kalau ada masalah.
class _Galat extends StatelessWidget {
  const _Galat({required this.player});

  final MullAudioHandler player;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: player.galat,
      builder: (context, pesan, _) {
        if (pesan == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  pesan,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              TextButton(onPressed: player.cobaLagi, child: const Text('Coba lagi')),
            ],
          ),
        );
      },
    );
  }
}

class _Seekbar extends StatefulWidget {
  const _Seekbar({required this.player, this.total});

  final MullAudioHandler player;
  final Duration? total;

  @override
  State<_Seekbar> createState() => _SeekbarState();
}

class _SeekbarState extends State<_Seekbar> {
  /// Posisi yang lagi diseret jari; null berarti ikut pemutar.
  double? _seret;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = widget.total ?? Duration.zero;
    final maks = total.inMilliseconds.toDouble();
    final adaDurasi = maks > 0;

    return StreamBuilder<Duration>(
      stream: widget.player.positionStream,
      builder: (context, snap) {
        final posisi = snap.data ?? Duration.zero;
        final ikut = posisi.inMilliseconds.toDouble().clamp(0.0, adaDurasi ? maks : 1.0);
        final nilai = _seret ?? ikut;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: cs.primary,
                inactiveTrackColor: cs.outlineVariant,
                thumbColor: cs.primary,
              ),
              child: Slider(
                value: adaDurasi ? nilai : 0,
                max: adaDurasi ? maks : 1,
                onChanged: adaDurasi ? (v) => setState(() => _seret = v) : null,
                onChangeEnd: (v) {
                  widget.player.seek(Duration(milliseconds: v.round()));
                  setState(() => _seret = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDuration(Duration(milliseconds: nilai.round())),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  Text(
                    adaDurasi ? formatDuration(total) : '--:--',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Kontrol extends StatelessWidget {
  const _Kontrol({required this.player});

  final MullAudioHandler player;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<PlaybackState>(
      stream: player.playbackState,
      builder: (context, snap) {
        final state = snap.data;
        final main = state?.playing ?? false;
        final sibuk = state?.processingState == AudioProcessingState.loading ||
            state?.processingState == AudioProcessingState.buffering;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 36,
              tooltip: 'Sebelumnya',
              onPressed: player.skipToPrevious,
              icon: const Icon(Icons.skip_previous),
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: 68,
              height: 68,
              child: sibuk
                  ? Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
                      ),
                    )
                  : Material(
                      color: cs.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: main ? player.pause : player.play,
                        child: Icon(
                          main ? Icons.pause : Icons.play_arrow,
                          size: 36,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 20),
            IconButton(
              iconSize: 36,
              tooltip: 'Berikutnya',
              onPressed: player.skipToNext,
              icon: const Icon(Icons.skip_next),
            ),
          ],
        );
      },
    );
  }
}
