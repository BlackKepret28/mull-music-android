import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Catatan kejadian app, disimpan ke berkas supaya masih ada setelah app
/// ditutup atau crash. Dibaca lewat Pengaturan > Pemutar > Diagnostik.
/// Berkasnya dipangkas sendiri kalau lebih dari ~300 KB.
class LogService {
  LogService._();
  static final instance = LogService._();

  static const _batas = 300000;

  final _baris = <String>[];
  File? _berkas;

  Future<void> mulai() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/mull-log.txt');
      if (await f.exists() && await f.length() > _batas) await f.delete();
      _berkas = f;
      catat('app', '--- app dibuka ---');
    } catch (_) {
      // Tanpa berkas, log tetap jalan di memori.
    }
  }

  void catat(String tag, String pesan) {
    final t = DateTime.now().toIso8601String().substring(11, 23);
    final baris = '$t [$tag] $pesan';
    _baris.add(baris);
    if (_baris.length > 600) _baris.removeAt(0);
    _berkas?.writeAsString('$baris\n', mode: FileMode.append).ignore();
  }

  /// Isi log: sisa sesi sebelumnya + sesi ini (dari berkas), atau memori
  /// kalau berkasnya nggak bisa dibaca.
  Future<String> baca() async {
    try {
      final f = _berkas;
      if (f != null && await f.exists()) {
        final teks = await f.readAsString();
        return teks.length > 80000 ? teks.substring(teks.length - 80000) : teks;
      }
    } catch (_) {}
    return _baris.join('\n');
  }
}
