import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../aksi.dart';
import '../models/track.dart';
import '../services/download_service.dart';
import '../services/library_service.dart';
import '../services/playlist_service.dart';
import '../services/player_service.dart';
import '../widgets/artwork.dart';
import '../widgets/lyrics_view.dart';
import '../theme.dart';
import '../widgets/mull_ui.dart';
import 'finder_screen.dart';
import 'playlist_screen.dart';

/// Layar Sedang diputar, muncul dari bawah waktu bar pemutar mini diketuk.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final _player = MullAudioHandler.instance;
  bool _lirik = false;

  /// Halaman 0 = antrean (geser ke kanan), halaman 1 = pemutar.
  final _halaman = PageController(initialPage: 1);
  int _hal = 1;

  @override
  void dispose() {
    _halaman.dispose();
    super.dispose();
  }

  void _menu() {
    final t = _player.current;
    tampilkanLembar<void>(
      context,
      judul: t?.title ?? 'Sedang diputar',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (t != null)
            BarisMenu(
              ikon: Icons.playlist_add_rounded,
              label: 'Tambah ke playlist',
              onTap: () {
                Navigator.pop(ctx);
                tampilkanTambahKePlaylist(context, t);
              },
            ),
          if (t != null)
            BarisMenu(
              ikon: Icons.graphic_eq_rounded,
              label: 'Kenali lagu di bagian ini',
              nada: NadaIkon.peach,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FinderScreen(berkas: t, di: _player.position),
                ));
              },
            ),
          ValueListenableBuilder<DateTime?>(
            valueListenable: _player.timerSampai,
            builder: (_, sampai, _) => ValueListenableBuilder<bool>(
              valueListenable: _player.jedaAkhirLagu,
              builder: (_, akhir, _) => BarisMenu(
                ikon: Icons.bedtime_rounded,
                label: 'Timer tidur',
                nada: NadaIkon.lavender,
                keterangan: sampai != null
                    ? 'Jeda jam ${_jam(sampai)}'
                    : (akhir ? 'Jeda di akhir lagu ini' : null),
                onTap: () {
                  Navigator.pop(ctx);
                  _timer();
                },
              ),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _player.kecepatan,
            builder: (_, v, _) => BarisMenu(
              ikon: Icons.speed_rounded,
              label: 'Kecepatan',
              nada: NadaIkon.mint,
              keterangan: _labelKecepatan(v),
              onTap: () {
                Navigator.pop(ctx);
                _kecepatan();
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _jam(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _labelKecepatan(double v) {
    if (v == 1) return 'Normal';
    final s = v.toString().replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return '${s.replaceAll('.', ',')}x';
  }

  static String _labelMenit(int m) => m == 60 ? '1 jam' : '$m menit';

  void _timer() {
    final aktif = _player.timerSampai.value != null || _player.jedaAkhirLagu.value;
    tampilkanLembar<void>(
      context,
      judul: 'Timer tidur',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in const [15, 30, 45, 60])
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              title: Text(_labelMenit(m)),
              onTap: () {
                Navigator.pop(ctx);
                _player.aturTimer(Duration(minutes: m));
                kabari(context, 'Pemutaran dijeda ${_labelMenit(m)} lagi.');
              },
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
            title: const Text('Akhir lagu ini'),
            onTap: () {
              Navigator.pop(ctx);
              _player.aturTimer(null, akhirLagu: true);
              kabari(context, 'Pemutaran dijeda waktu lagu ini selesai.');
            },
          ),
          if (aktif)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              title: Text('Matikan timer', style: TextStyle(color: ctx.mull.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _player.aturTimer(null);
              },
            ),
        ],
      ),
    );
  }

  void _kecepatan() {
    tampilkanLembar<void>(
      context,
      judul: 'Kecepatan',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              title: Text(_labelKecepatan(v)),
              trailing: _player.kecepatan.value == v ? Icon(Icons.check_rounded, color: ctx.mull.accent) : null,
              onTap: () {
                Navigator.pop(ctx);
                _player.aturKecepatan(v);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: _player.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            leadingWidth: 68,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: TombolIkon(
                  ikon: Icons.keyboard_arrow_down_rounded,
                  tooltip: 'Tutup',
                  kaca: true,
                  ukuranIkon: 28,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            title: Text(
              _hal == 0 ? 'Antrean' : (_lirik ? 'Lirik' : 'Sedang diputar'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            centerTitle: true,
            actions: [
              _TombolSuka(player: _player),
              TombolIkon(
                ikon: _lirik ? Icons.album_rounded : Icons.lyrics_rounded,
                tooltip: _lirik ? 'Tampilkan sampul' : 'Tampilkan lirik',
                kaca: true,
                onPressed: () => setState(() => _lirik = !_lirik),
              ),
              const SizedBox(width: 8),
              _TombolUnduh(player: _player),
              TombolIkon(
                ikon: Icons.more_vert_rounded,
                tooltip: 'Opsi lain',
                kaca: true,
                onPressed: item == null ? null : _menu,
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Stack(
            children: [
              // Cahaya pastel ikut warna sampul lagu yang lagi diputar.
              Positioned.fill(child: LatarSampul(sampul: item?.artUri?.toString(), kuat: true)),
              if (item == null)
                const Center(child: Text('Nggak ada yang diputar.'))
              else
                Padding(
                  padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + kToolbarHeight),
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    // Geser ke kanan = antrean, ke kiri = balik ke pemutar.
                    child: PageView(
                      controller: _halaman,
                      onPageChanged: (i) => setState(() => _hal = i),
                      children: [
                        _PanelAntrean(player: _player),
                        _Isi(player: _player, item: item, lirik: _lirik),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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

        final acak = state?.shuffleMode == AudioServiceShuffleMode.all;
        final ulang = state?.repeatMode ?? AudioServiceRepeatMode.none;
        final aktif = cs.primary;
        final pasif = cs.onSurfaceVariant;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: acak ? 'Matikan acak' : 'Acak',
              onPressed: () => player.setShuffleMode(
                acak ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
              ),
              icon: Icon(Icons.shuffle_rounded, color: acak ? aktif : pasif),
            ),
            IconButton(
              iconSize: 36,
              tooltip: 'Sebelumnya',
              onPressed: player.skipToPrevious,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            const SizedBox(width: 8),
            TombolPutar(
              ikon: main ? Icons.pause_rounded : Icons.play_arrow_rounded,
              tooltip: main ? 'Jeda' : 'Putar',
              ukuran: 72,
              onPressed: sibuk ? null : (main ? player.pause : player.play),
              child: sibuk
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            IconButton(
              iconSize: 36,
              tooltip: 'Berikutnya',
              onPressed: player.skipToNext,
              icon: const Icon(Icons.skip_next_rounded),
            ),
            IconButton(
              tooltip: switch (ulang) {
                AudioServiceRepeatMode.none => 'Ulangi semua',
                AudioServiceRepeatMode.one => 'Matikan ulangi',
                _ => 'Ulangi lagu ini',
              },
              onPressed: () => player.setRepeatMode(switch (ulang) {
                AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
                AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
                _ => AudioServiceRepeatMode.one,
              }),
              icon: Icon(
                ulang == AudioServiceRepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                color: ulang == AudioServiceRepeatMode.none ? pasif : aktif,
              ),
            ),
          ],
        );
      },
    );
  }
}


/// Tombol unduh di pojok atas layar Sedang diputar. Cuma muncul kalau
/// lagunya belum ada di HP; selama diunduh jadi indikator muat.
/// (Induknya sudah dibangun ulang tiap lagu ganti, jadi `player.current`
/// selalu lagu yang tampil.)
class _TombolUnduh extends StatelessWidget {
  const _TombolUnduh({required this.player});

  final MullAudioHandler player;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([DownloadService.instance, LibraryService.instance]),
      builder: (context, _) {
        final t = player.current;
        if (t == null) return const SizedBox.shrink();

        final unduhan = DownloadService.instance.antrean.where((u) => !u.video && u.track.id == t.id);
        final sudah = t.isDownloaded ||
            LibraryService.instance.lagu.any((e) => e.localPath != null && e.id == t.id) ||
            unduhan.any((u) => u.status == StatusUnduhan.selesai);
        if (sudah) return const SizedBox.shrink();

        final proses = unduhan.any((u) => u.bisaDibatalkan);
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TombolIkon(
            ikon: Icons.download_rounded,
            tooltip: proses ? 'Sedang diunduh' : 'Unduh lagu',
            kaca: true,
            onPressed: proses ? null : () => unduhLagu(context, t),
            child: proses
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : null,
          ),
        );
      },
    );
  }
}


/// Tombol hati: suka atau batal suka lagu yang sedang diputar.
class _TombolSuka extends StatelessWidget {
  const _TombolSuka({required this.player});

  final MullAudioHandler player;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PlaylistService.instance,
      builder: (context, _) {
        final t = player.current;
        if (t == null) return const SizedBox.shrink();
        final suka = PlaylistService.instance.disukaiLagu(t);
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TombolIkon(
            ikon: suka ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            tooltip: suka ? 'Batal suka' : 'Suka',
            kaca: true,
            onPressed: () async {
              final jadi = await PlaylistService.instance.toggleSuka(t);
              if (context.mounted) {
                kabari(context, jadi ? 'Masuk ke Disukai.' : 'Dihapus dari Disukai.');
              }
            },
            child: suka ? Icon(Icons.favorite_rounded, color: context.mull.accent, size: 22) : null,
          ),
        );
      },
    );
  }
}

/// Antrean putar. Dari playlist = urutan playlist, dari Pustaka = acak.
class _PanelAntrean extends StatefulWidget {
  const _PanelAntrean({required this.player});

  final MullAudioHandler player;

  @override
  State<_PanelAntrean> createState() => _PanelAntreanState();
}

class _PanelAntreanState extends State<_PanelAntrean> {
  static const _tinggi = 68.0;
  late final ScrollController _gulir;

  @override
  void initState() {
    super.initState();
    final pos = widget.player.posisiSekarang;
    // Buka tepat di sekitar lagu yang sedang diputar.
    _gulir = ScrollController(initialScrollOffset: pos <= 1 ? 0 : (pos - 1) * _tinggi);
  }

  @override
  void dispose() {
    _gulir.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<MediaItem?>(
      stream: p.mediaItem,
      builder: (context, _) {
        final lagu = p.urutanPutar;
        final pos = p.posisiSekarang;
        if (lagu.isEmpty) return const Center(child: Text('Antrean kosong.'));
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
                child: Text(
                  '${lagu.length} lagu. Ketuk buat lompat, geser ke kiri buat balik ke pemutar.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _gulir,
                  itemExtent: _tinggi,
                  itemCount: lagu.length,
                  itemBuilder: (context, i) {
                    final t = lagu[i];
                    final aktif = i == pos;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      selected: aktif,
                      selectedTileColor: context.mull.accentSoft,
                      leading: Artwork(url: t.thumbUrl, size: 48, radius: 8),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: aktif ? FontWeight.w700 : FontWeight.w500),
                      ),
                      subtitle: t.artist == null
                          ? null
                          : Text(t.artist!, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: aktif ? Icon(Icons.graphic_eq_rounded, color: context.mull.accent) : null,
                      onTap: () => p.lompatKe(i),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
