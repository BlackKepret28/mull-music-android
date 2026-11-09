import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/track.dart';
import '../services/library_service.dart';
import '../services/playlist_service.dart';
import '../services/recent_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/quick_tile.dart';
import '../widgets/shelf.dart';
import 'playlist_screen.dart';
import 'settings_screen.dart';

/// Pintasan tetap di petak akses cepat, dipakai kalau playlist belum banyak.
enum Pintasan { pustaka, unduhan, playlist, cari }

/// Beranda. Mekanismenya ikut versi Windows (salam menurut jam, petak akses
/// cepat, kartu tempel tautan, lalu rak kartu), tapi tata letaknya diatur
/// ulang buat layar HP: petaknya dua kolom, raknya bisa digeser jempol, dan
/// semuanya muat tanpa perlu zoom.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onPlay,
    this.onGoSearch,
    this.onGoLibrary,
    this.onGoDownloads,
    this.onTempelTautan,
  });

  final void Function(List<Track> daftar, int indeks)? onPlay;
  final VoidCallback? onGoSearch;
  final VoidCallback? onGoLibrary;
  final VoidCallback? onGoDownloads;

  /// Dipanggil dengan isi papan klip waktu tombol Tempel ditekan.
  final void Function(String tautan)? onTempelTautan;

  static String salam() {
    final j = DateTime.now().hour;
    if (j < 4) return 'Selamat malam';
    if (j < 11) return 'Selamat pagi';
    if (j < 15) return 'Selamat siang';
    if (j < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  Future<void> _tempel(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final teks = data?.text?.trim() ?? '';
    if (!context.mounted) return;

    if (teks.isEmpty || !teks.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Papan klip kamu nggak berisi tautan.')),
      );
      return;
    }
    onTempelTautan?.call(teks);
  }

  @override
  Widget build(BuildContext context) {
    final lib = LibraryService.instance;
    final playlists = PlaylistService.instance;
    final recent = RecentService.instance;

    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([lib, playlists, recent]),
        builder: (context, _) {
          final baruDiputar = recent.daftar;
          final baruDiunduh = lib.lagu;
          final daftarPlaylist = playlists.daftar;

          final kosong =
              baruDiputar.isEmpty && baruDiunduh.isEmpty && daftarPlaylist.isEmpty;

          return SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.only(bottom: RuangBawah.of(context) + 16),
              children: [
                _Kepala(onPengaturan: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    )),
                _PetakCepat(
                  playlists: daftarPlaylist,
                  onBukaPlaylist: (p) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(playlist: p, onPlay: onPlay),
                    ),
                  ),
                  onPintasan: (p) => switch (p) {
                    Pintasan.pustaka => onGoLibrary?.call(),
                    Pintasan.unduhan => onGoDownloads?.call(),
                    Pintasan.playlist => onGoLibrary?.call(),
                    Pintasan.cari => onGoSearch?.call(),
                  },
                ),
                _KartuTempel(onTempel: () => _tempel(context)),
                if (kosong) _Sambutan(onGoSearch: onGoSearch),
                Shelf(
                  title: 'Baru diputar',
                  items: baruDiputar.take(12).toList(),
                  onTapItem: (t) {
                    final daftar = baruDiputar.take(12).toList();
                    onPlay?.call(daftar, daftar.indexOf(t));
                  },
                ),
                Shelf(
                  title: 'Baru diunduh',
                  items: baruDiunduh.take(12).toList(),
                  onSeeAll: onGoLibrary,
                  onTapItem: (t) {
                    final daftar = baruDiunduh.take(12).toList();
                    onPlay?.call(daftar, daftar.indexOf(t));
                  },
                ),
                if (daftarPlaylist.isNotEmpty)
                  _RakPlaylist(
                    playlists: daftarPlaylist,
                    onLihatSemua: onGoLibrary,
                    onBuka: (p) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(playlist: p, onPlay: onPlay),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Kepala extends StatelessWidget {
  const _Kepala({required this.onPengaturan});

  final VoidCallback onPengaturan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              HomeScreen.salam(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: onPengaturan,
          ),
        ],
      ),
    );
  }
}

/// Dua kolom petak pendek: playlist terbaru dulu, sisanya pintasan tetap.
class _PetakCepat extends StatelessWidget {
  const _PetakCepat({
    required this.playlists,
    required this.onBukaPlaylist,
    required this.onPintasan,
  });

