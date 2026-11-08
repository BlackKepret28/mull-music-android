import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

/// Pustaka: lagu dan video yang ada di HP, plus playlist lokal.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.onGoSearch});

  final VoidCallback? onGoSearch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pustaka'),
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
        body: TabBarView(
          children: [
            EmptyState(
              icon: Icons.music_note_outlined,
              title: 'Belum ada lagu',
              message: 'Lagu yang kamu unduh muncul di sini, bisa diputar tanpa internet.',
              action: FilledButton(onPressed: onGoSearch, child: const Text('Cari lagu')),
            ),
            const EmptyState(
              icon: Icons.movie_outlined,
              title: 'Belum ada video',
              message: 'Video yang kamu unduh muncul di sini.',
            ),
            const EmptyState(
              icon: Icons.queue_music_outlined,
              title: 'Belum ada playlist',
              message: 'Playlist yang kamu bikin sendiri muncul di sini.',
            ),
          ],
        ),
      ),
    );
  }
}
