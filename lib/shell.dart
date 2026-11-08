import 'package:flutter/material.dart';

import 'models/track.dart';
import 'screens/downloads_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'widgets/mini_player.dart';

/// Kerangka utama: empat tab di bawah, bar pemutar mini nempel di atasnya.
///
/// Tiap tab disimpan hidup pakai [IndexedStack] supaya posisi gulir dan
/// hasil pencarian nggak hilang waktu pindah tab.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  /// Lagu yang sedang diputar. Masih selalu null sampai pemutar disambung
  /// (just_audio + audio_service) di commit berikutnya.
  Track? _current;
  bool _playing = false;

  void _goSearch() => setState(() => _tab = 1);

  void _openTrack(Track t) => setState(() => _current = t);

  @override
  Widget build(BuildContext context) {
    final current = _current;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(onTapTrack: _openTrack, onGoSearch: _goSearch),
          SearchScreen(onTapTrack: _openTrack),
          LibraryScreen(onGoSearch: _goSearch),
          DownloadsScreen(onGoSearch: _goSearch),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current != null)
            MiniPlayer(
              track: current,
              playing: _playing,
              onTogglePlay: () => setState(() => _playing = !_playing),
              onTap: () {},
            ),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Beranda',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Cari',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: 'Pustaka',
              ),
              NavigationDestination(
                icon: Icon(Icons.download_outlined),
                selectedIcon: Icon(Icons.download),
                label: 'Unduhan',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
