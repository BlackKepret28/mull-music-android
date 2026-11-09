import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';

/// Riwayat putar, buat rak "Baru diputar" di Beranda.
///
/// Sepadan dengan `recent.json` versi Windows: satu entri per lagu, yang
/// terbaru di atas, lagu yang diputar ulang naik lagi ke atas (bukan dobel).
class RecentService extends ChangeNotifier {
  RecentService._();
  static final instance = RecentService._();

  /// Instance bersih buat tes, boleh diarahkan ke folder sementara.
  @visibleForTesting
  factory RecentService.baru({Directory? folder}) {
    final s = RecentService._();
    s._folderTes = folder;
    return s;
  }

  static const _maks = 50;

  Directory? _folderTes;
  List<Track> _daftar = [];
  bool _sudahMuat = false;

  List<Track> get daftar => List.unmodifiable(_daftar);
  bool get sudahMuat => _sudahMuat;

  Future<File> _berkas() async {
    final dasar = _folderTes ?? await getApplicationSupportDirectory();
    if (!await dasar.exists()) await dasar.create(recursive: true);
    return File('${dasar.path}/recent.json');
  }

  Future<void> muat() async {
    try {
      final f = await _berkas();
      if (await f.exists()) {
        final isi = jsonDecode(await f.readAsString());
        final list = (isi is Map ? isi['items'] : null) as List?;
        _daftar = (list ?? const [])
            .whereType<Map>()
            .map((e) => Track.fromJson(Map<String, dynamic>.from(e)))
            .where((t) => t.id.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Berkas rusak: mulai dari kosong daripada bikin Beranda gagal.
      _daftar = [];
    } finally {
      _sudahMuat = true;
      notifyListeners();
    }
  }

  /// Catat satu lagu sebagai baru diputar.
  Future<void> catat(Track t) async {
    if (t.id.isEmpty) return;
    if (!_sudahMuat) await muat();

    _daftar
      ..removeWhere((e) => e.id == t.id)
      ..insert(0, t);
    if (_daftar.length > _maks) _daftar = _daftar.sublist(0, _maks);

    notifyListeners();
    await _simpan();
  }

  Future<void> bersihkan() async {
    _daftar = [];
    notifyListeners();
    await _simpan();
  }

  Future<void> _simpan() async {
    try {
      final f = await _berkas();
      await f.writeAsString(
        jsonEncode({'items': _daftar.map((t) => t.toJson()).toList()}),
      );
    } catch (_) {
      // Gagal nulis: isi di memori tetap benar sampai app ditutup.
    }
  }
}