  final List<Playlist> playlists;
  final void Function(Playlist) onBukaPlaylist;
  final void Function(Pintasan) onPintasan;

  @override
  Widget build(BuildContext context) {
    // Maksimal enam petak: lebih dari itu Beranda jadi penuh dan raknya
    // kedorong terlalu ke bawah di layar HP.
    final petak = <Widget>[];

    for (final p in playlists.take(4)) {
      final sampul = p.lagu
          .map((t) => t.thumbUrl)
          .where((u) => u != null && u.isNotEmpty)
          .cast<String>()
          .take(4)
          .toList();
      petak.add(QuickTile(
        label: p.nama,
        covers: sampul.length >= 4 ? sampul : null,
        coverUrl: sampul.isEmpty ? null : sampul.first,
        icon: Icons.queue_music_rounded,
        onTap: () => onBukaPlaylist(p),
      ));
    }

    const tetap = [
      (Pintasan.pustaka, 'Pustaka', Icons.album_rounded),
      (Pintasan.unduhan, 'Unduhan', Icons.arrow_circle_down_rounded),
      (Pintasan.playlist, 'Playlist', Icons.queue_music_rounded),
      (Pintasan.cari, 'Cari lagu', Icons.search_rounded),
    ];
    for (final (id, label, ikon) in tetap) {
      if (petak.length >= 6) break;
      petak.add(QuickTile(label: label, icon: ikon, onTap: () => onPintasan(id)));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // mainAxisExtent, bukan childAspectRatio: tingginya harus pas 52
      // (setinggi sampulnya) di lebar layar mana pun. Pakai rasio, tingginya
      // ikut lebar layar dan isinya meluber di HP sempit.
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 52,
        ),
        children: petak,
      ),
    );
  }
}

/// Kartu "tempel tautan", sepadan dengan `hm-paste` versi Windows.
class _KartuTempel extends StatelessWidget {
  const _KartuTempel({required this.onTempel});

  final VoidCallback onTempel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Material(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTempel,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.link_rounded, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Putar dari tautan',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Salin tautan YouTube, lalu ketuk di sini.',
                        style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.content_paste_rounded, color: cs.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sambutan extends StatelessWidget {
  const _Sambutan({this.onGoSearch});

  final VoidCallback? onGoSearch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mulai dari sini',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Cari lagu atau tempel tautan buat diputar dan diunduh. '
            'Yang kamu putar bakal muncul di halaman ini.',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onGoSearch, child: const Text('Cari lagu')),
        ],
      ),
    );
  }
}

class _RakPlaylist extends StatelessWidget {
  const _RakPlaylist({
    required this.playlists,
    required this.onBuka,
    this.onLihatSemua,
  });

  final List<Playlist> playlists;
  final void Function(Playlist) onBuka;
  final VoidCallback? onLihatSemua;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8, top: 20, bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text('Playlist kamu', style: Theme.of(context).textTheme.titleMedium),
              ),
              if (onLihatSemua != null)
                TextButton(onPressed: onLihatSemua, child: const Text('Lihat semua')),
            ],
          ),
        ),
        SizedBox(
          height: 186,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: playlists.length > 12 ? 12 : playlists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final p = playlists[i];
              return SizedBox(
                width: 132,
                child: InkWell(
                  onTap: () => onBuka(p),
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 132,
                        height: 132,
                        child: _SampulPlaylistKotak(playlist: p),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        p.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.lagu.isEmpty ? 'Masih kosong' : '${p.lagu.length} lagu',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SampulPlaylistKotak extends StatelessWidget {
  const _SampulPlaylistKotak({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sampul = playlist.lagu
        .map((t) => t.thumbUrl)
        .where((u) => u != null && u.isNotEmpty)
        .cast<String>()
        .take(4)
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: switch (sampul.length) {
        0 => ColoredBox(
            color: cs.primary.withValues(alpha: 0.12),
            child: Icon(Icons.queue_music_rounded, color: cs.primary, size: 28),
          ),
        1 || 2 || 3 => Image.network(
            sampul.first,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => ColoredBox(color: cs.surfaceContainer),
          ),
        _ => GridView.count(
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final u in sampul)
                Image.network(
                  u,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => ColoredBox(color: cs.surfaceContainer),
                ),
            ],
          ),
      },
    );
  }
}
