import 'package:flutter/material.dart';

import '../aksi.dart';
import '../models/track.dart';
import '../services/library_service.dart';
import '../services/pencocok.dart';
import '../services/playlist_service.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/empty_state.dart';
import '../widgets/mull_ui.dart';

enum _Saring { semua, mull, belumAda }

enum _Urut { terbaru, judul, artis }

/// Pilih lagu dari Pustaka buat dimasukkan ke [playlist]: kolom cari,
/// filter, urutan, dan centang banyak lagu sekaligus.
class PilihPustakaScreen extends StatefulWidget {
  const PilihPustakaScreen({super.key, required this.playlist, this.langsungCari = false});

  final Playlist playlist;

  /// Kolom cari langsung aktif (keyboard muncul) begitu layar terbuka.
  final bool langsungCari;

  @override
  State<PilihPustakaScreen> createState() => _PilihPustakaScreenState();
}

class _PilihPustakaScreenState extends State<PilihPustakaScreen> {
  final _lib = LibraryService.instance;
  final _cari = TextEditingController();

  String _q = '';
  _Saring _saring = _Saring.semua;
  _Urut _urut = _Urut.terbaru;

  /// Kunci = uri berkas.
  final _dipilih = <String, Track>{};
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    if (_lib.kosong && !_lib.memuat) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lib.muat());
    }
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  bool _sudahAda(Track t) => widget.playlist.lagu.any((x) => x.id == t.id || (x.localPath != null && x.localPath == t.localPath));

  /// Semua kata yang diketik harus ada di judul atau artis (tanpa peduli
  /// huruf besar, aksen, atau isi kurung).
  bool _cocok(Track t, List<String> kata) {
    if (kata.isEmpty) return true;
    final teks = Pencocok.norm('${t.title} ${t.artist ?? ''}');
    return kata.every(teks.contains);
  }

  List<Track> _hasil() {
    final kata = Pencocok.norm(_q).split(' ').where((w) => w.isNotEmpty).toList();
    final daftar = [
      for (final t in _lib.lagu)
        if (_cocok(t, kata) &&
            (_saring != _Saring.mull || _lib.milikMull(t)) &&
            (_saring != _Saring.belumAda || !_sudahAda(t)))
          t,
    ];
    switch (_urut) {
      case _Urut.terbaru:
        break;
      case _Urut.judul:
        daftar.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _Urut.artis:
        daftar.sort((a, b) => (a.artist ?? '~').toLowerCase().compareTo((b.artist ?? '~').toLowerCase()));
    }
    return daftar;
  }

  void _pilih(Track t) {
    final k = t.localPath ?? t.id;
    setState(() => _dipilih.containsKey(k) ? _dipilih.remove(k) : _dipilih[k] = t);
  }

  void _pilihSemua(List<Track> hasil) {
    final bisa = hasil.where((t) => !_sudahAda(t)).toList();
    final semuaTerpilih = bisa.every((t) => _dipilih.containsKey(t.localPath ?? t.id));
    setState(() {
      for (final t in bisa) {
        final k = t.localPath ?? t.id;
        semuaTerpilih ? _dipilih.remove(k) : _dipilih[k] = t;
      }
    });
  }

  Future<void> _simpan() async {
    if (_dipilih.isEmpty || _menyimpan) return;
    setState(() => _menyimpan = true);
    final n = await PlaylistService.instance.tambahLagu(widget.playlist, _dipilih.values.toList());
    if (!mounted) return;
    kabari(context, n == 0 ? 'Lagunya sudah ada di playlist.' : '$n lagu masuk ke "${widget.playlist.nama}".');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LatarMull(halus: true)),
          ListenableBuilder(
            listenable: _lib,
            builder: (context, _) {
              final hasil = _hasil();
              return HalamanKaca(
                header: HeaderKaca(
                  judul: 'Tambah dari Pustaka',
                  subjudul: 'Ke "${widget.playlist.nama}"',
                  depan: TombolIkon(
                    ikon: Icons.arrow_back_rounded,
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  aksi: [
                    PopupMenuButton<_Urut>(
                      tooltip: 'Urutkan',
                      initialValue: _urut,
                      onSelected: (u) => setState(() => _urut = u),
                      icon: Icon(Icons.swap_vert_rounded, color: context.mull.icon),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: _Urut.terbaru, child: Text('Terbaru')),
                        PopupMenuItem(value: _Urut.judul, child: Text('Judul')),
                        PopupMenuItem(value: _Urut.artis, child: Text('Artis')),
                      ],
                    ),
                  ],
                  bawah: _Saringan(
                    cari: _cari,
                    autofokus: widget.langsungCari,
                    onCari: (v) => setState(() => _q = v),
                    saring: _saring,
                    onSaring: (s) => setState(() => _saring = s),
                  ),
                ),
                isi: (context, padding) => _isi(hasil, padding),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _dipilih.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _menyimpan ? null : _simpan,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: Text('Tambah ${_dipilih.length} lagu'),
                ),
              ),
            ),
    );
  }

  Widget _isi(List<Track> hasil, EdgeInsets padding) {
    final c = context.mull;
    if (_lib.memuat && _lib.kosong) {
      return Padding(padding: padding, child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)));
    }
    final atas = <Widget>[
      if (!_lib.semuaLagu)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: KartuMull(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Baru unduhan Mull yang kelihatan. Izinkan Mull baca lagu di HP biar semuanya bisa dipilih.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: c.textMuted),
                  ),
                ),
                TautanAksi(label: 'Izinkan', onTap: () => _lib.mintaIzinSemua()),
              ],
            ),
          ),
        ),
      if (hasil.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${hasil.length} lagu${_dipilih.isEmpty ? '' : '  ·  ${_dipilih.length} dipilih'}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted),
                ),
              ),
              TautanAksi(label: 'Pilih semua', onTap: () => _pilihSemua(hasil)),
            ],
          ),
        ),
    ];

    if (hasil.isEmpty) {
      return ListView(
        padding: padding,
        children: [
          ...atas,
          const SizedBox(height: 40),
          EmptyState(
            icon: Icons.search_off_rounded,
            title: _lib.lagu.isEmpty ? 'Pustaka masih kosong' : 'Nggak ada yang cocok',
            message: _lib.lagu.isEmpty ? 'Unduh lagu dulu, atau izinkan Mull baca lagu di HP.' : 'Coba kata lain atau ganti filternya.',
          ),
        ],
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: atas.length + hasil.length,
      itemBuilder: (context, i) {
        if (i < atas.length) return atas[i];
        final t = hasil[i - atas.length];
        final ada = _sudahAda(t);
        return _BarisPilih(
          track: t,
          terpilih: _dipilih.containsKey(t.localPath ?? t.id),
          sudahAda: ada,
          onTap: ada ? null : () => _pilih(t),
        );
      },
    );
  }
}

