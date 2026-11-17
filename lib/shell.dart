import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'models/track.dart';
import 'screens/downloads_screen.dart';
import 'screens/home_screen.dart';
import 'screens/import_screen.dart';
import 'screens/library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/search_screen.dart';
import 'services/download_service.dart';
import 'services/finder_service.dart';
import 'services/import_service.dart';
import 'services/player_service.dart';
import 'services/playlist_service.dart';
import 'services/recent_service.dart';
import 'services/update_service.dart';
import 'services/ytdlp_service.dart';
import 'settings.dart';
import 'ytdlp.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/glass_surface.dart';
import 'widgets/mini_player.dart';
import 'widgets/mull_ui.dart';

/// Tinggi kapsul pemutar mini dan pil navigasi (MsaTabBar: 64).
const _tinggiPemutar = 64.0;
const _tinggiNav = 64.0;
const _jarakPanel = 8.0;

/// Kerangka utama ala MSA: latar pastel di paling belakang, lalu dua kapsul
/// kaca melayang di bawah (pemutar mini, navigasi empat tab). Isi halaman
/// sengaja lewat di bawah kapsul itu (`extendBody: true`) supaya kacanya ada
/// yang dibiaskan.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _player = MullAudioHandler.instance;
  final _unduhan = DownloadService.instance;
  int _tab = 0;

  /// Jembatan Beranda -> Cari waktu tombol Tempel tautan ditekan.
  final _permintaanCari = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    // Init Python + ffmpeg makan ~5 detik pertama kali. Mulai sekarang supaya
    // sudah siap waktu pengguna selesai ngetik pencarian pertamanya.
    // Galatnya ditangani YtDlpService dan muncul di layar Cari.
    YtDlpService.instance.ensureReady().ignore();

    // Playlist dibaca dari disk. Ditunda ke setelah frame pertama karena
    // `muat()` langsung memberi tahu pendengarnya.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PlaylistService.instance.muat();
      RecentService.instance.muat();
      // Tanpa izin ini notifikasi pemutar (dan kontrol di layar kunci)
      // nggak muncul di Android 13+. Diminta sekali waktu app dibuka.
      _mintaIzinNotifikasi();
      FinderService.instance.muat();
      // Cek versi baru diam-diam (paling sering sekali sehari). Kalau ada,
      // kartu kecil muncul di Beranda.
      if (SettingsScope.of(context).waktunyaCekUpdate()) {
        UpdateService.instance.cek(diam: true);
      }
    });
  }

  @override
  void dispose() {
    _permintaanCari.dispose();
    super.dispose();
  }

  void _tempelTautan(String tautan) {
    // Tautan playlist (YouTube, Spotify) atau kode Mull: langsung ke Impor.
    if (ImportService.tampakPlaylist(tautan)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ImportScreen(teksAwal: tautan)),
      );
      return;
    }
    setState(() => _tab = 1);
    // Diset ulang ke null dulu supaya tautan yang sama bisa dikirim dua kali.
    _permintaanCari.value = null;
    _permintaanCari.value = tautan;
  }

  void _goSearch() => setState(() => _tab = 1);

  void _mintaIzinNotifikasi() => YtDlp.mintaIzinNotifikasi().ignore();

  /// Putar satu daftar mulai dari lagu yang diketuk, supaya tombol
  /// berikutnya/sebelumnya ada isinya.
  void _putar(List<Track> daftar, int indeks) {
    _mintaIzinNotifikasi();
    _player.putar(daftar, indeks);
  }

  void _putarAcak(List<Track> daftar) {
    _mintaIzinNotifikasi();
    _player.putarAcak(daftar);
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
    final marginBawah = sisaBawah + 12;
    final lebarNav = (MediaQuery.sizeOf(context).width - 24).clamp(0.0, 380.0);

    return StreamBuilder<MediaItem?>(
      stream: _player.mediaItem,
      builder: (context, snapItem) {
        final item = snapItem.data;
        final tinggiPanel = (item == null ? 0 : _tinggiPemutar + _jarakPanel) + _tinggiNav;

        return RuangBawah(
          tinggi: tinggiPanel + marginBawah + 8,
          child: Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                // Latar digambar SEKALI di sini, dipakai bareng semua tab.
                Positioned.fill(child: LatarSampul(sampul: item?.artUri?.toString())),
                Positioned.fill(child: _isiTab()),
              ],
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, marginBawah),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item != null) ...[
                    GlassSurface(
                      radius: _tinggiPemutar / 2,
                      child: _BarPemutar(player: _player, item: item, onTap: _bukaSedangDiputar),
                    ),
                    const SizedBox(height: _jarakPanel),
                  ],
                  GlassSurface(
                    radius: _tinggiNav / 2,
                    width: lebarNav,
                    height: _tinggiNav,
                    child: BottomNav(
                      index: _tab,
                      onPilih: (i) => setState(() => _tab = i),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _isiTab() {
    return IndexedStack(
      index: _tab,
      children: [
        HomeScreen(
          onPlay: _putar,
          onGoSearch: _goSearch,
          onGoLibrary: () => setState(() => _tab = 2),
          onGoDownloads: () => setState(() => _tab = 3),
          // Kolom "Cari atau tempel tautan" di Beranda: teks apa pun
          // (kata kunci atau tautan) diteruskan ke layar Cari.
          onTempelTautan: _tempelTautan,
        ),
        SearchScreen(
          onPlay: _putar,
          onDownload: _unduh,
          permintaanLuar: _permintaanCari,
        ),
        LibraryScreen(
          onGoSearch: _goSearch,
          onPlay: _putar,
          onPlayAcak: _putarAcak,
        ),
        DownloadsScreen(onGoSearch: _goSearch),
      ],
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
          stream: player.positionStreamLambat,
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
