import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aksi.dart';
import '../models/track.dart';
import '../services/finder_service.dart';
import '../services/ytdlp_service.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/mull_ui.dart';
import '../widgets/track_tile.dart';
import '../ytdlp.dart';
import 'playlist_screen.dart';

enum _Mode { diam, dengar, proses }

/// Kenali lagu (mirip Shazam): dari mikrofon, tautan, berkas di Pustaka,
/// atau lagu yang lagi diputar. Plus cari dari potongan lirik.
class FinderScreen extends StatefulWidget {
  const FinderScreen({super.key, this.berkas, this.di});

  /// Langsung kenali lagu ini (dari Pustaka atau pemutar).
  final Track? berkas;

  /// Posisi yang ditunjuk di pemutar ("Kenali lagu di bagian ini").
  final Duration? di;

  @override
  State<FinderScreen> createState() => _FinderScreenState();
}

class _FinderScreenState extends State<FinderScreen> {
  final _finder = FinderService.instance;
  final _tautan = TextEditingController();
  final _lirik = TextEditingController();

  _Mode _mode = _Mode.diam;
  double _level = 0;
  double _detik = 0;
  bool _mencocokkan = false;
  bool _batal = false;
  String? _status;
  String? _galat;

  LaguDikenali? _hasil;
  bool _kosong = false;
  bool _cariYt = false;

  List<HasilLirik>? _hasilLirik;
  bool _cariLirik = false;
  String? _galatLirik;