/// Kolom cari + chip filter di bawah judul header.
class _Saringan extends StatelessWidget {
  const _Saringan({required this.cari, required this.onCari, required this.saring, required this.onSaring, this.autofokus = false});

  final TextEditingController cari;
  final bool autofokus;
  final ValueChanged<String> onCari;
  final _Saring saring;
  final ValueChanged<_Saring> onSaring;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 46,
          padding: const EdgeInsets.only(left: 14, right: 4),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: c.textSubtle),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: cari,
                  autofocus: autofokus,
                  onChanged: onCari,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 14.5, color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Cari judul atau artis',
                    hintStyle: TextStyle(color: c.textSubtle),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: cari,
                builder: (context, _) => cari.text.isEmpty
                    ? const SizedBox(width: 8)
                    : TombolIkon(
                        ikon: Icons.close_rounded,
                        tooltip: 'Hapus',
                        ukuran: 38,
                        ukuranIkon: 18,
                        onPressed: () {
                          cari.clear();
                          onCari('');
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (s, label) in const [
                (_Saring.semua, 'Semua'),
                (_Saring.mull, 'Dari Mull'),
                (_Saring.belumAda, 'Belum di playlist'),
              ]) ...[
                ChipMull(label: label, terpilih: saring == s, onTap: () => onSaring(s)),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BarisPilih extends StatelessWidget {
  const _BarisPilih({required this.track, required this.terpilih, required this.sudahAda, this.onTap});

  final Track track;
  final bool terpilih;
  final bool sudahAda;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final sudut = BorderRadius.circular(18);
    final bawah = sudahAda
        ? 'Sudah ada di playlist'
        : [if (track.artist != null) track.artist!, if (track.duration != null) formatDuration(track.duration!)].join('  ·  ');
    return Opacity(
      opacity: sudahAda ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: terpilih ? Color.alphaBlend(c.accentSoft, c.surfaceSolid) : c.surface,
          borderRadius: sudut,
          border: Border.all(color: terpilih ? c.accent.withValues(alpha: 0.45) : c.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: sudut,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  Artwork(url: track.thumbUrl, size: 46, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                        if (bawah.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              bawah,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: c.textMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: sudahAda || terpilih,
                    onChanged: onTap == null ? null : (_) => onTap!(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
