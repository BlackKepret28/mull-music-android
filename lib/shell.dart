import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'models/track.dart';
import 'screens/downloads_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/search_screen.dart';
import 'services/download_service.dart';
import 'services/library_service.dart';
import 'services/player_service.dart';
import 'services/ytdlp_service.dart';
import 'settings.dart';
import 'ytdlp.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/glass_surface.dart';
import 'widgets/mini_player.dart';

/// Tinggi bar pemutar mini (isi + garis progres).
const _tinggiPemutar = 62.0;
const _tinggiNav = 60.0;

/// Kerangka utama: panel kaca mengambang di bawah berisi bar pemutar mini
/// dan navigasi empat tab. Isi halaman sengaja lewat di bawah panel itu
/// (`extendBody: true`) supaya kacanya ada yang dibiaskan.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _player = MullAudioHandler.instance;
  final _unduhan = DownloadService.instance;
  int _tab = 0;

  /// Izin notifikasi cuma diminta sekali, pas pertama kali pengguna memutar
  /// atau mengunduh sesuatu. Minta di layar pembuka cuma bikin bingung.
  bool _izinDiminta = false;

  @override
  void initState() {
    super.initState();
    // Init Python + ffmpeg makan ~5 detik pertama kali. Mulai sekarang supaya
    // sudah siap waktu pengguna selesai ngetik pencarian pertamanya.
    // Galatnya ditangani YtDlpService dan muncul di layar Cari.
    YtDlpService.instance.ensureReady().ignore();
  }

  void _goSearch() => setState(() => _tab = 1);

  void _mintaIzinNotifikasi() {
    if (_izinDiminta) return;
    _izinDiminta = true;
    // Gagal pun nggak apa-apa: musiknya tetap jalan, cuma tanpa notifikasi.
    YtDlp.ensureNotificationPermission().ignore();
  }

  /// Putar satu daftar mulai dari lagu yang diketuk, supaya tombol
  /// berikutnya/sebelumnya ada isinya.
  void _putar(List<Track> daftar, int indeks) {
    _mintaIzinNotifikasi();
    _player.putar(daftar, indeks);
  }

  void _unduh(Track t, {bool video = false}) {
    _mintaIzinNotifikasi();
    _unduhan.formatAudio = SettingsScope.of(context).formatAudio;
    _unduhan.tambah(t, video: video);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${t.title}" masuk antrean unduhan.'),
        action: SnackBarAction(label: 'Lihat', onPressed: () => setState(() => _tab = 3)),
      ),
    );
  }

  void _bukaSedangDiputar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const NowPlayingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sisaBawah = MediaQuery.viewPaddingOf(context).bottom;
    final marginBawah = sisaBawah + 10;

    return StreamBuilder<MediaItem?>(
      stream: _player.mediaItem,
      builder: (context, snapItem) {
        final item = snapItem.data;
        final tinggiPanel = (item == null ? 0 : _tinggiPemutar) + _tinggiNav;

        return RuangBawah(
          tinggi: tinggiPanel + marginBawah + 8,
          child: Scaffold(
            extendBody: true,
            body: IndexedStack(
              index: _tab,
              children: [
                ListenableBuilder(
                  listenable: LibraryService.instance,
                  builder: (context, _) => HomeScreen(
                    downloaded: LibraryService.instance.lagu,
                    onPlay: _putar,
                    onGoSearch: _goSearch,
                  ),
                ),
                SearchScreen(onPlay: _putar, onDownload: _unduh),
                LibraryScreen(onGoSearch: _goSearch, onPlay: _putar),
                DownloadsScreen(onGoSearch: _goSearch),
              ],
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, marginBawah),
              child: GlassSurface(
                radius: 26,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item != null)
                      _BarPemutar(player: _player, item: item, onTap: _bukaSedangDiputar),
                    BottomNav(
                      index: _tab,
                      onPilih: (i) => setState(() => _tab = i),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bar pemutar mini yang ikut keadaan audio_service.
class _BarPemutar extends StatelessWidget {
  const _BarPemutar({required this.player, required this.item, required this.onTap});

  final MullAudioHandler player;
  final MediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: player.playbackState,
      builder: (context, snapState) {
        final state = snapState.data;
        final main = state?.playing ?? false;
        final sibuk = state?.processingState == AudioProcessingState.loading ||
            state?.processingState == AudioProcessingState.buffering;

        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, snapPos) {
            final total = item.duration?.inMilliseconds ?? 0;
            final posisi = snapPos.data?.inMilliseconds ?? 0;

            return MiniPlayer(
              track: Track(
                id: item.id,
                title: item.title,
                artist: item.artist,
                thumbUrl: item.artUri?.toString(),
                duration: item.duration,
              ),
              playing: main,
              buffering: sibuk,
              progress: total <= 0 ? 0 : posisi / total,
              onTap: onTap,
              onTogglePlay: main ? player.pause : player.play,
              onNext: player.skipToNext,
            );
          },
        );
      },
    );
  }
}
