import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/library_service.dart';
import '../services/playlist_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/empty_state.dart';
import '../widgets/media_cards.dart';
import '../widgets/segmented_pill.dart';
import '../widgets/track_tile.dart';
import 'playlist_screen.dart';
import 'video_screen.dart';

enum _Urut { terbaru, judul, artis }

/// Pustaka: berkas yang sudah ada di HP, plus playlist lokal.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.onGoSearch, this.onPlay, this.onPlayAcak});

  final VoidCallback? onGoSearch;
  final void Function(List<Track> daftar, int indeks)? onPlay;
  final void Function(List<Track> daftar)? onPlayAcak;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _lib = LibraryService.instance;
  int _tab = 0;
  _Urut _urut = _Urut.terbaru;

  @override
  void initState() {
    super.initState();
    // Ditunda sampai frame pertama selesai: `muat()` langsung memberi tahu
    // pendengarnya, dan di IndexedStack layar ini dibangun bersamaan dengan
    // widget lain yang ikut mendengarkan LibraryService.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _lib.muat();
    });
  }

  /// `terbaru` itu urutan asli dari MediaStore (DATE_ADDED menurun).
  List<Track> _urutkan(List<Track> asli) {
    if (_urut == _Urut.terbaru) return asli;
    final salinan = [...asli];
    salinan.sort((a, b) => switch (_urut) {
          _Urut.judul => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          _Urut.artis => (a.artist ?? '~').toLowerCase().compareTo((b.artist ?? '~').toLowerCase()),
          _Urut.terbaru => 0,
        });
    return salinan;
  }

  Future<void> _hapus(Track t) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus berkas?'),
        content: Text('"${t.title}" bakal dihapus permanen dari HP kamu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (yakin != true) return;

    final ok = await _lib.hapus(t);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Berkas dihapus.' : 'Nggak bisa menghapus berkas itu.')),
    );
  }

  void _menuBerkas(Track t) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Tambah ke playlist'),
              onTap: () {
                Navigator.pop(ctx);
                tampilkanTambahKePlaylist(context, t);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
              title: Text(
                'Hapus dari HP',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _hapus(t);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _lib,
        builder: (context, _) {
          final lagu = _urutkan(_lib.lagu);
          final video = _urutkan(_lib.video);

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Kepala(
                  jumlahLagu: _lib.lagu.length,
                  jumlahVideo: _lib.video.length,
                  memuat: _lib.memuat,
                  onMuatUlang: _lib.muat,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SegmentedPill(
                    labels: const ['Lagu', 'Video', 'Playlist'],
                    index: _tab,
                    onPilih: (i) => setState(() => _tab = i),
                  ),
                ),
                Expanded(child: _isi(lagu, video)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _isi(List<Track> lagu, List<Track> video) {
    if (_lib.memuat && _lib.kosong) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_lib.galat != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Pustaka gagal dibaca',
        message: _lib.galat,
        action: FilledButton(onPressed: _lib.muat, child: const Text('Coba lagi')),
      );
    }

    return switch (_tab) {
      0 => _TabLagu(
          lagu: lagu,
          urut: _urut,
          onUrut: (u) => setState(() => _urut = u),
          onPlay: widget.onPlay,
          onPlayAcak: widget.onPlayAcak,
          onMenu: _menuBerkas,
          onGoSearch: widget.onGoSearch,
        ),
      1 => _TabVideo(video: video, onMenu: _menuBerkas),
      _ => const _TabPlaylist(),
    };
  }
}

/// Judul besar + ringkasan isi pustaka.
class _Kepala extends StatelessWidget {
  const _Kepala({
    required this.jumlahLagu,
    required this.jumlahVideo,
    required this.memuat,
    required this.onMuatUlang,
  });

  final int jumlahLagu;
  final int jumlahVideo;
  final bool memuat;
  final VoidCallback onMuatUlang;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bagian = <String>[
      if (jumlahLagu > 0) '$jumlahLagu lagu',
      if (jumlahVideo > 0) '$jumlahVideo video',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pustaka',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  bagian.isEmpty ? 'Semua yang ada di HP kamu' : bagian.join('  ·  '),
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: memuat ? null : onMuatUlang,
            icon: memuat
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _TabLagu extends StatelessWidget {
  const _TabLagu({
    required this.lagu,
    required this.urut,
    required this.onUrut,
    required this.onMenu,
    this.onPlay,
    this.onPlayAcak,
    this.onGoSearch,
  });

  final List<Track> lagu;
  final _Urut urut;
  final ValueChanged<_Urut> onUrut;
  final void Function(Track) onMenu;
  final void Function(List<Track>, int)? onPlay;
  final void Function(List<Track>)? onPlayAcak;
  final VoidCallback? onGoSearch;

  @override
  Widget build(BuildContext context) {
    if (lagu.isEmpty) {
      return EmptyState(
        icon: Icons.music_note_rounded,
        title: 'Belum ada lagu',
        message: 'Lagu yang kamu unduh disimpan di Music/Mull dan bisa diputar tanpa internet.',
        action: FilledButton(onPressed: onGoSearch, child: const Text('Cari lagu')),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: RuangBawah.of(context) + 16),
      itemCount: lagu.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _BarisAksi(
            urut: urut,
            onUrut: onUrut,
            onPutar: onPlay == null ? null : () => onPlay!(lagu, 0),
            onAcak: onPlayAcak == null ? null : () => onPlayAcak!(lagu),
          );
        }
        final t = lagu[i - 1];
        return TrackTile(
          track: t,
          onTap: onPlay == null ? null : () => onPlay!(lagu, i - 1),
          onMenu: () => onMenu(t),
        );
      },
    );
  }
}

/// Putar semua, Acak, dan pilihan urutan.
class _BarisAksi extends StatelessWidget {
  const _BarisAksi({
    required this.urut,
    required this.onUrut,
    this.onPutar,
    this.onAcak,
  });

  final _Urut urut;
  final ValueChanged<_Urut> onUrut;
  final VoidCallback? onPutar;
  final VoidCallback? onAcak;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: onPutar,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Putar'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onAcak,
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: const Text('Acak'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              side: BorderSide(color: cs.outlineVariant),
            ),
          ),
          const Spacer(),
          PopupMenuButton<_Urut>(
            tooltip: 'Urutkan',
            initialValue: urut,
            onSelected: onUrut,
            icon: const Icon(Icons.swap_vert_rounded, size: 22),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Urut.terbaru, child: Text('Terbaru')),
              PopupMenuItem(value: _Urut.judul, child: Text('Judul')),
              PopupMenuItem(value: _Urut.artis, child: Text('Artis')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabVideo extends StatelessWidget {
  const _TabVideo({required this.video, required this.onMenu});

  final List<Track> video;
  final void Function(Track) onMenu;

  @override
  Widget build(BuildContext context) {
    if (video.isEmpty) {
      return const EmptyState(
        icon: Icons.movie_rounded,
        title: 'Belum ada video',
        message: 'Video yang kamu unduh disimpan di Movies/Mull.',
      );
    }

    // Satu kolom di HP sempit, dua kolom begitu muat. Kartu 16:9 butuh lebar;
    // dipaksa dua kolom di layar kecil malah jadi kekecilan.
    final lebar = MediaQuery.sizeOf(context).width;
    final kolom = lebar >= 600 ? 2 : 1;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, RuangBawah.of(context) + 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: kolom,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        // 16:9 gambar + ruang buat dua baris judul.
        childAspectRatio: kolom == 1 ? 16 / 11.6 : 16 / 12.4,
      ),
      itemCount: video.length,
      itemBuilder: (context, i) => VideoCard(
        track: video[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VideoScreen(track: video[i])),
        ),
        onMenu: () => onMenu(video[i]),
      ),
    );
  }
}

class _TabPlaylist extends StatelessWidget {
  const _TabPlaylist();

  @override
  Widget build(BuildContext context) {
    final service = PlaylistService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final daftar = service.daftar;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(16, 0, 16, RuangBawah.of(context) + 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 18,
            crossAxisSpacing: 14,
            // Sampul kotak + dua baris teks di bawahnya.
            childAspectRatio: 1 / 1.34,
          ),
          itemCount: daftar.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return PlaylistCardBaru(
                onTap: () async {
                  final nama = await mintaNamaPlaylist(context);
                  if (nama != null) await service.buat(nama);
                },
              );
            }
            final p = daftar[i - 1];
            return PlaylistCard(
              playlist: p,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: p)),
              ),
            );
          },
        );
      },
    );
  }
}
