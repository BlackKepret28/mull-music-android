import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aksi.dart';
import '../services/import_service.dart';
import '../services/playlist_service.dart';
import '../theme.dart';
import '../widgets/artwork.dart';
import '../widgets/mull_ui.dart';
import 'playlist_screen.dart';

/// Impor playlist dari tautan YouTube Music, YouTube, Spotify, daftar
/// teks, atau kode bagikan Mull. Ikut layar Impor versi Windows.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, this.teksAwal, this.ke});

  /// Tautan yang langsung dibaca (mis. dari kolom tempel di Beranda).
  final String? teksAwal;

  /// Masukkan ke playlist ini, bukan bikin playlist baru.
  final Playlist? ke;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _teks = TextEditingController();
  final _nama = TextEditingController();

  PratinjauImpor? _p;
  bool _membaca = false;
  String? _langkah;
  String? _galat;
  bool _mencocokkan = false;
  bool _batal = false;
  bool _menyimpan = false;
  bool _unduhJuga = false;

  /// null = playlist baru.
  Playlist? _tujuan;

  @override
  void initState() {
    super.initState();
    _tujuan = widget.ke;
    final awal = widget.teksAwal?.trim();
    if (awal != null && awal.isNotEmpty) {
      _teks.text = awal;
      WidgetsBinding.instance.addPostFrameCallback((_) => _baca());
    }
  }

  @override
  void dispose() {
    _batal = true;
    _teks.dispose();
    _nama.dispose();
    super.dispose();
  }

  Future<void> _tempel() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim() ?? '';
    if (t.isEmpty) {
      if (mounted) kabari(context, 'Papan klip kamu masih kosong.');
      return;
    }
    _teks.text = t;
    _baca();
  }

  Future<void> _baca() async {
    if (_membaca) return;
    FocusScope.of(context).unfocus();
    _batal = true; // hentikan pencocokan lama
    setState(() {
      _membaca = true;
      _galat = null;
      _p = null;
      _langkah = 'Membaca playlist...';
    });
    try {
      final p = await ImportService.pratinjau(_teks.text, progres: (a, b) {
        if (mounted) setState(() => _langkah = 'Membaca lagu $a dari $b...');
      });
      if (!mounted) return;
      _nama.text = p.nama;
      setState(() => _p = p);
      if (p.perluCocok) _cocokkan(p);
    } on ImporGagal catch (e) {
      if (mounted) setState(() => _galat = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _galat = '$e');
    } finally {
      if (mounted) setState(() => _membaca = false);
    }
  }

  Future<void> _cocokkan(PratinjauImpor p) async {
    _batal = false;
    setState(() => _mencocokkan = true);
    await ImportService.cocokkan(
      p,
      onUbah: () {
        if (mounted) setState(() {});
      },
      batal: () => _batal || !mounted || _p != p,
    );
    if (mounted && _p == p) setState(() => _mencocokkan = false);
  }

  Future<void> _simpan() async {
    final p = _p;
    if (p == null || _menyimpan) return;
    setState(() => _menyimpan = true);
    try {
      final (pl, n) = await ImportService.simpan(p, ke: _tujuan, namaBaru: _nama.text.trim());
      if (!mounted) return;
      if (_unduhJuga) {
        for (final l in p.lagu) {
          if (l.yt != null && l.dipakai) unduhLagu(context, l.yt!, diam: true);
        }
      }
      kabari(
        context,
        n == 0
            ? 'Semua lagunya sudah ada di "${pl.nama}".'
            : '$n lagu masuk ke "${pl.nama}"${_unduhJuga ? ', unduhannya sudah diantrekan' : ''}.',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: pl, onPlay: putarDaftar)),
      );
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LatarMull(halus: true)),
          HalamanKaca(
            header: HeaderKaca(
              judul: 'Impor playlist',
              subjudul: 'YouTube Music, YouTube, Spotify, atau kode Mull',
              depan: TombolIkon(
                ikon: Icons.arrow_back_rounded,
                tooltip: 'Kembali',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            isi: (context, padding) => ListView(
              padding: padding.copyWith(left: 16, right: 16),
              children: [
                _kolomTempel(),
                if (_membaca) _Memuat(teks: _langkah ?? 'Membaca...'),
                if (_galat != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
                    child: Text(_galat!, style: TextStyle(color: context.mull.danger, height: 1.4)),
                  ),
                if (p == null && !_membaca) const _Petunjuk(),
                if (p != null) ...[
                  const SizedBox(height: 16),
                  _ringkasan(p),
                  const SizedBox(height: 16),
                  _pilihanSimpan(),
                  const SizedBox(height: 18),
                  LabelBagian('${p.lagu.length} lagu'),
                  for (final l in p.lagu) _BarisLagu(lagu: l, onUbah: () => setState(() {})),
                  const PetunjukAkhir(
                    'Lagu bertanda tanya itu pasangannya kurang yakin. Hilangkan centangnya kalau salah.',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kolomTempel() {
    final c = context.mull;
    return KartuMull(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _teks,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _baca(),
              style: TextStyle(fontSize: 15, color: c.text),
              decoration: InputDecoration(
                hintText: 'Tempel tautan playlist',
                hintStyle: TextStyle(color: c.textSubtle),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          TombolIkon(ikon: Icons.content_paste_rounded, tooltip: 'Tempel', onPressed: _tempel),
          TombolIkon(ikon: Icons.arrow_forward_rounded, tooltip: 'Baca', onPressed: _membaca ? null : _baca),
        ],
      ),
    );
  }

  Widget _ringkasan(PratinjauImpor p) {
    final c = context.mull;
    final ok = p.lagu.where((l) => l.status == StatusCocok.ok).length;
    final ragu = p.lagu.where((l) => l.status == StatusCocok.ragu).length;
    final nggak = p.lagu.where((l) => l.status == StatusCocok.nggakAda).length;
    final selesai = ok + ragu + nggak;

    return KartuMull(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Artwork(url: p.sampul, size: 64, radius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nama,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [if (p.pemilik != null) p.pemilik!, '${p.lagu.length} lagu'].join('  ·  '),
                      style: TextStyle(fontSize: 13, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.perluCocok) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p.lagu.isEmpty ? 1 : selesai / p.lagu.length,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _mencocokkan
                  ? 'Mencari pasangannya di YouTube: $selesai dari ${p.lagu.length}'
                  : '$ok cocok, $ragu kurang yakin, $nggak nggak ketemu',
              style: TextStyle(fontSize: 13, color: c.textMuted),
            ),
          ],
          if (p.terbatas) ...[
            const SizedBox(height: 10),
            Text(
              'Lewat tautan, Spotify cuma ngasih 100 lagu pertama. Buat sisanya, buka playlist di Spotify desktop, '
              'pilih semua lagu (Ctrl+A), salin (Ctrl+C), lalu tempel di sini.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: c.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pilihanSimpan() {
    final daftar = PlaylistService.instance.daftar;
    final dipakai = _p?.lagu.where((l) => l.yt != null && l.dipakai).length ?? 0;
    return KartuMull(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<Playlist?>(
            initialValue: _tujuan,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Simpan ke'),
            items: [
              const DropdownMenuItem<Playlist?>(value: null, child: Text('Playlist baru')),
              for (final p in daftar)
                DropdownMenuItem<Playlist?>(
                  value: p,
                  child: Text(p.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _tujuan = v),
          ),
          if (_tujuan == null) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _nama,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama playlist'),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _unduhJuga,
            onChanged: (v) => setState(() => _unduhJuga = v),
            title: const Text('Unduh juga jadi audio'),
          ),
          FilledButton.icon(
            onPressed: dipakai == 0 || _menyimpan ? null : _simpan,
            icon: _menyimpan
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.playlist_add_check_rounded),
            label: Text(dipakai == 0 ? 'Belum ada lagu yang cocok' : 'Impor $dipakai lagu'),
          ),
        ],
      ),
    );
  }
}

class _Memuat extends StatelessWidget {
  const _Memuat({required this.teks});
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 0),
      child: Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text(teks, style: TextStyle(color: context.mull.textMuted))),
        ],
      ),
    );
  }
}

