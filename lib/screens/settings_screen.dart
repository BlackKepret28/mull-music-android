import 'package:flutter/material.dart';

import '../dev/spike_page.dart';
import '../services/ytdlp_service.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets/mull_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LatarMull(halus: true)),
          HalamanKaca(
            header: HeaderKaca(
              judul: 'Pengaturan',
              depan: TombolIkon(
                ikon: Icons.arrow_back_rounded,
                tooltip: 'Kembali',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            isi: (context, padding) => ListView(
              padding: padding.copyWith(left: 16, right: 16),
              children: [
                const LabelBagian('Tampilan'),
                _Kartu(
                  children: [
                    RadioGroup<ThemeMode>(
                      groupValue: s.themeMode,
                      onChanged: (v) => s.themeMode = v ?? ThemeMode.system,
                      child: const Column(
                        children: [
                          RadioListTile<ThemeMode>(value: ThemeMode.system, title: Text('Ikut sistem')),
                          RadioListTile<ThemeMode>(value: ThemeMode.light, title: Text('Terang')),
                          RadioListTile<ThemeMode>(value: ThemeMode.dark, title: Text('Gelap')),
                        ],
                      ),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    SwitchListTile(
                      value: s.glass,
                      onChanged: (v) => s.glass = v,
                      title: const Text('Efek kaca'),
                      subtitle: const Text('Matikan kalau app terasa berat. Panelnya jadi pekat, bentuknya tetap.'),
                    ),
                  ],
                ),
                const _Jarak(),
                const LabelBagian('Unduhan'),
                _Kartu(
                  children: [
                    RadioGroup<String>(
                      groupValue: s.formatAudio,
                      onChanged: (v) => s.formatAudio = v ?? 'm4a',
                      child: const Column(
                        children: [
                          RadioListTile<String>(
                            value: 'm4a',
                            title: Text('m4a (AAC)'),
                            subtitle: Text('Paling aman, kebaca hampir semua app musik.'),
                          ),
                          RadioListTile<String>(
                            value: 'opus',
                            title: Text('opus'),
                            subtitle: Text('Berkas lebih kecil, tapi app lama kadang nolak.'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    const ListTile(
                      leading: KotakIkon(ikon: Icons.folder_rounded, nada: NadaIkon.peach, ukuran: 38),
                      title: Text('Tempat simpan'),
                      subtitle: Text('Music/Mull buat lagu, Movies/Mull buat video.'),
                    ),
                  ],
                ),
                const _Jarak(),
                const LabelBagian('Mesin unduh'),
                _Kartu(
                  children: [
                    const _BarisYtDlp(),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: const KotakIkon(ikon: Icons.bug_report_rounded, nada: NadaIkon.lavender, ukuran: 38),
                      title: const Text('Diagnosa yt-dlp'),
                      subtitle: const Text('Jalankan tes unduhan dan cek runtime JS.'),
                      trailing: Icon(Icons.chevron_right_rounded, color: context.mull.textSubtle),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SpikePage()),
                      ),
                    ),
                  ],
                ),
                const _Jarak(),
                const LabelBagian('Tentang'),
                const _Kartu(
                  children: [
                    ListTile(
                      title: Text('Mull Music App'),
                      subtitle: Text('Versi 1.0.0 (pengembangan)'),
                    ),
                    Divider(indent: 16, endIndent: 16),
                    ListTile(
                      title: Text('Lisensi'),
                      subtitle: Text(
                        'GPL-3.0. Memakai yt-dlp, youtubedl-android, ffmpeg, dan QuickJS. '
                        'Font Plus Jakarta Sans (OFL).',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu kelompok pengaturan di dalam kartu MSA.
class _Kartu extends StatelessWidget {
  const _Kartu({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return KartuMull(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: children),
    );
  }
}

class _Jarak extends StatelessWidget {
  const _Jarak();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 20);
}

/// Versi yt-dlp + tombol perbarui.
///
/// Belum ada perbarui otomatis berkala: app cuma memperbarui sekali waktu
/// pertama dipasang. Nyusul setelah penyimpanan pengaturan jadi.
class _BarisYtDlp extends StatefulWidget {
  const _BarisYtDlp();

  @override
  State<_BarisYtDlp> createState() => _BarisYtDlpState();
}

class _BarisYtDlpState extends State<_BarisYtDlp> {
  final _service = YtDlpService.instance;
  bool _jalan = false;

  Future<void> _perbarui() async {
    setState(() => _jalan = true);
    String pesan;
    try {
      final v = await _service.perbaruiYtDlp();
      pesan = v == null ? 'yt-dlp diperbarui.' : 'yt-dlp sekarang $v.';
    } catch (e) {
      pesan = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    setState(() => _jalan = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final v = _service.version;
        final nyiapin = _service.status == EngineStatus.nyiapin;

        return ListTile(
          leading: const KotakIkon(ikon: Icons.sync_rounded, nada: NadaIkon.mint, ukuran: 38),
          title: const Text('yt-dlp'),
          subtitle: Text(switch (_service.status) {
            EngineStatus.gagal => _service.error ?? 'Gagal disiapkan.',
            EngineStatus.nyiapin => _service.langkah,
            _ => v ?? 'Versi bawaan paket',
          }),
          trailing: _jalan || nyiapin
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(onPressed: _perbarui, child: const Text('Perbarui')),
        );
      },
    );
  }
}
