import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/lyrics_service.dart';

/// Panel lirik di layar Sedang diputar.
///
/// Kalau liriknya bertanda waktu, baris yang lagi dinyanyikan disorot dan
/// daftarnya ikut bergulir sendiri. Kalau nggak, ditampilkan apa adanya.
class LyricsView extends StatefulWidget {
  const LyricsView({
    super.key,
    required this.track,
    required this.posisi,
    this.onSeek,
  });

  final Track track;

  /// Posisi pemutaran sekarang.
  final Duration posisi;

  /// Ketuk satu baris buat lompat ke sana.
  final void Function(Duration)? onSeek;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final _scroll = ScrollController();

  Lirik? _lirik;
  bool _memuat = true;
  int _barisAktif = -1;

  /// Jangan rebut kendali gulir kalau pengguna lagi baca sendiri.
  bool _digulirManual = false;

  @override
  void initState() {
    super.initState();
    _muat();
    _scroll.addListener(() {
      if (_scroll.position.isScrollingNotifier.value) _digulirManual = true;
    });
  }

  @override
  void didUpdateWidget(LyricsView old) {
    super.didUpdateWidget(old);
    if (old.track.id != widget.track.id) {
      _barisAktif = -1;
      _digulirManual = false;
      _muat();
    } else if (old.posisi != widget.posisi) {
      _perbaruiBaris();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _lirik = null;
    });
    final l = await LyricsService.instance.untuk(widget.track);
    if (!mounted) return;
    setState(() {
      _lirik = l;
      _memuat = false;
    });
    _perbaruiBaris();
  }

  void _perbaruiBaris() {
    final baris = _lirik?.tersinkron;
    if (baris == null || baris.isEmpty) return;

    var i = -1;
    for (var k = 0; k < baris.length; k++) {
      if (baris[k].waktu <= widget.posisi) {
        i = k;
      } else {
        break;
      }
    }
    if (i == _barisAktif) return;

    setState(() => _barisAktif = i);
    if (!_digulirManual) _gulirKe(i);
  }

  void _gulirKe(int i) {
    if (!_scroll.hasClients || i < 0) return;
    // Tinggi baris nggak seragam, jadi ini perkiraan yang cukup enak dilihat.
    const perkiraanTinggi = 44.0;
    final target = (i * perkiraanTinggi) - (_scroll.position.viewportDimension / 2) + perkiraanTinggi;
    _scroll.animateTo(
      target.clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_memuat) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }

    final l = _lirik;
    if (l == null || l.kosong) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lyrics_outlined, size: 28, color: cs.onSurfaceVariant),
              const SizedBox(height: 14),
              Text(
                'Lirik belum ketemu',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'LRCLIB belum punya lirik buat lagu ini.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    if (!l.adaWaktu) {
      return ListView(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        children: [
          Text(
            l.polos,
            style: TextStyle(fontSize: 16, height: 1.7, color: cs.onSurface),
          ),
          const SizedBox(height: 24),
          _Sumber(sumber: l.sumber),
        ],
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          itemCount: l.tersinkron.length + 1,
          itemBuilder: (context, i) {
            if (i == l.tersinkron.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _Sumber(sumber: l.sumber),
              );
            }

            final baris = l.tersinkron[i];
            final aktif = i == _barisAktif;

            return InkWell(
              onTap: widget.onSeek == null
                  ? null
                  : () {
                      _digulirManual = false;
                      widget.onSeek!(baris.waktu);
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    fontSize: aktif ? 19 : 16.5,
                    height: 1.35,
                    fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                    color: aktif ? cs.primary : cs.onSurfaceVariant,
                  ),
                  child: Text(baris.teks.isEmpty ? '·' : baris.teks),
                ),
              ),
            );
          },
        ),
        if (_digulirManual)
          Positioned(
            right: 16,
            bottom: 16,
            child: FilledButton.tonalIcon(
              onPressed: () {
                setState(() => _digulirManual = false);
                _gulirKe(_barisAktif);
              },
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Ikuti lagu'),
            ),
          ),
      ],
    );
  }
}

class _Sumber extends StatelessWidget {
  const _Sumber({required this.sumber});

  final String sumber;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Lirik dari $sumber',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
