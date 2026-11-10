import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/ytdlp_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/track_tile.dart';
import 'playlist_screen.dart';

/// Cari lagu atau video lewat yt-dlp (`ytsearch`), atau tempel tautan langsung.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.onPlay,
    this.onDownload,
    this.permintaanLuar,
  });

  final void Function(List<Track> daftar, int indeks)? onPlay;
  final void Function(Track track, {bool video})? onDownload;

  /// Query yang dikirim layar lain (mis. tombol Tempel tautan di Beranda).
  final ValueNotifier<String?>? permintaanLuar;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _service = YtDlpService.instance;

  List<Track>? _hasil;
  bool _cari = false;
  String? _galat;

  /// Query yang hasilnya sedang ditampilkan.
  String _terakhir = '';

  /// Tautan butuh QuickJS, jadi jauh lebih lama. Dipakai buat pesan tunggu.
  bool _lamaBanget = false;

  @override
  void initState() {
    super.initState();
    widget.permintaanLuar?.addListener(_dariLuar);
  }

  @override
  void dispose() {
    widget.permintaanLuar?.removeListener(_dariLuar);
    _controller.dispose();
    super.dispose();
  }

  void _dariLuar() {
    final q = widget.permintaanLuar?.value;
    if (q == null || q.isEmpty) return;
    _controller.text = q;
    _submit(q);
  }

  Future<void> _submit(String raw) async {
    final q = raw.trim();
    if (q.isEmpty || _cari) return;

    FocusScope.of(context).unfocus();

    // Hasil lama sengaja TIDAK dikosongkan. Kalau sudah ada isinya, daftarnya
    // tetap kebaca selagi pencarian baru jalan, cuma dikasih garis progres.
    // Layar yang mendadak kosong bikin nunggu kerasa lebih lama.
    setState(() {
      _cari = true;
      _galat = null;
      _terakhir = q;
      _lamaBanget = YtDlpService.isUrl(q);
    });

    try {
      final hasil = await _service.search(q);
      if (!mounted) return;
      setState(() {
        _hasil = hasil;
        _cari = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = e.toString().replaceFirst('Exception: ', '');
        _cari = false;
      });
    }
  }

  void _bersihkan() {
    _controller.clear();
    setState(() {
      _hasil = null;
      _galat = null;
      _terakhir = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: _submit,
          decoration: InputDecoration(
            hintText: 'Lagu, artis, atau tempel tautan',
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            suffixIcon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: _bersihkan,
                    ),
            ),
          ),
        ),
        bottom: _cari
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                ),
              )
            : null,
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final hasil = _hasil;
    final padding = EdgeInsets.only(top: 4, bottom: RuangBawah.of(context) + 16);

    if (_cari) {
      // Sudah punya hasil lama: biarkan kebaca, garis progres di atas sudah
      // cukup jadi tanda. Belum punya: tampilkan kerangka daftarnya.
      if (hasil != null && hasil.isNotEmpty) return _daftar(hasil, padding);

      return Column(
        children: [
          _StatusCari(lamaBanget: _lamaBanget, service: _service),
          Expanded(child: SkeletonTrackList(padding: padding)),
        ],
      );
    }

    if (_galat != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Pencarian gagal',
        message: _galat,
        action: FilledButton(
          onPressed: () => _submit(_terakhir),
          child: const Text('Coba lagi'),
        ),
      );
    }

    if (hasil == null) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Mau dengar apa?',
        message: 'Tulis judul lagu, nama artis, atau tempel tautan YouTube.',
      );
    }

    if (hasil.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nggak ada hasil',
        message: 'Nggak ketemu apa pun buat "$_terakhir". Coba kata lain.',
      );
    }

    return _daftar(hasil, padding);
  }

  Widget _daftar(List<Track> hasil, EdgeInsets padding) {
    return ListView.builder(
      padding: padding,
      itemCount: hasil.length,
      itemBuilder: (_, i) => TrackTile(
        track: hasil[i],
        onTap: widget.onPlay == null ? null : () => widget.onPlay!(hasil, i),
        onDownload: widget.onDownload == null ? null : () => widget.onDownload!(hasil[i]),
        onDownloadVideo:
            widget.onDownload == null ? null : () => widget.onDownload!(hasil[i], video: true),
        onTambahKePlaylist: () => tampilkanTambahKePlaylist(context, hasil[i]),
      ),
    );
  }
}

/// Satu baris status di atas kerangka daftar.
///
/// Cuma muncul kalau memang ada yang perlu dijelaskan: mesin lagi disiapkan,
/// atau tautan lagi dipecahkan (yang itu memang lama). Pencarian biasa nggak
/// dikasih teks apa-apa, karena kerangka daftarnya sudah cukup jelas.
class _StatusCari extends StatelessWidget {
  const _StatusCari({required this.lamaBanget, required this.service});

  final bool lamaBanget;
  final YtDlpService service;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final nyiapin = service.status == EngineStatus.nyiapin;

        final pesan = nyiapin
            ? service.langkah
            : lamaBanget
                ? 'Mengambil info tautan, bisa sampai 30 detik.'
                : null;

        if (pesan == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Row(
            children: [
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pesan,
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
