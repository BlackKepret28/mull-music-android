import 'package:flutter/material.dart';

import '../dev/spike_page.dart';
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
          const _SectionTitle('Lanjutan'),
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
