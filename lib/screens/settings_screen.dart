import 'package:flutter/material.dart';

import '../dev/spike_page.dart';
import '../services/update_service.dart';
import '../services/ytdlp_service.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets/mull_ui.dart';
import '../widgets/update_ui.dart';
import '../ytdlp.dart';

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
                    SwitchListTile(
                      value: s.glass,
                      onChanged: (v) => s.glass = v,
                      title: const Text('Efek kaca'),
                      subtitle: const Text('Matikan kalau app terasa berat. Panelnya jadi pekat, bentuknya tetap.'),
                    ),
                  ],
                ),
                const _Jarak(),
                const LabelBagian('Pemutar'),
                _Kartu(
                  children: [
                    const _BarisNotifikasi(),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: const KotakIkon(ikon: Icons.battery_saver_rounded, nada: NadaIkon.peach, ukuran: 38),
                      title: const Text('Jalan di latar belakang'),
                      subtitle: const Text(
                        'Kalau musik atau notifikasi hilang saat layar mati, set baterai Mull ke "Tanpa batasan".',
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: context.mull.textSubtle),
                      onTap: () => YtDlp.openBatterySettings(),
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
                _Kartu(
                  children: [
                    ListTile(
                      leading: const KotakIkon(ikon: Icons.system_update_rounded, nada: NadaIkon.aksen, ukuran: 38),
                      title: const Text('Cek update'),
                      subtitle: FutureBuilder<String>(
                        future: UpdateService.instance.versiLengkap(),
                        builder: (context, snap) => Text(
                          snap.hasData ? 'Mull Music App ${snap.data}' : 'Mull Music App',
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: context.mull.textSubtle),
                      onTap: () => tampilkanUpdate(context),
                    ),
                    SwitchListTile(
                      value: s.cekUpdate,
                      onChanged: (v) => s.cekUpdate = v,
                      title: const Text('Cek update otomatis'),
                      subtitle: const Text('Paling sering sekali sehari, waktu app dibuka.'),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    const ListTile(
                      title: Text('Lisensi'),
                      subtitle: Text(
                        'GPL-3.0. Memakai yt-dlp, youtubedl-android, ffmpeg, dan QuickJS. '
                        'Sidik jari Kenali lagu diport dari SongRec (GPL-3.0). '
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


/// Status izin notifikasi pemutar. Tanpa izin ini Android 13+ nggak
/// menampilkan kontrol putar/jeda di bilah notifikasi dan layar kunci.
class _BarisNotifikasi extends StatefulWidget {
  const _BarisNotifikasi();

  @override
  State<_BarisNotifikasi> createState() => _BarisNotifikasiState();
}

class _BarisNotifikasiState extends State<_BarisNotifikasi> with WidgetsBindingObserver {
  bool? _izin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cek();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Habis balik dari pengaturan Android, status perlu dibaca ulang.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _cek();
  }

  Future<void> _cek() async {
    bool ok;
    try {
      ok = await YtDlp.hasNotificationPermission();
    } catch (_) {
      ok = false;
    }
    if (mounted) setState(() => _izin = ok);
  }

  Future<void> _ketuk() async {
    if (_izin == true) {
      await YtDlp.openNotificationSettings();
      return;
    }
    // Coba dialog izin dulu. Kalau Android nggak mau nampilin lagi
    // (sudah ditolak), kirim ke pengaturan notifikasi app.
    final ok = await YtDlp.mintaIzinNotifikasi();
    await _cek();
    if (!ok && mounted && _izin != true) await YtDlp.openNotificationSettings();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _izin == true;
    return ListTile(
      leading: KotakIkon(
        ikon: ok ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
        nada: ok ? NadaIkon.mint : NadaIkon.peach,
        ukuran: 38,
      ),
      title: const Text('Notifikasi pemutar'),
      subtitle: Text(
        _izin == null
            ? 'Mengecek...'
            : ok
                ? 'Aktif. Kontrol putar muncul di notifikasi dan layar kunci.'
                : 'Mati. Ketuk buat mengizinkan supaya kontrol muncul di notifikasi dan layar kunci.',
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: context.mull.textSubtle),
      onTap: _ketuk,
    );
  }
}
