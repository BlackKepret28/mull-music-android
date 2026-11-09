import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/track.dart';
import '../services/ytdlp_service.dart';

/// Pemutar video layar penuh.
///
/// Video yang sudah diunduh diputar langsung dari MediaStore. Yang belum,
/// URL-nya diminta ke yt-dlp dulu, dan itu bisa makan puluhan detik karena
/// QuickJS, jadi layarnya ngasih tahu terang-terangan.
class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key, required this.track});

  final Track track;

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  VideoPlayerController? _c;
  String? _galat;
  bool _kontrolTampil = true;

  @override
  void initState() {
    super.initState();
    // Video enaknya mendatar, dan status bar disembunyikan.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _siapkan();
  }

  @override
  void dispose() {
    _c?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _siapkan() async {
    try {
      final lokal = widget.track.localPath;
      final uri = lokal != null
          ? Uri.parse(lokal)
          : Uri.parse(await YtDlpService.instance.streamUrl(widget.track, video: true));

      final c = VideoPlayerController.networkUrl(uri);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _c = c);
      await c.play();
      c.addListener(_ikut);
    } catch (e) {
      if (!mounted) return;
      setState(() => _galat = YtDlpService.pesanRamah(e));
    }
  }

  void _ikut() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_galat != null)
            _Pesan(
              ikon: Icons.error_outline,
              judul: 'Video nggak bisa diputar',
              detail: _galat!,
              aksi: FilledButton(
                onPressed: () {
                  setState(() => _galat = null);
                  _siapkan();
                },
                child: const Text('Coba lagi'),
              ),
            )
          else if (c == null)
            _Pesan(
              ikon: Icons.hourglass_empty,
              judul: 'Menyiapkan video',
              detail: widget.track.localPath != null
                  ? 'Sebentar...'
                  : 'Mengambil tautan dari YouTube. Bisa sampai 30 detik\n'
                      'karena diproses di HP.',
              aksi: const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
              ),
            )
          else
            GestureDetector(
              onTap: () => setState(() => _kontrolTampil = !_kontrolTampil),
              child: Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),
            ),
          if (c != null && _kontrolTampil) _Kontrol(controller: c, judul: widget.track.title),
          Positioned(
            top: 8,
            left: 4,
            child: SafeArea(
              child: IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pesan extends StatelessWidget {
  const _Pesan({
    required this.ikon,
    required this.judul,
    required this.detail,
    required this.aksi,
  });

  final IconData ikon;
  final String judul;
  final String detail;
  final Widget aksi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, color: Colors.white54, size: 30),
            const SizedBox(height: 16),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            aksi,
          ],
        ),
      ),
    );
  }
}

class _Kontrol extends StatelessWidget {
  const _Kontrol({required this.controller, required this.judul});

  final VideoPlayerController controller;
  final String judul;

  @override
  Widget build(BuildContext context) {
    final v = controller.value;
    final total = v.duration;
    final posisi = v.position;

    return Container(
      // Hitam tipis di atas dan bawah supaya teks putih tetap kebaca.
      color: Colors.black26,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Text(
                judul,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const Spacer(),
            IconButton(
              iconSize: 56,
              icon: Icon(
                v.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white,
              ),
              onPressed: () => v.isPlaying ? controller.pause() : controller.play(),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    formatDuration(posisi),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Expanded(
                    child: Slider(
                      value: total.inMilliseconds == 0
                          ? 0
                          : posisi.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
                      max: total.inMilliseconds == 0 ? 1 : total.inMilliseconds.toDouble(),
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                      onChanged: (x) => controller.seekTo(Duration(milliseconds: x.round())),
                    ),
                  ),
                  Text(
                    formatDuration(total),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