class _Petunjuk extends StatelessWidget {
  const _Petunjuk();

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    Widget baris(IconData i, NadaIkon n, String judul, String isi) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KotakIkon(ikon: i, nada: n, ukuran: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(judul, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(isi, style: TextStyle(fontSize: 13, height: 1.4, color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        children: [
          baris(Icons.queue_music_rounded, NadaIkon.aksen, 'YouTube Music dan YouTube',
              'Buka playlist-nya, ketuk Bagikan, Salin link, lalu tempel di sini.'),
          baris(Icons.library_music_rounded, NadaIkon.mint, 'Spotify',
              'Tautan playlist atau album publik. Lagunya dicarikan pasangannya di YouTube.'),
          baris(Icons.notes_rounded, NadaIkon.peach, 'Daftar lagu',
              'Satu lagu per baris, misalnya "Judul - Artis".'),
          baris(Icons.share_rounded, NadaIkon.lavender, 'Kode playlist Mull',
              'Dari tombol Bagikan di playlist, di HP atau di laptop.'),
        ],
      ),
    );
  }
}

class _BarisLagu extends StatelessWidget {
  const _BarisLagu({required this.lagu, required this.onUbah});

  final LaguImpor lagu;
  final VoidCallback onUbah;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final yt = lagu.yt;
    final (ikon, warna) = switch (lagu.status) {
      StatusCocok.menunggu => (Icons.more_horiz_rounded, c.textSubtle),
      StatusCocok.ok => (Icons.check_circle_rounded, c.accent),
      StatusCocok.ragu => (Icons.help_rounded, c.textMuted),
      StatusCocok.nggakAda => (Icons.cancel_rounded, c.danger),
    };
    final bisaDipilih = yt != null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Artwork(url: yt?.thumbUrl, size: 44, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lagu.judul,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  yt != null && yt.title != lagu.judul ? 'YouTube: ${yt.title}' : lagu.artis,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ],
            ),
          ),
          Icon(ikon, size: 20, color: warna),
          Checkbox(
            value: bisaDipilih && lagu.dipakai,
            onChanged: bisaDipilih
                ? (v) {
                    lagu.dipakai = v ?? false;
                    onUbah();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