  @override
  void initState() {
    super.initState();
    _finder.muat();
    final b = widget.berkas;
    if (b != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _kenaliBerkas(b));
    }
  }

  @override
  void dispose() {
    _batal = true;
    _tautan.dispose();
    _lirik.dispose();
    super.dispose();
  }

  void _mulai(String status) => setState(() {
        _mode = _Mode.proses;
        _status = status;
        _galat = null;
        _hasil = null;
        _kosong = false;
        _batal = false;
      });

  Future<void> _selesai(LaguDikenali? l, {String? galat}) async {
    if (!mounted) return;
    setState(() {
      _mode = _Mode.diam;
      _hasil = l;
      _kosong = l == null && galat == null;
      _galat = galat;
      _status = null;
    });
    if (l == null) return;
    await _finder.catat(l);
    if (!mounted) return;
    setState(() => _cariYt = true);
    await _finder.pasangkan(l);
    if (mounted) setState(() => _cariYt = false);
  }

  Future<void> _dengarkan() async {
    if (_mode == _Mode.dengar) {
      _batal = true;
      return;
    }
    if (_mode != _Mode.diam) return;
    // Izin dulu, supaya "Mendengarkan..." nggak muncul di belakang dialog izin.
    if (!await YtDlp.ensureMicPermission().catchError((_) => false)) {
      if (mounted) {
        setState(() => _galat =
            'Izin mikrofon belum dikasih. Bisa diatur lewat Pengaturan HP > Aplikasi > Mull Music > Izin.');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _mode = _Mode.dengar;
      _level = 0;
      _detik = 0;
      _galat = null;
      _hasil = null;
      _kosong = false;
      _batal = false;
    });
    try {
      final l = await _finder.dengarkan(
        onLevel: (lv, d, cocok) {
          if (mounted) {
            setState(() {
              _level = lv;
              _detik = d;
              _mencocokkan = cocok;
            });
          }
        },
        batal: () => _batal,
      );
      if (_batal) {
        if (mounted) setState(() => _mode = _Mode.diam);
        return;
      }
      await _selesai(l);
    } on FinderGagal catch (e) {
      await _selesai(null, galat: e.pesan);
    } catch (e) {
      await _selesai(null, galat: YtDlpService.pesanRamah(e));
    }
  }

  Future<void> _kenaliBerkas(Track t) async {
    _mulai('Membaca "${t.title}"...');
    try {
      if (t.localPath == null) {
        // Lagu dari internet: audionya diambil yt-dlp dulu.
        final (l, _) = await _finder.kenaliTautan(t.resolvableUrl, di: widget.di, langkah: (s) {
          if (mounted) setState(() => _status = s);
        });
        await _selesai(l);
        return;
      }
      final l = await _finder.kenaliSumber(
        t.localPath!,
        durasi: t.duration,
        di: widget.di,
        sumber: 'file',
        progres: (i, n) {
          if (mounted && n > 1) setState(() => _status = 'Mendengarkan bagian ${i + 1} dari $n...');
        },
      );
      await _selesai(l);
    } on FinderGagal catch (e) {
      await _selesai(null, galat: e.pesan);
    } catch (e) {
      await _selesai(null, galat: YtDlpService.pesanRamah(e));
    }
  }

  Future<void> _kenaliTautan() async {
    final url = _tautan.text.trim();
    if (!YtDlpService.isUrl(url)) {
      setState(() => _galat = 'Tempel tautan video atau audio dulu (YouTube, TikTok, Reels, dll).');
      return;
    }
    FocusScope.of(context).unfocus();
    _mulai('Membuka tautan...');
    try {
      final (l, _) = await _finder.kenaliTautan(url, langkah: (s) {
        if (mounted) setState(() => _status = s);
      });
      await _selesai(l);
    } on FinderGagal catch (e) {
      await _selesai(null, galat: e.pesan);
    } catch (e) {
      await _selesai(null, galat: YtDlpService.pesanRamah(e));
    }
  }

  Future<void> _tempelTautan() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim() ?? '';
    if (t.isEmpty) return;
    _tautan.text = t;
    if (YtDlpService.isUrl(t)) _kenaliTautan();
  }

  Future<void> _cariDariLirik() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _cariLirik = true;
      _galatLirik = null;
    });
    try {
      final r = await _finder.cariLirik(_lirik.text);
      if (mounted) setState(() => _hasilLirik = r);
    } on FinderGagal catch (e) {
      if (mounted) setState(() => _galatLirik = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _galatLirik = YtDlpService.pesanRamah(e));
    } finally {
      if (mounted) setState(() => _cariLirik = false);
    }
  }

  void _menuRiwayat(LaguDikenali l) {
    tampilkanLembar<void>(
      context,
      judul: l.judul,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BarisMenu(
            ikon: Icons.play_arrow_rounded,
            label: 'Putar',
            nada: NadaIkon.aksen,
            onTap: () {
              Navigator.pop(ctx);
              _putar(l);
            },
          ),
          BarisMenu(
            ikon: Icons.download_rounded,
            label: 'Unduh',
            nada: NadaIkon.mint,
            onTap: () async {
              Navigator.pop(ctx);
              final t = await _pastikanYt(l);
              if (t != null && mounted) unduhLagu(context, t);
            },
          ),
          BarisMenu(
            ikon: Icons.playlist_add_rounded,
            label: 'Tambah ke playlist',
            onTap: () async {
              Navigator.pop(ctx);
              final t = await _pastikanYt(l);
              if (t != null && mounted) tampilkanTambahKePlaylist(context, t);
            },
          ),
          BarisMenu(
            ikon: Icons.delete_outline_rounded,
            label: 'Hapus dari riwayat',
            bahaya: true,
            onTap: () {
              Navigator.pop(ctx);
              _finder.hapus(l);
            },
          ),
        ],
      ),
    );
  }

  Future<Track?> _pastikanYt(LaguDikenali l) async {
    if (l.yt != null) return l.yt;
    kabari(context, 'Mencari "${l.judul}" di YouTube...');
    final t = await _finder.pasangkan(l);
    if (t == null && mounted) kabari(context, 'Lagunya belum ketemu di YouTube.');
    return t;
  }

  Future<void> _putar(LaguDikenali l) async {
    final t = await _pastikanYt(l);
    if (t != null) putarDaftar([t], 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LatarMull(halus: true)),
          HalamanKaca(
            header: HeaderKaca(
              judul: 'Kenali lagu',
              subjudul: 'Dari suara, tautan, atau potongan lirik',
              depan: TombolIkon(
                ikon: Icons.arrow_back_rounded,
                tooltip: 'Kembali',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            isi: (context, padding) => ListenableBuilder(
              listenable: _finder,
              builder: (context, _) => ListView(
                padding: padding.copyWith(left: 16, right: 16),
                children: [
                  _kartuDengar(),
                  if (_hasil != null) ...[
                    const SizedBox(height: 14),
                    _KartuHasil(
                      lagu: _hasil!,
                      mencari: _cariYt,
                      onPutar: () => _putar(_hasil!),
                      onUnduh: () async {
                        final t = await _pastikanYt(_hasil!);
                        if (t != null && context.mounted) unduhLagu(context, t);
                      },
                      onPlaylist: () async {
                        final t = await _pastikanYt(_hasil!);
                        if (t != null && context.mounted) tampilkanTambahKePlaylist(context, t);
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  const LabelBagian('Dari tautan'),
                  _kartuTautan(),
                  const SizedBox(height: 20),
                  const LabelBagian('Dari potongan lirik'),
                  _kartuLirik(),
                  ..._daftarLirik(),
                  if (_finder.riwayat.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    LabelBagian(
                      'Pernah dikenali',
                    ),
                    for (final l in _finder.riwayat.take(30))
                      _BarisRiwayat(lagu: l, onTap: () => _putar(l), onMenu: () => _menuRiwayat(l)),
                  ],
                  const PetunjukAkhir(
                    'Yang dikirim ke server pengenal lagu cuma sidik jari suaranya, bukan rekamannya.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuDengar() {
    final c = context.mull;
    final dengar = _mode == _Mode.dengar;
    final proses = _mode == _Mode.proses;

    final String judul;
    final String? sub;
    if (dengar) {
      judul = _mencocokkan ? 'Mencocokkan...' : 'Mendengarkan...';
      sub = '${_detik.floor()} dtk  ·  ketuk lagi buat berhenti';
    } else if (proses) {
      judul = 'Sebentar...';
      sub = _status;
    } else if (_galat != null) {
      judul = 'Belum bisa';
      sub = _galat;
    } else if (_kosong) {
      judul = 'Lagunya belum ketemu';
      sub = 'Coba di bagian reff, kurangi suara obrolan, atau dekatkan HP ke sumber suara.';
    } else {
      judul = 'Ketuk buat dengarkan';
      sub = 'Putar lagunya di dekat HP. Biasanya ketemu dalam 4 sampai 12 detik.';
    }

    return KartuMull(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      child: Column(
        children: [
          SizedBox(
            width: 168,
            height: 168,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: dengar ? 128 + 40 * _level : 128,
                  height: dengar ? 128 + 40 * _level : 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.accent.withValues(alpha: dengar ? 0.16 : 0.08),
                  ),
                ),
                TombolPutar(
                  ikon: dengar ? Icons.stop_rounded : Icons.graphic_eq_rounded,
                  tooltip: dengar ? 'Berhenti' : 'Dengarkan',
                  ukuran: 104,
                  onPressed: proses ? null : _dengarkan,
                  child: proses
                      ? SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(strokeWidth: 3, color: c.onAccent),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(judul, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: _galat != null ? c.danger : c.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kolom({
    required TextEditingController controller,
    required String petunjuk,
    required VoidCallback onKirim,
    required Widget aksi,
    int baris = 1,
  }) {
    final c = context.mull;
    return KartuMull(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: baris,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onKirim(),
              style: TextStyle(fontSize: 15, color: c.text),
              decoration: InputDecoration(
                hintText: petunjuk,
                hintStyle: TextStyle(color: c.textSubtle),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          aksi,
        ],
      ),
    );
  }

  Widget _kartuTautan() => _kolom(
        controller: _tautan,
        petunjuk: 'Tautan YouTube, TikTok, Reels...',
        onKirim: _kenaliTautan,
        aksi: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TombolIkon(ikon: Icons.content_paste_rounded, tooltip: 'Tempel', onPressed: _tempelTautan),
            TombolIkon(
              ikon: Icons.arrow_forward_rounded,
              tooltip: 'Kenali',
              onPressed: _mode == _Mode.diam ? _kenaliTautan : null,
            ),
          ],
        ),
      );

  Widget _kartuLirik() => _kolom(
        controller: _lirik,
        petunjuk: 'Ketik potongan liriknya',
        onKirim: _cariDariLirik,
        baris: 3,
        aksi: TombolIkon(
          ikon: Icons.search_rounded,
          tooltip: 'Cari',
          onPressed: _cariLirik ? null : _cariDariLirik,
          child: _cariLirik
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
        ),
      );

  List<Widget> _daftarLirik() {
    final c = context.mull;
    if (_galatLirik != null) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
          child: Text(_galatLirik!, style: TextStyle(color: c.danger, fontSize: 13)),
        ),
      ];
    }
    final h = _hasilLirik;
    if (h == null) return const [];
    if (h.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
          child: Text('Nggak ada hasil. Coba potongan lirik yang lain.', style: TextStyle(color: c.textMuted)),
        ),
      ];
    }
    final daftar = h.map((e) => e.track).toList();
    return [
      const SizedBox(height: 6),
      for (var i = 0; i < h.length; i++) ...[
        TrackTile(
          track: h[i].track,
          margin: const EdgeInsets.symmetric(vertical: 5),
          onTap: () => putarDaftar(daftar, i),
          onDownload: () => unduhLagu(context, h[i].track),
          onTambahKePlaylist: () => tampilkanTambahKePlaylist(context, h[i].track),
        ),
        if (h[i].baris != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '"${h[i].baris}"',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: c.accentStrong),
            ),
          ),
      ],
    ];
  }
}

class _KartuHasil extends StatelessWidget {
  const _KartuHasil({
    required this.lagu,
    required this.mencari,
    required this.onPutar,
    required this.onUnduh,
    required this.onPlaylist,
  });

  final LaguDikenali lagu;
  final bool mencari;
  final VoidCallback onPutar;
  final VoidCallback onUnduh;
  final VoidCallback onPlaylist;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final info = [lagu.album, lagu.tahun, lagu.genre].whereType<String>().where((s) => s.isNotEmpty).join('  ·  ');
    return KartuMull(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Artwork(url: lagu.sampul ?? lagu.yt?.thumbUrl, size: 84, radius: 16),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ketemu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.accentStrong)),
                    const SizedBox(height: 2),
                    Text(
                      lagu.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.2),
                    ),
                    const SizedBox(height: 3),
                    Text(lagu.artis, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted)),
                    if (info.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          info,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.textSubtle),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: mencari ? null : onPutar,
                icon: mencari
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(mencari ? 'Mencari di YouTube' : 'Putar'),
              ),
              OutlinedButton.icon(
                onPressed: mencari ? null : onUnduh,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Unduh'),
              ),
              IconButton(
                tooltip: 'Tambah ke playlist',
                onPressed: mencari ? null : onPlaylist,
                icon: const Icon(Icons.playlist_add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarisRiwayat extends StatelessWidget {
  const _BarisRiwayat({required this.lagu, required this.onTap, required this.onMenu});

  final LaguDikenali lagu;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final sudut = BorderRadius.circular(18);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(color: c.surface, borderRadius: sudut, border: Border.all(color: c.border)),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: sudut,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
            child: Row(
              children: [
                Artwork(url: lagu.sampul ?? lagu.yt?.thumbUrl, size: 48, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lagu.judul,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        lagu.artis,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Opsi lain', icon: const Icon(Icons.more_vert, size: 20), onPressed: onMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
