import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/ytdlp_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/track_tile.dart';

/// Cari lagu atau video lewat yt-dlp (`ytsearch`), atau tempel tautan langsung.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.onTapTrack, this.onDownload});

  final void Function(Track track)? onTapTrack;
  final void Function(Track track)? onDownload;

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    final q = raw.trim();
    if (q.isEmpty || _cari) return;

    FocusScope.of(context).unfocus();
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
            prefixIcon: const Icon(Icons.search, size: 22),
            suffixIcon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _hasil = null;
                          _galat = null;
                        });
                      },
                    ),
            ),
          ),
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_cari) return _Menunggu(lamaBanget: _lamaBanget, service: _service);

    if (_galat != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Pencarian gagal',
        message: _galat,
        action: FilledButton(
          onPressed: () => _submit(_terakhir),
          child: const Text('Coba lagi'),
        ),
      );
    }

    final hasil = _hasil;
    if (hasil == null) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Mau dengar apa?',
        message: 'Tulis judul lagu, nama artis, atau tempel tautan YouTube.',
      );
    }

    if (hasil.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Nggak ada hasil',
        message: 'Nggak ketemu apa pun buat "$_terakhir". Coba kata lain.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: hasil.length,
      itemBuilder: (_, i) => TrackTile(
        track: hasil[i],
        onTap: widget.onTapTrack == null ? null : () => widget.onTapTrack!(hasil[i]),
        onDownload: widget.onDownload == null ? null : () => widget.onDownload!(hasil[i]),
      ),
    );
  }
}

/// Indikator tunggu yang jujur: sebut kalau prosesnya memang lama.
class _Menunggu extends StatelessWidget {
  const _Menunggu({required this.lamaBanget, required this.service});

  final bool lamaBanget;
  final YtDlpService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final nyiapin = service.status == EngineStatus.nyiapin;

        final pesan = nyiapin
            ? service.langkah
            : lamaBanget
                ? 'Mengambil info tautan. Ini bisa sampai 30 detik karena\n'
                    'YouTube harus dipecahkan dulu di HP.'
                : 'Mencari...';

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  pesan,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
