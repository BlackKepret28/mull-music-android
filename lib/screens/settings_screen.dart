import 'package:flutter/material.dart';

import '../dev/spike_page.dart';
import '../services/ytdlp_service.dart';
import '../settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const _SectionTitle('Tampilan'),
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
          SwitchListTile(
            value: s.glass,
            onChanged: (v) => s.glass = v,
            title: const Text('Efek kaca'),
            subtitle: const Text('Matikan kalau app terasa berat.'),
          ),
          const Divider(height: 24),
          const _SectionTitle('Mesin unduh'),
          const _BarisYtDlp(),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Diagnosa yt-dlp'),
            subtitle: const Text('Jalankan tes unduhan dan cek runtime JS.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SpikePage()),
            ),
          ),
          const Divider(height: 24),
          const _SectionTitle('Tentang'),
          const ListTile(
            title: Text('Mull Music App'),
            subtitle: Text('Versi 1.0.0 (pengembangan)'),
          ),
          const ListTile(
            title: Text('Lisensi'),
            subtitle: Text('GPL-3.0. Memakai yt-dlp, youtubedl-android, ffmpeg, dan QuickJS.'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
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
          leading: const Icon(Icons.sync),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
