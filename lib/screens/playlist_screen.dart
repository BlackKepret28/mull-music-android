import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/playlist_service.dart';
import '../widgets/artwork.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/mull_ui.dart';
import '../widgets/track_tile.dart';

/// Empat sampul pertama disusun jadi mozaik kecil.
class _SampulPlaylist extends StatelessWidget {
  const _SampulPlaylist({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final sampul = playlist.lagu
        .map((t) => t.thumbUrl)
        .where((u) => u != null && u.isNotEmpty)
        .take(4)
        .toList();

    if (sampul.length < 4) {
      return Artwork(
        url: sampul.isEmpty ? null : sampul.first,
        size: 48,
        radius: 12,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 48,
        height: 48,
        child: GridView.count(
          crossAxisCount: 2,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final u in sampul) Artwork(url: u, size: 24, radius: 0),
          ],
        ),
      ),
    );
  }
}

/// Isi satu playlist.
class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.playlist, this.onPlay});

  final Playlist playlist;
  final void Function(List<Track> daftar, int indeks)? onPlay;

  Future<void> _gantiNama(BuildContext context) async {
    final nama = await mintaNamaPlaylist(
      context,
      awal: playlist.nama,
      judul: 'Ganti nama',
    );
    if (nama == null) return;
    await PlaylistService.instance.gantiNama(playlist, nama);
  }

  Future<void> _hapus(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus playlist?'),
        content: Text(
          '"${playlist.nama}" bakal dihapus. Berkas lagunya nggak ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true || !context.mounted) return;
    await PlaylistService.instance.hapus(playlist);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PlaylistService.instance,
      builder: (context, _) {
        final lagu = playlist.lagu;
        final c = context.mull;

        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: LatarMull(halus: true)),
              HalamanKaca(
                header: HeaderKaca(
                  judul: playlist.nama,
                  subjudul: lagu.isEmpty
                      ? 'Masih kosong'
                      : '${lagu.length} lagu  ·  ${formatDuration(playlist.totalDurasi)}',
                  depan: TombolIkon(
                    ikon: Icons.arrow_back_rounded,
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  aksi: [
                    PopupMenuButton<String>(
                      tooltip: 'Opsi lain',
                      icon: Icon(Icons.more_vert_rounded, color: c.icon),
                      onSelected: (v) => switch (v) {
                        'nama' => _gantiNama(context),
                        'hapus' => _hapus(context),
                        _ => null,
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'nama', child: Text('Ganti nama')),
                        PopupMenuItem(
                          value: 'hapus',
                          child: Text('Hapus playlist'),
                        ),
                      ],
                    ),
                  ],
                  bawah: lagu.isEmpty
                      ? null
                      : Row(
                          children: [
                            FilledButton.icon(
                              onPressed: onPlay == null
                                  ? null
                                  : () => onPlay!(lagu, 0),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 22,
                              ),
                              label: const Text('Putar semua'),
                            ),
                          ],
                        ),
                ),
                isi: (context, padding) => lagu.isEmpty
                    ? Padding(
                        padding: padding,
                        child: const EmptyState(
                          icon: Icons.queue_music_rounded,
                          title: 'Playlist ini masih kosong',
                          message: 'Tambahkan lagu lewat titik tiga di hasil Cari atau di Pustaka.',
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: padding,
                        itemCount: lagu.length,
                        footer: const PetunjukAkhir(
                          'Tahan lagu buat ganti urutan, geser ke kiri buat buang dari playlist.',
                        ),
                        // onReorderItem (bukan onReorder yang sudah usang)
                        // sudah membetulkan indeks tujuannya sendiri.
                        onReorderItem: (dari, ke) => PlaylistService.instance
                            .pindahLagu(playlist, dari, ke),
                        itemBuilder: (context, i) => Dismissible(
                          key: ValueKey('${playlist.id}/${lagu[i].id}'),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => PlaylistService.instance
                              .hapusLagu(playlist, lagu[i]),
                          background: Container(
                            alignment: Alignment.centerRight,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 5,
                            ),
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: c.dangerSoft,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.remove_circle_outline_rounded,
                              color: c.danger,
                            ),
                          ),
                          child: TrackTile(
                            track: lagu[i],
                            onTap: onPlay == null
                                ? null
                                : () => onPlay!(lagu, i),
                          ),
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

/// Dialog nama playlist. Balikin null kalau dibatalkan.
Future<String?> mintaNamaPlaylist(
  BuildContext context, {
  String awal = '',
  String judul = 'Playlist baru',
}) {
  final c = TextEditingController(text: awal);

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(judul),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nama playlist'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, c.text),
          child: const Text('Simpan'),
        ),
      ],
    ),
  ).then((v) {
    c.dispose();
    final s = v?.trim();
    return (s == null || s.isEmpty) ? null : s;
  });
}

/// Lembar pilihan "Tambah ke playlist".
Future<void> tampilkanTambahKePlaylist(BuildContext context, Track t) async {
  final service = PlaylistService.instance;
  if (!service.sudahMuat) await service.muat();
  if (!context.mounted) return;

  await tampilkanLembar<void>(
    context,
    judul: 'Tambah ke playlist',
    builder: (ctx) => ListenableBuilder(
      listenable: service,
      builder: (ctx, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
            leading: const KotakIkon(ikon: Icons.add_rounded, ukuran: 48),
            title: const Text('Playlist baru'),
            onTap: () async {
              final nama = await mintaNamaPlaylist(ctx);
              if (nama == null) return;
              final p = await service.buat(nama);
              await service.tambahLagu(p, [t]);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          for (final p in service.daftar)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              leading: _SampulPlaylist(playlist: p),
              title: Text(p.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${p.lagu.length} lagu'),
              onTap: () async {
                final n = await service.tambahLagu(p, [t]);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      n > 0
                          ? 'Ditambahkan ke "${p.nama}".'
                          : 'Lagu itu sudah ada di sana.',
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}
