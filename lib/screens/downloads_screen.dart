import 'package:flutter/material.dart';

import '../services/download_service.dart';
import '../widgets/artwork.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/empty_state.dart';

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
        final adaSelesai = daftar.any((u) => u.status == StatusUnduhan.selesai);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Unduhan'),
            actions: [
              if (adaSelesai)
                TextButton(
                  onPressed: service.bersihkanSelesai,
                  child: const Text('Bersihkan'),
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: daftar.isEmpty
              ? EmptyState(
                  icon: Icons.download_outlined,
                  title: 'Belum ada unduhan',
                  message: 'Lagu yang kamu unduh disimpan ke Music/Mull, '
                      'jadi bisa dibuka app musik lain juga.',
                  action: FilledButton(
                    onPressed: onGoSearch,
                    child: const Text('Cari lagu'),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(top: 4, bottom: RuangBawah.of(context) + 16),
                  itemCount: daftar.length,
                  itemBuilder: (_, i) => _Baris(unduhan: daftar[i], service: service),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Artwork(url: u.track.thumbUrl, size: 48, radius: 6, isVideo: u.video),
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
                        fontWeight: FontWeight.w500,
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
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                // Progres belum diketahui: garis bergerak, bukan angka palsu.
                value: u.progress < 0 ? null : u.progress / 100,
                minHeight: 3,
                backgroundColor: cs.outlineVariant,
                color: cs.primary,
              ),
            ),
          ],
        ],
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
