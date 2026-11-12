import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/track.dart';
import '../services/library_service.dart';
import '../services/playlist_service.dart';
import '../services/recent_service.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/artwork.dart';
import '../widgets/glass_surface.dart';
import '../widgets/mull_ui.dart';
import '../widgets/quick_tile.dart';
import '../widgets/shelf.dart';
import 'playlist_screen.dart';
import 'settings_screen.dart';

/// Pintasan tetap di petak akses cepat, dipakai kalau playlist belum banyak.
enum Pintasan { pustaka, unduhan, playlist, cari }

/// Beranda. Mekanismenya ikut versi Windows (salam menurut jam, petak akses
/// cepat, tempel tautan, lalu rak kartu); tampilannya ikut Beranda MSA:
/// tanggal kecil + sapaan besar, kolom pil kaca, rak dalam kartu besar.
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

  /// Dipanggil dengan teks dari kolom cari Beranda (kata kunci atau tautan),
  /// atau isi papan klip waktu tombol Tempel ditekan.
  final void Function(String teks)? onTempelTautan;

  static String salam([DateTime? waktu]) {
    final j = (waktu ?? DateTime.now()).hour;
    if (j < 4) return 'Selamat malam';
    if (j < 11) return 'Selamat pagi';
    if (j < 15) return 'Selamat siang';
    if (j < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  static const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  static const _bulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  /// "Kamis, 12 November". Ditulis sendiri biar nggak perlu paket intl.
  static String tanggal([DateTime? waktu]) {
    final d = waktu ?? DateTime.now();
    return '${_hari[d.weekday - 1]}, ${d.day} ${_bulan[d.month - 1]}';
  }

  Future<void> _tempel(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final teks = data?.text?.trim() ?? '';
    if (!context.mounted) return;

    if (teks.isEmpty || !teks.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Papan klip kamu belum berisi tautan. Salin dulu, lalu ketuk lagi.')),
      );
      return;
    }
    onTempelTautan?.call(teks);
  }

  void _bukaPlaylist(BuildContext context, Playlist p) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: p, onPlay: onPlay)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = LibraryService.instance;
    final playlists = PlaylistService.instance;
    final recent = RecentService.instance;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: Listenable.merge([lib, playlists, recent]),
        builder: (context, _) {
          final baruDiputar = recent.daftar.take(12).toList();
          // Cuma unduhan Mull; lagu lain di HP bukan "baru diunduh".
          final baruDiunduh = lib.laguMull.take(12).toList();
          final daftarPlaylist = playlists.daftar;

          final kosong = baruDiputar.isEmpty && baruDiunduh.isEmpty && daftarPlaylist.isEmpty;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              MullUkuran.tepi,
              MediaQuery.paddingOf(context).top + 18,
              MullUkuran.tepi,
              RuangBawah.of(context) + 16,
            ),
            children: [
              _Kepala(
                onPengaturan: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const SizedBox(height: 20),
              _KolomCari(
                onKirim: (teks) => onTempelTautan?.call(teks),
                onTempel: () => _tempel(context),
              ),
              const SizedBox(height: 20),
              _PetakCepat(
                playlists: daftarPlaylist,
                onBukaPlaylist: (p) => _bukaPlaylist(context, p),
                onPintasan: (p) => switch (p) {
                  Pintasan.pustaka => onGoLibrary?.call(),
                  Pintasan.unduhan => onGoDownloads?.call(),
                  Pintasan.playlist => onGoLibrary?.call(),
                  Pintasan.cari => onGoSearch?.call(),
                },
              ),
              if (kosong) _Sambutan(onGoSearch: onGoSearch),
              Shelf(
                title: 'Baru diputar',
                items: baruDiputar,
                onTapItem: (t) => onPlay?.call(baruDiputar, baruDiputar.indexOf(t)),
              ),
              Shelf(
                title: 'Baru diunduh',
                items: baruDiunduh,
                onSeeAll: onGoLibrary,
                onTapItem: (t) => onPlay?.call(baruDiunduh, baruDiunduh.indexOf(t)),
              ),
              _RakPlaylist(
                playlists: daftarPlaylist.take(12).toList(),
                onLihatSemua: onGoLibrary,
                onBuka: (p) => _bukaPlaylist(context, p),
              ),
              if (!kosong)
                const PetunjukAkhir('Lagu yang kamu putar dan unduh bakal muncul di sini.'),
            ],
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
    final c = context.mull;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HomeScreen.tanggal(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  HomeScreen.salam(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                ),
              ],
            ),
          ),
          TombolIkon(
            ikon: Icons.settings_rounded,
            tooltip: 'Pengaturan',
            kaca: true,
            ukuran: 48,
            onPressed: onPengaturan,
          ),
        ],
      ),
    );
  }
}

