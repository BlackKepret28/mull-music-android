import 'package:flutter/material.dart';

import '../aksi.dart';
import '../models/track.dart';
import '../services/download_service.dart';
import '../services/import_service.dart';
import '../services/library_service.dart';
import '../services/playlist_service.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/mull_ui.dart';
import '../widgets/sampul_playlist.dart';
import '../widgets/track_tile.dart';
import '../ytdlp.dart';
import 'import_screen.dart';
import 'pilih_pustaka_screen.dart';

/// Isi satu playlist.
class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.playlist, this.onPlay});

  final Playlist playlist;
  final void Function(List<Track> daftar, int indeks)? onPlay;

  Future<void> _gantiNama(BuildContext context) async {
    final nama = await mintaNamaPlaylist(
      context,
      awal: playlist.nama,
      judul: 'Ganti nama',
    );
    if (nama == null) return;
    await PlaylistService.instance.gantiNama(playlist, nama);
  }

  void _bagikan(BuildContext context) {
    final b = ImportService.bagikan(playlist);
    if (b.jumlah == 0) {
      kabari(context, 'Belum ada lagu yang bisa dibagikan. Lagu dari HP tanpa tautan sumber nggak ikut.');
      return;
    }
    tampilkanLembar<void>(
      context,
      judul: 'Bagikan playlist',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BarisMenu(
            ikon: Icons.qr_code_rounded,
            label: 'Kode playlist Mull',
            keterangan: 'Buat teman yang pakai Mull, di HP atau laptop. Lagu dan urutannya sama persis.',
            nada: NadaIkon.aksen,
            onTap: () {
              Navigator.pop(ctx);
              YtDlp.shareText(
                'Playlist "${playlist.nama}" (${b.jumlah} lagu). Tempel di Mull Music App, Impor:\n\n${b.kode}',
                title: 'Bagikan kode playlist',
              );
            },
          ),
          BarisMenu(
            ikon: Icons.format_list_bulleted_rounded,
            label: 'Daftar lagu',
            keterangan: 'Judul, artis, dan tautan YouTube. Bisa dibaca siapa saja.',
            nada: NadaIkon.mint,
            onTap: () {
              Navigator.pop(ctx);
              YtDlp.shareText(b.teks, title: 'Bagikan daftar lagu');
            },
          ),
          if (b.dilewati > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Text(
                '${b.dilewati} lagu dari HP nggak ikut karena nggak punya tautan sumber.',
                style: TextStyle(fontSize: 12.5, color: ctx.mull.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _hapus(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus playlist?'),
        content: Text(
          '"${playlist.nama}" bakal dihapus. Berkas lagunya nggak ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true || !context.mounted) return;
    await PlaylistService.instance.hapus(playlist);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PlaylistService.instance,
      builder: (context, _) {
        final lagu = playlist.lagu;
        final c = context.mull;

        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: LatarMull(halus: true)),
              HalamanKaca(
                header: HeaderKaca(
                  judul: playlist.nama,
                  subjudul: lagu.isEmpty
                      ? 'Masih kosong'
                      : '${lagu.length} lagu  ·  ${formatDuration(playlist.totalDurasi)}',
                  depan: TombolIkon(
                    ikon: Icons.arrow_back_rounded,
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  aksi: [
                    PopupMenuButton<String>(
                      tooltip: 'Opsi lain',
                      icon: Icon(Icons.more_vert_rounded, color: c.icon),
                      onSelected: (v) => switch (v) {
                        'bagikan' => _bagikan(context),
                        'pustaka' => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => PilihPustakaScreen(playlist: playlist)),
                          ),
                        'impor' => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ImportScreen(ke: playlist)),
                          ),
                        'nama' => _gantiNama(context),
                        'hapus' => _hapus(context),
                        _ => null,
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'bagikan', child: Text('Bagikan')),
                        PopupMenuItem(value: 'pustaka', child: Text('Tambah dari Pustaka')),
                        PopupMenuItem(value: 'impor', child: Text('Impor dari tautan')),
                        PopupMenuItem(value: 'nama', child: Text('Ganti nama')),
                        PopupMenuItem(
                          value: 'hapus',
                          child: Text('Hapus playlist'),
                        ),
                      ],
                    ),
                  ],
                  bawah: lagu.isEmpty
                      ? null
                      : Row(
                          children: [
                            FilledButton.icon(
                              onPressed: onPlay == null
                                  ? null
                                  : () => onPlay!(lagu, 0),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 22,
                              ),
                              label: const Text('Putar semua'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => putarAcak(lagu),
                              icon: const Icon(Icons.shuffle_rounded, size: 18),
                              label: const Text('Acak'),
                            ),
                          ],
                        ),
                ),
                isi: (context, padding) => lagu.isEmpty
                    ? ListView(
                        padding: padding,
                        children: [
                          _SampulBesar(playlist: playlist),
                          const SizedBox(height: 24),
                          EmptyState(
                            icon: Icons.queue_music_rounded,
                            title: 'Playlist ini masih kosong',
                            message: 'Pilih lagu dari Pustaka, atau impor dari tautan lewat titik tiga di atas.',
                            action: FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => PilihPustakaScreen(playlist: playlist)),
                              ),
                              icon: const Icon(Icons.library_music_rounded, size: 20),
                              label: const Text('Tambah dari Pustaka'),
                            ),
                          ),
                        ],
                      )
                    : ReorderableListView.builder(
                        padding: padding,
                        header: _SampulBesar(playlist: playlist),
                        itemCount: lagu.length,
                        footer: const PetunjukAkhir(
                          'Tahan lagu buat ganti urutan. Geser ke kanan buat buang dari playlist, geser ke kiri buat unduh.',
                        ),
                        // onReorderItem (bukan onReorder yang sudah usang)
                        // sudah membetulkan indeks tujuannya sendiri.
                        onReorderItem: (dari, ke) => PlaylistService.instance
                            .pindahLagu(playlist, dari, ke),
                        itemBuilder: (context, i) => ListenableBuilder(
                          // Key harus di akar item (syarat ReorderableListView).
                          key: ValueKey('${playlist.id}/${lagu[i].id}'),
                          // Arah geser tergantung lagunya sudah diunduh atau belum.
                          listenable: Listenable.merge([
                            DownloadService.instance,
                            LibraryService.instance,
                          ]),
                          builder: (context, _) {
                            final sudah = sudahDiunduh(lagu[i]);
                            return Dismissible(
                              key: ValueKey('geser/${playlist.id}/${lagu[i].id}'),
                              // Kanan = buang dari playlist. Kiri = unduh (cuma
                              // kalau belum diunduh).
                              direction: sudah
                                  ? DismissDirection.startToEnd
                                  : DismissDirection.horizontal,
                              confirmDismiss: (arah) async {
                                if (arah == DismissDirection.endToStart) {
                                  // Unduh dimulai, barisnya balik lagi (nggak hilang).
                                  unduhLagu(context, lagu[i]);
                                  return false;
                                }
                                return true;
                              },
                              onDismissed: (arah) {
                                if (arah == DismissDirection.startToEnd) {
                                  PlaylistService.instance.hapusLagu(playlist, lagu[i]);
                                }
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 5,
                                ),
                                padding: const EdgeInsets.only(left: 24),
                                decoration: BoxDecoration(
                                  color: c.dangerSoft,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: c.danger,
                                ),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 5,
                                ),
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  color: c.accentSoft,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  Icons.download_rounded,
                                  color: c.accent,
                                ),
                              ),
                              child: TrackTile(
                                track: lagu[i],
                                onTap: onPlay == null
                                    ? null
                                    : () => onPlay!(lagu, i),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Sampul besar di atas daftar lagu (ala versi Windows): mozaik dari
/// lagu-lagunya, ikut berubah begitu isi playlist berubah.
class _SampulBesar extends StatelessWidget {
  const _SampulBesar({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final sisi = (MediaQuery.sizeOf(context).width * 0.56).clamp(160.0, 260.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: c.shadow, blurRadius: 30, offset: const Offset(0, 12))],
          ),
          child: SampulPlaylist(playlist: playlist, ukuran: sisi, radius: 22),
        ),
      ),
    );
  }
}

