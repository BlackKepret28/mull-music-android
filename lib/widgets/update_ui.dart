import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../theme.dart';
import 'mull_ui.dart';

/// Lembar update: versi baru, catatan rilis, tombol unduh dan pasang.
Future<void> tampilkanUpdate(BuildContext context) {
  final u = UpdateService.instance;
  if (u.rilis == null && u.tahap != TahapUpdate.cek) u.cek();
  return tampilkanLembar<void>(
    context,
    judul: 'Update Mull',
    builder: (ctx) => ListenableBuilder(listenable: u, builder: (ctx, _) => _IsiUpdate(u: u)),
  );
}

class _IsiUpdate extends StatelessWidget {
  const _IsiUpdate({required this.u});

  final UpdateService u;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final r = u.rilis;
    final ukuran = r?.ukuran == null ? '' : ' (${(r!.ukuran! / 1024 / 1024).toStringAsFixed(1)} MB)';

    final Widget tombol = switch (u.tahap) {
      TahapUpdate.cek => const _Memuat('Mengecek versi terbaru...'),
      TahapUpdate.unduh => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: u.progres <= 0 ? null : u.progres, minHeight: 6),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mengunduh ${(u.progres * 100).round()}%',
                    style: TextStyle(color: c.textMuted),
                  ),
                ),
                TextButton(onPressed: u.batalkan, child: const Text('Batal')),
              ],
            ),
          ],
        ),
      TahapUpdate.ada || TahapUpdate.siap => FilledButton.icon(
          onPressed: u.unduhDanPasang,
          icon: Icon(u.tahap == TahapUpdate.siap ? Icons.install_mobile_rounded : Icons.download_rounded),
          label: Text(u.tahap == TahapUpdate.siap ? 'Pasang' : 'Unduh dan pasang$ukuran'),
        ),
      _ => OutlinedButton.icon(
          onPressed: () => u.cek(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Cek lagi'),
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Versi kamu: ${u.versiSekarang ?? '-'}${r != null ? '   ·   Terbaru: ${r.versi}' : ''}',
            style: TextStyle(fontSize: 13.5, color: c.textMuted),
          ),
          if (u.pesan != null) ...[
            const SizedBox(height: 8),
            Text(
              u.pesan!,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: u.tahap == TahapUpdate.gagal ? c.danger : c.text,
              ),
            ),
          ],
          if (r != null && r.catatan.isNotEmpty && u.adaUpdate) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.chipBg, borderRadius: BorderRadius.circular(14)),
              child: SingleChildScrollView(
                child: Text(r.catatan, style: TextStyle(fontSize: 13, height: 1.45, color: c.textMuted)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          tombol,
          if (u.adaUpdate) ...[
            const SizedBox(height: 10),
            Text(
              'Android bakal nanya sekali lagi sebelum memasang. Playlist, riwayat, dan lagu kamu nggak ikut berubah.',
              style: TextStyle(fontSize: 12, height: 1.4, color: c.textSubtle),
            ),
          ],
        ],
      ),
    );
  }
}

class _Memuat extends StatelessWidget {
  const _Memuat(this.teks);
  final String teks;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text(teks, style: TextStyle(color: context.mull.textMuted)),
        ],
      );
}

/// Kartu kecil di Beranda waktu ada versi baru.
class KartuUpdate extends StatelessWidget {
  const KartuUpdate({super.key});

  @override
  Widget build(BuildContext context) {
    final u = UpdateService.instance;
    return ListenableBuilder(
      listenable: u,
      builder: (context, _) {
        if (!u.adaUpdate || u.rilis == null) return const SizedBox.shrink();
        final c = context.mull;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: KartuMull(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                const KotakIkon(ikon: Icons.system_update_rounded, nada: NadaIkon.mint),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Versi ${u.rilis!.versi} tersedia',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                      Text('Ketuk buat lihat isinya', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                    ],
                  ),
                ),
                TextButton(onPressed: () => tampilkanUpdate(context), child: const Text('Update')),
              ],
            ),
          ),
        );
      },
    );
  }
}