/// Kolom pil kaca "Cari atau tempel tautan" (sepadan "Tulis catatan" di MSA).
class _KolomCari extends StatefulWidget {
  const _KolomCari({required this.onKirim, required this.onTempel});

  final ValueChanged<String> onKirim;
  final VoidCallback onTempel;

  @override
  State<_KolomCari> createState() => _KolomCariState();
}

class _KolomCariState extends State<_KolomCari> {
  final _teks = TextEditingController();

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  void _kirim(String s) {
    final q = s.trim();
    if (q.isEmpty) return;
    _teks.clear();
    FocusScope.of(context).unfocus();
    widget.onKirim(q);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    return GlassSurface(
      radius: 28,
      height: 58,
      padding: const EdgeInsets.only(left: 18, right: 7),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 22, color: c.textSubtle),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _teks,
              textInputAction: TextInputAction.search,
              onSubmitted: _kirim,
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: c.text),
              decoration: InputDecoration(
                hintText: 'Cari atau tempel tautan',
                hintStyle: TextStyle(fontSize: 15.5, color: c.textSubtle),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          TombolPutar(
            ikon: Icons.content_paste_rounded,
            tooltip: 'Tempel tautan',
            ukuran: 44,
            onPressed: widget.onTempel,
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
        nada: NadaIkon.lavender,
        onTap: () => onBukaPlaylist(p),
      ));
    }

    // Warna kotak ikon ala MSA: tiap pintasan punya nada pastel sendiri.
    const tetap = [
      (Pintasan.pustaka, 'Pustaka', Icons.album_rounded, NadaIkon.aksen),
      (Pintasan.unduhan, 'Unduhan', Icons.arrow_circle_down_rounded, NadaIkon.mint),
      (Pintasan.playlist, 'Playlist', Icons.queue_music_rounded, NadaIkon.lavender),
      (Pintasan.cari, 'Cari lagu', Icons.search_rounded, NadaIkon.peach),
    ];
    for (final (id, label, ikon, nada) in tetap) {
      if (petak.length >= 6) break;
      petak.add(QuickTile(label: label, icon: ikon, nada: nada, onTap: () => onPintasan(id)));
    }

    // mainAxisExtent, bukan childAspectRatio: tingginya harus tetap di lebar
    // layar mana pun. Pakai rasio, tingginya ikut lebar layar dan isinya
    // meluber di HP sempit.
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // padding wajib eksplisit: scroll view bersarang yang padding-nya null
      // otomatis memakai MediaQuery.padding, jadi muncul celah sebesar inset
      // navigasi bawah (kejadian di Infinix).
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 62,
      ),
      children: petak,
    );
  }
}

class _Sambutan extends StatelessWidget {
  const _Sambutan({this.onGoSearch});

  final VoidCallback? onGoSearch;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KartuMull(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const KotakIkon(ikon: Icons.music_note_rounded, nada: NadaIkon.peach, ukuran: 42),
            const SizedBox(height: 14),
            const Text('Mulai dari sini', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Cari lagu atau tempel tautan buat diputar dan diunduh. '
              'Yang kamu putar bakal muncul di halaman ini.',
              style: TextStyle(fontSize: 14, height: 1.45, color: c.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onGoSearch,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text('Cari lagu'),
            ),
          ],
        ),
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
    final c = context.mull;

    return RakKartu(
      judul: 'Playlist kamu',
      jumlah: playlists.length,
      onLihatSemua: onLihatSemua,
      itemBuilder: (context, i) {
        final p = playlists[i];
        return SizedBox(
          width: 132,
          child: InkWell(
            onTap: () => onBuka(p),
            borderRadius: BorderRadius.circular(MullUkuran.sampul),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 132, height: 132, child: _SampulPlaylistKotak(playlist: p)),
                const SizedBox(height: 10),
                Text(
                  p.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  p.lagu.isEmpty ? 'Masih kosong' : '${p.lagu.length} lagu',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SampulPlaylistKotak extends StatelessWidget {
  const _SampulPlaylistKotak({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final sampul = playlist.lagu
        .map((t) => t.thumbUrl)
        .where((u) => u != null && u.isNotEmpty)
        .cast<String>()
        .take(4)
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(MullUkuran.sampul),
      child: switch (sampul.length) {
        0 => ColoredBox(
            color: c.violetSoft,
            child: Icon(Icons.queue_music_rounded, color: c.violet, size: 30),
          ),
        1 || 2 || 3 => GambarSampul(url: sampul.first, cadangan: ColoredBox(color: c.chipBg)),
        _ => GridView.count(
            crossAxisCount: 2,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final u in sampul) GambarSampul(url: u, cadangan: ColoredBox(color: c.chipBg)),
            ],
          ),
      },
    );
  }
}