/// Dialog nama playlist. Balikin null kalau dibatalkan.
Future<String?> mintaNamaPlaylist(
  BuildContext context, {
  String awal = '',
  String judul = 'Playlist baru',
}) {
  final c = TextEditingController(text: awal);

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(judul),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nama playlist'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, c.text),
          child: const Text('Simpan'),
        ),
      ],
    ),
  ).then((v) {
    c.dispose();
    final s = v?.trim();
    return (s == null || s.isEmpty) ? null : s;
  });
}

/// Lembar pilihan "Tambah ke playlist".
Future<void> tampilkanTambahKePlaylist(BuildContext context, Track t) async {
  final service = PlaylistService.instance;
  if (!service.sudahMuat) await service.muat();
  if (!context.mounted) return;

  await tampilkanLembar<void>(
    context,
    judul: 'Tambah ke playlist',
    builder: (ctx) => ListenableBuilder(
      listenable: service,
      builder: (ctx, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
            leading: const KotakIkon(ikon: Icons.add_rounded, ukuran: 48),
            title: const Text('Playlist baru'),
            onTap: () async {
              final nama = await mintaNamaPlaylist(ctx);
              if (nama == null) return;
              final p = await service.buat(nama);
              await service.tambahLagu(p, [t]);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          for (final p in service.daftar)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              leading: SampulPlaylist(playlist: p, ukuran: 48, radius: 12),
              title: Text(p.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${p.lagu.length} lagu'),
              onTap: () async {
                final n = await service.tambahLagu(p, [t]);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      n > 0
                          ? 'Ditambahkan ke "${p.nama}".'
                          : 'Lagu itu sudah ada di sana.',
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}
