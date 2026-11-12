import 'package:flutter/material.dart';

import '../services/download_service.dart';
import '../widgets/artwork.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/mull_ui.dart';

/// Antrean dan riwayat unduhan.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key, this.onGoSearch});

  final VoidCallback? onGoSearch;

  @override
  Widget build(BuildContext context) {
    final service = DownloadService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final daftar = service.antrean;
        final aktif = daftar.where((u) => u.bisaDibatalkan).toList();
        final lainnya = daftar.where((u) => !u.bisaDibatalkan).toList();
        final adaSelesai = daftar.any((u) => u.status == StatusUnduhan.selesai);

        final ringkas = <String>[
          if (aktif.isNotEmpty) '${aktif.length} di antrean',
          if (lainnya.isNotEmpty) '${lainnya.length} di riwayat',
        ];

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: HalamanKaca(
            header: HeaderKaca(
              judul: 'Unduhan',
              subjudul: ringkas.isEmpty
                  ? 'Lagu dan video yang kamu simpan'
                  : ringkas.join('  ·  '),
              aksi: [
                if (adaSelesai)
                  TautanAksi(
                    label: 'Bersihkan',
                    onTap: service.bersihkanSelesai,
                  ),
              ],
            ),
            isi: (context, padding) => daftar.isEmpty
                ? Padding(
                    padding: padding,
                    child: EmptyState(
                      icon: Icons.download_rounded,
                      title: 'Belum ada unduhan',
                      message: 'Santai dulu. Cari lagu, lalu ketuk titik tiga dan pilih Unduh lagu.',
                      action: FilledButton.icon(
                        onPressed: onGoSearch,
                        icon: const Icon(Icons.search_rounded, size: 20),
                        label: const Text('Cari lagu'),
                      ),
                    ),
                  )
                : ListView(
                    padding: padding.copyWith(left: 16, right: 16),
                    children: [
                      if (aktif.isNotEmpty) ...[
                        const LabelBagian('Sedang jalan'),
                        for (final u in aktif)
                          _Baris(unduhan: u, service: service),
                      ],
                      if (lainnya.isNotEmpty) ...[
                        LabelBagian(
                          'Riwayat',
                          padding: EdgeInsets.fromLTRB(
                            4,
                            aktif.isEmpty ? 0 : 14,
                            0,
                            10,
                          ),
                        ),
                        for (final u in lainnya)
                          _Baris(unduhan: u, service: service),
                      ],
                      const PetunjukAkhir(
                        'Lagu tersimpan di Music/Mull, video di Movies/Mull.',
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.unduhan, required this.service});

  final Unduhan unduhan;
  final DownloadService service;

  String _ukuran(int bytes) {
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = unduhan;

    final (String bawah, Color warnaBawah) = switch (u.status) {
      StatusUnduhan.antre => ('Menunggu giliran', cs.onSurfaceVariant),
      StatusUnduhan.jalan => (
        u.progress < 0
            ? 'Menyiapkan...'
            : '${u.progress.toStringAsFixed(0)}%'
                  '${u.eta > 0 ? '  ·  sisa ${u.eta} dtk' : ''}',
        cs.onSurfaceVariant,
      ),
      StatusUnduhan.selesai => (
        u.ukuran == null ? 'Selesai' : 'Selesai  ·  ${_ukuran(u.ukuran!)}',
        cs.primary,
      ),
      StatusUnduhan.gagal => (u.galat ?? 'Gagal', cs.error),
      StatusUnduhan.dibatalkan => ('Dibatalkan', cs.onSurfaceVariant),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KartuMull(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        radius: 18,
        child: Column(
          children: [
            Row(
              children: [
                Artwork(
                  url: u.track.thumbUrl,
                  size: 48,
                  radius: 12,
                  isVideo: u.video,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bawah,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: warnaBawah),
                      ),
                    ],
                  ),
                ),
                _Aksi(unduhan: u, service: service),
              ],
            ),
            if (u.sedangJalan) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    // Progres belum diketahui: garis bergerak, bukan angka palsu.
                    value: u.progress < 0 ? null : u.progress / 100,
                    minHeight: 3,
                    backgroundColor: context.mull.track,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Aksi extends StatelessWidget {
  const _Aksi({required this.unduhan, required this.service});

  final Unduhan unduhan;
  final DownloadService service;

  @override
  Widget build(BuildContext context) {
    return switch (unduhan.status) {
      StatusUnduhan.antre || StatusUnduhan.jalan => IconButton(
        tooltip: 'Batalkan',
        icon: const Icon(Icons.close, size: 20),
        onPressed: () => service.batal(unduhan),
      ),
      StatusUnduhan.gagal => IconButton(
        tooltip: 'Coba lagi',
        icon: const Icon(Icons.refresh, size: 20),
        onPressed: () => service.ulangi(unduhan),
      ),
      StatusUnduhan.selesai => Icon(
        Icons.download_done,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
      StatusUnduhan.dibatalkan => IconButton(
        tooltip: 'Hapus dari daftar',
        icon: const Icon(Icons.clear, size: 20),
        onPressed: () => service.hapusDariDaftar(unduhan),
      ),
    };
  }
}
