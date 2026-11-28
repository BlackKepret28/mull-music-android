import 'dart:async';

import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/riwayat_cari.dart';
import '../services/saran_cari.dart';
import '../services/ytdlp_service.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/mull_ui.dart';
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
  final _fokus = FocusNode();

  /// Saran ketikan (dari YouTube) dan penunda biar nggak minta tiap huruf.
  Timer? _tundaSaran;
  List<String> _saran = const [];
  int _tokenSaran = 0;
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
    _fokus.addListener(_segarkan);
    RiwayatCari.instance.addListener(_segarkan);
    RiwayatCari.instance.muat();
  }

  void _segarkan() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.permintaanLuar?.removeListener(_dariLuar);
    RiwayatCari.instance.removeListener(_segarkan);
    _tundaSaran?.cancel();
    _fokus.dispose();
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
    if (!YtDlpService.isUrl(q)) RiwayatCari.instance.catat(q);

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
      // Siapkan URL 3 hasil teratas diam-diam lewat jalur kilat (murah), jadi
      // ketukan pertama biasanya langsung bunyi.
      for (final t in hasil.where((t) => t.localPath == null).take(3)) {
        _service.prefetch(t, boleYtDlp: false);
      }
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
      _saran = const [];
      _hasil = null;
      _galat = null;
      _terakhir = '';
    });
  }

  String get _subjudul {
    final hasil = _hasil;
    if (_cari) return YtDlpService.isUrl(_terakhir) ? 'Mengambil info tautan...' : 'Mencari "$_terakhir"...';
    if (hasil != null && hasil.isNotEmpty) return '${hasil.length} hasil buat "$_terakhir"';
    return 'Dari YouTube dan YouTube Music';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HalamanKaca(
        header: HeaderKaca(
          judul: 'Cari',
          subjudul: _subjudul,
          bawah: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kolom cari pil (MSA): isi sedikit lebih pekat dari panel kacanya.
              Container(
                height: 48,
                padding: const EdgeInsets.only(left: 16, right: 4),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 21, color: c.textSubtle),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _fokus,
                        textInputAction: TextInputAction.search,
                        onChanged: _ketik,
                        onSubmitted: _submit,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.text),
                        decoration: InputDecoration(
                          hintText: 'Lagu, artis, atau tempel tautan',
                          hintStyle: TextStyle(fontSize: 15, color: c.textSubtle),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (_, value, _) => value.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: 'Hapus',
                              icon: Icon(Icons.close_rounded, size: 20, color: c.textMuted),
                              onPressed: _bersihkan,
                            ),
                    ),
                  ],
                ),
              ),
              if (_cari)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(minHeight: 2.5),
                  ),
                ),
            ],
          ),
        ),
        isi: (context, padding) => _body(padding),
      ),
    );
  }

  Widget _body(EdgeInsets padding) {
    // Kolom cari lagi dipakai: tampilkan riwayat atau saran, bukan hasil.
    if (_fokus.hasFocus) return _panelSaran(padding);

    final hasil = _hasil;

    if (_cari) {
      // Sudah punya hasil lama: biarkan kebaca, garis progres di atas sudah
      // cukup jadi tanda. Belum punya: tampilkan kerangka daftarnya.
      if (hasil != null && hasil.isNotEmpty) return _daftar(hasil, padding);

      return Padding(
        padding: EdgeInsets.only(top: padding.top),
        child: Column(
          children: [
            _StatusCari(lamaBanget: _lamaBanget, service: _service),
            Expanded(child: SkeletonTrackList(padding: EdgeInsets.only(bottom: padding.bottom))),
          ],
        ),
      );
    }

    if (_galat != null) {
      return _kosong(padding, EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Pencarian gagal',
        message: _galat,
        action: FilledButton(
          onPressed: () => _submit(_terakhir),
          child: const Text('Coba lagi'),
        ),
      ));
    }

    if (hasil == null) {
      return _kosong(padding, const EmptyState(
        icon: Icons.search_rounded,
        title: 'Mau dengar apa?',
        message: 'Tulis judul lagu, nama artis, atau tempel tautan YouTube.',
      ));
    }

    if (hasil.isEmpty) {
      return _kosong(padding, EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nggak ada hasil',
        message: 'Nggak ketemu apa pun buat "$_terakhir". Coba kata lain, atau tempel tautannya langsung.',
      ));
    }

    return _daftar(hasil, padding);
  }

  /// Dipanggil tiap huruf: ganti panel, lalu minta saran setelah jeda singkat.
  void _ketik(String v) {
    setState(() {});
    _tundaSaran?.cancel();
    final q = v.trim();
    if (q.length < 2 || YtDlpService.isUrl(q)) {
      if (_saran.isNotEmpty) setState(() => _saran = const []);
      return;
    }
    _tundaSaran = Timer(const Duration(milliseconds: 250), () async {
      final aku = ++_tokenSaran;
      final hasil = await SaranCari.ambil(q);
      // Ketikannya sudah berubah lagi: jawaban ini basi.
      if (!mounted || aku != _tokenSaran) return;
      setState(() => _saran = hasil);
    });
  }

  void _pakai(String teks, {required bool langsungCari}) {
    _controller.text = teks;
    _controller.selection = TextSelection.collapsed(offset: teks.length);
    if (langsungCari) {
      _submit(teks);
    } else {
      _ketik(teks);
    }
  }

  Widget _panelSaran(EdgeInsets padding) {
    final c = context.mull;
    final q = _controller.text.trim();
    final riwayat = RiwayatCari.instance.daftar;

    Widget baris(IconData ikon, String teks, Widget? ujung, VoidCallback onTap) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: Icon(ikon, size: 22, color: c.textSubtle),
          title: Text(teks, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: ujung,
          onTap: onTap,
        );

    // Lagi mengetik: saran dari YouTube. Belum ada saran (jaringan lambat,
    // atau terlalu pendek): riwayat yang cocok.
    if (q.isNotEmpty) {
      final cocok = _saran.isNotEmpty
          ? _saran
          : riwayat.where((e) => e.toLowerCase().contains(q.toLowerCase())).toList();
      return ListView(
        padding: padding,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          for (final s in cocok)
            baris(
              _saran.isNotEmpty ? Icons.search_rounded : Icons.history_rounded,
              s,
              IconButton(
                tooltip: 'Isi ke kolom cari',
                icon: Icon(Icons.north_west_rounded, size: 20, color: c.textMuted),
                onPressed: () => _pakai(s, langsungCari: false),
              ),
              () => _pakai(s, langsungCari: true),
            ),
        ],
      );
    }

    if (riwayat.isEmpty) {
      return _kosong(
        padding,
        const EmptyState(
          icon: Icons.history_rounded,
          title: 'Belum ada pencarian',
          message: 'Pencarian yang kamu lakukan muncul di sini biar gampang diulang.',
        ),
      );
    }

    return ListView(
      padding: padding,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Pencarian terakhir',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textMuted),
                ),
              ),
              TextButton(
                onPressed: RiwayatCari.instance.kosongkan,
                child: const Text('Hapus semua'),
              ),
            ],
          ),
        ),
        for (final r in riwayat)
          baris(
            Icons.history_rounded,
            r,
            IconButton(
              tooltip: 'Hapus dari riwayat',
              icon: Icon(Icons.close_rounded, size: 20, color: c.textMuted),
              onPressed: () => RiwayatCari.instance.hapus(r),
            ),
            () => _pakai(r, langsungCari: true),
          ),
      ],
    );
  }

  Widget _kosong(EdgeInsets padding, Widget isi) => Padding(padding: padding, child: isi);

  Widget _daftar(List<Track> hasil, EdgeInsets padding) {
    return ListView.builder(
      padding: padding,
      itemCount: hasil.length + 1,
      itemBuilder: (_, i) => i == hasil.length
          ? const PetunjukAkhir('Ketuk lagu buat langsung putar. Titik tiga buat unduh atau simpan ke playlist.')
          : TrackTile(
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
