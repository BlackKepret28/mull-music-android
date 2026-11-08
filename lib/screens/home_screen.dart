import 'package:flutter/material.dart';

import '../models/track.dart';
import '../widgets/empty_state.dart';
import '../widgets/shelf.dart';
import 'settings_screen.dart';

/// Beranda: rak kartu horizontal, pola Spotify / YT Music.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.recent = const [],
    this.downloaded = const [],
    this.onTapTrack,
    this.onGoSearch,
  });

  /// Riwayat putar. Masih kosong sampai pemutar jadi.
  final List<Track> recent;

  /// Lagu yang sudah ada file-nya di HP.
  final List<Track> downloaded;

  final void Function(Track track)? onTapTrack;
  final VoidCallback? onGoSearch;

  @override
  Widget build(BuildContext context) {
    final kosong = recent.isEmpty && downloaded.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mull'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: kosong
          ? EmptyState(
              icon: Icons.graphic_eq,
              title: 'Belum ada apa-apa di sini',
              message: 'Cari lagu atau video dulu, nanti yang sering kamu putar '
                  'muncul di halaman ini.',
              action: FilledButton(
                onPressed: onGoSearch,
                child: const Text('Mulai cari'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Shelf(
                  title: 'Baru diputar',
                  items: recent,
                  onTapItem: onTapTrack,
                ),
                Shelf(
                  title: 'Sudah diunduh',
                  items: downloaded,
                  onTapItem: onTapTrack,
                ),
              ],
            ),
    );
  }
}
