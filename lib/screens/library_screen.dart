import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/library_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/empty_state.dart';
import '../widgets/track_tile.dart';

/// Pustaka: lagu dan video yang sudah ada berkasnya di HP, plus playlist lokal.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.onGoSearch, this.onPlay});

  final VoidCallback? onGoSearch;
  final void Function(List<Track> daftar, int indeks)? onPlay;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _lib = LibraryService.instance;

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pustaka'),
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              icon: const Icon(Icons.refresh),
              onPressed: _lib.muat,
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            indicatorColor: cs.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: cs.outlineVariant,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Lagu'),
              Tab(text: 'Video'),
              Tab(text: 'Playlist'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: _lib,
          builder: (context, _) {
            if (_lib.memuat && _lib.kosong) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
            }
            if (_lib.galat != null) {
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Pustaka gagal dibaca',
                message: _lib.galat,
                action: FilledButton(onPressed: _lib.muat, child: const Text('Coba lagi')),
              );
            }

            return TabBarView(
              children: [
                _Daftar(
                  items: _lib.lagu,
                  kosong: EmptyState(
                    icon: Icons.music_note_outlined,
                    title: 'Belum ada lagu',
                    message: 'Lagu yang kamu unduh disimpan di Music/Mull dan '
                        'bisa diputar tanpa internet.',
                    action: FilledButton(
                      onPressed: widget.onGoSearch,
                      child: const Text('Cari lagu'),
                    ),
                  ),
                  onPlay: widget.onPlay,
                  onHapus: _hapus,
                ),
                _Daftar(
                  items: _lib.video,
                  kosong: const EmptyState(
                    icon: Icons.movie_outlined,
                    title: 'Belum ada video',
                    message: 'Video yang kamu unduh disimpan di Movies/Mull.',
                  ),
                  onPlay: widget.onPlay,
                  onHapus: _hapus,
                ),
                const EmptyState(
                  icon: Icons.queue_music_outlined,
                  title: 'Belum ada playlist',
                  message: 'Playlist yang kamu bikin sendiri muncul di sini.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Daftar extends StatelessWidget {
  const _Daftar({
    required this.items,
    required this.kosong,
    this.onPlay,
    this.onHapus,
  });

  final List<Track> items;
  final Widget kosong;
  final void Function(List<Track> daftar, int indeks)? onPlay;
  final void Function(Track t)? onHapus;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return kosong;

    return ListView.builder(
      padding: EdgeInsets.only(top: 4, bottom: RuangBawah.of(context) + 16),
      itemCount: items.length,
      itemBuilder: (_, i) => Dismissible(
        key: ValueKey(items[i].localPath ?? items[i].id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          onHapus?.call(items[i]);
          // Daftarnya dibangun ulang dari MediaStore, bukan dari animasi geser.
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.14),
          child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
        ),
        child: TrackTile(
          track: items[i],
          onTap: onPlay == null ? null : () => onPlay!(items, i),
        ),
      ),
    );
  }
}
