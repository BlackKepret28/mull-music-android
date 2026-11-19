import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/log_service.dart';
import '../services/player_service.dart';
import '../services/update_service.dart';
import '../ytdlp.dart';

/// Layar buat melacak kenapa notifikasi pemutar nggak muncul, dan buat
/// menyimpan log error. Cara pakai: putar lagu dulu, lalu buka layar ini.
class DiagnostikScreen extends StatefulWidget {
  const DiagnostikScreen({super.key});

  @override
  State<DiagnostikScreen> createState() => _DiagnostikScreenState();
}

class _DiagnostikScreenState extends State<DiagnostikScreen> {
  Map<String, dynamic>? _diag;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final d = await YtDlp.diagNotifikasi();
      if (mounted) {
        setState(() {
          _diag = d;
          _galat = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _galat = e.toString());
    }
  }

  static String _ya(Object? v) => v == true ? 'ya' : 'TIDAK';

  static String _daftar(Object? v) {
    final l = (v as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return l.isEmpty ? 'tidak ada' : l.join('\n    ');
  }

  List<String> _baris() {
    final d = _diag;
    if (d == null) return const [];
    final p = MullAudioHandler.instance.playbackState.value;
    final lagu = MullAudioHandler.instance.mediaItem.value;
    return [
      'Perangkat: ${d['perangkat']} (Android SDK ${d['sdk']})',
      'Notifikasi app diizinkan: ${_ya(d['notifAktif'])}',
      'Bebas pembatasan baterai: ${_ya(d['bebasBaterai'])}',
      'Layanan pemutar (AudioService) jalan: ${_ya(d['layananJalan'])}',
      'Status pemutar: playing=${p.playing}, proses=${p.processingState.name}',
      'Lagu di sesi media: ${lagu?.title ?? '-'}',
      'Kanal notifikasi:\n    ${_daftar(d['saluran'])}',
      'Notifikasi aktif:\n    ${_daftar(d['notifikasi'])}',
    ];
  }

  String _kesimpulan() {
    final d = _diag;
    if (d == null) return '';
    final p = MullAudioHandler.instance.playbackState.value;
    final jalan = d['layananJalan'] == true;
    final adaNotif = ((d['notifikasi'] as List?) ?? const []).isNotEmpty;
    if (d['notifAktif'] != true) {
      return 'Notifikasi untuk app ini dimatikan di pengaturan Android. Nyalakan dulu.';
    }
    if (!p.playing) return 'Putar lagu dulu, lalu ketuk Segarkan.';
    if (!jalan) {
      return 'Lagu bunyi tapi layanan pemutar TIDAK jalan. Ini bug di app: ketuk Bagikan log dan kirim ke Claude.';
    }
    if (!adaNotif) {
      return 'Layanan jalan tapi nggak ada notifikasi yang terpasang. Kemungkinan ditolak sistem (cek log sistem): ketuk Bagikan log.';
    }
    return 'Notifikasi pemutar ADA di sistem. Kalau belum kelihatan, cek kartu media di panel notifikasi atau layar kunci.';
  }

  Future<String> _laporan() async {
    await _muat();
    final b = StringBuffer('== Diagnostik Mull ==\n');
    try {
      b.writeln('Versi: ${await UpdateService.instance.versiLengkap()}');
    } catch (_) {}
    for (final l in _baris()) {
      b.writeln(l);
    }
    b
      ..writeln('\n== Log app ==')
      ..writeln(await LogService.instance.baca())
      ..writeln('\n== Log sistem (disaring) ==');
    try {
      b.writeln(await YtDlp.getLogcat());
    } catch (e) {
      b.writeln('(gagal membaca log sistem: $e)');
    }
    final s = b.toString();
    return s.length > 150000 ? s.substring(s.length - 150000) : s;
  }

  void _info(String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _tesNotifikasi() async {
    try {
      await YtDlp.testNotification();
      _info('Notifikasi tes dikirim. Tarik panel notifikasi dari atas.');
    } catch (e) {
      _info('Gagal mengirim notifikasi tes: $e');
    }
  }

  Future<void> _bagikan() async {
    final teks = await _laporan();
    await YtDlp.shareText(teks, title: 'Log Mull');
  }

  Future<void> _salin() async {
    final teks = await _laporan();
    await Clipboard.setData(ClipboardData(text: teks));
    _info('Log disalin. Tempel ke chat.');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final baris = _baris();
    final kesimpulan = _kesimpulan();
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostik pemutar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Putar satu lagu dulu, buka layar ini, lalu ketuk Segarkan. Kalau notifikasi tetap nggak muncul, ketuk Bagikan log dan kirim ke Claude.',
            style: tema.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (_galat != null) Text('Gagal membaca status: $_galat', style: tema.bodyMedium),
          for (final l in baris)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText(l, style: tema.bodyMedium),
            ),
          if (kesimpulan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(kesimpulan, style: tema.titleSmall),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonal(onPressed: _muat, child: const Text('Segarkan')),
              FilledButton.tonal(onPressed: _tesNotifikasi, child: const Text('Kirim notifikasi tes')),
              FilledButton(onPressed: _bagikan, child: const Text('Bagikan log')),
              OutlinedButton(onPressed: _salin, child: const Text('Salin log')),
            ],
          ),
        ],
      ),
    );
  }
}
