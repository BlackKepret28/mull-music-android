import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/playlist_service.dart';
import '../widgets/artwork.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/empty_state.dart';
import '../widgets/track_tile.dart';

/// Isi tab Playlist di Pustaka.
class PlaylistTab extends StatelessWidget {
  const PlaylistTab({super.key, this.onPlay});

  final void Function(List<Track> daftar, int indeks)? onPlay;

  Future<void> _buat(BuildContext context) async {
    final nama = await mintaNamaPlaylist(context);
    if (nama == null) return;
    await PlaylistService.instance.buat(nama);
  }

  @override
  Widget build(BuildContext context) {
    final service = PlaylistService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final daftar = service.daftar;

        if (daftar.isEmpty) {
          return EmptyState(
            icon: Icons.queue_music_outlined,
            title: 'Belum ada playlist',
            message: 'Bikin playlist buat ngumpulin lagu favorit kamu.',
            action: FilledButton(
              onPressed: () => _buat(context),
              child: const Text('Bikin playlist'),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(top: 4, bottom: RuangBawah.of(context) + 16),
          itemCount: daftar.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Bikin playlist baru'),
                onTap: () => _buat(context),
              );
            }

            final p = daftar[i - 1];
            return ListTile(
              leading: _SampulPlaylist(playlist: p),
              title: Text(p.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                p.lagu.isEmpty
                    ? 'Masih kosong'
                    : '${p.lagu.length} lagu  ·  ${formatDuration(p.totalDurasi)}',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlist: p, onPlay: onPlay),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

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
      return Artwork(url: sampul.isEmpty ? null : sampul.first, size: 48, radius: 6);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 48,
        height: 48,
        child: GridView.count(
          crossAxisCount: 2,
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
    final nama = await mintaNamaPlaylist(context, awal: playlist.nama, judul: 'Ganti nama');
    if (nama == null) return;
    await PlaylistService.instance.gantiNama(playlist, nama);
  }

  Future<void> _hapus(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus playlist?'),
        content: Text('"${playlist.nama}" bakal dihapus. Berkas lagunya nggak ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
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

        return Scaffold(
          appBar: AppBar(
            title: Text(playlist.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) => switch (v) {
                  'nama' => _gantiNama(context),
                  'hapus' => _hapus(context),
                  _ => null,
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'nama', child: Text('Ganti nama')),
                  PopupMenuItem(value: 'hapus', child: Text('Hapus playlist')),
                ],
              ),
            ],
          ),
          body: lagu.isEmpty
              ? const EmptyState(
                  icon: Icons.music_note_outlined,
                  title: 'Playlist ini masih kosong',
                  message: 'Tambahkan lagu lewat tombol titik tiga di hasil Cari '
                      'atau di Pustaka.',
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          FilledButton.icon(
                            onPressed: onPlay == null ? null : () => onPlay!(lagu, 0),
                            icon: const Icon(Icons.play_arrow, size: 20),
                            label: const Text('Putar semua'),
                          ),
                          const Spacer(),
                          Text(
                            '${lagu.length} lagu  ·  ${formatDuration(playlist.totalDurasi)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: EdgeInsets.only(bottom: RuangBawah.of(context) + 16),
                        itemCount: lagu.length,
                        // onReorderItem (bukan onReorder yang sudah usang)
                        // sudah membetulkan indeks tujuannya sendiri.
                        onReorderItem: (dari, ke) =>
                            PlaylistService.instance.pindahLagu(playlist, dari, ke),
                        itemBuilder: (context, i) => Dismissible(
                          key: ValueKey('${playlist.id}/${lagu[i].id}'),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) =>
                              PlaylistService.instance.hapusLagu(playlist, lagu[i]),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.14),
                            child: Icon(
                              Icons.remove_circle_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          child: TrackTile(
                            track: lagu[i],
                            onTap: onPlay == null ? null : () => onPlay!(lagu, i),
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
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Simpan')),
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

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => ListenableBuilder(
      listenable: service,
      builder: (ctx, _) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Tambah ke playlist',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
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
                        n > 0 ? 'Ditambahkan ke "${p.nama}".' : 'Lagu itu sudah ada di sana.',
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}
