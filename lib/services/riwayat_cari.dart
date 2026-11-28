import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 20 pencarian terakhir (terbaru di atas), disimpan di HP. Tautan nggak
/// dicatat.
class RiwayatCari extends ChangeNotifier {
  RiwayatCari._();
  static final instance = RiwayatCari._();

  static const _kunci = 'riwayatCari';
  static const _maks = 20;

  List<String> _daftar = [];
  bool _sudahMuat = false;

  List<String> get daftar => List.unmodifiable(_daftar);

  Future<void> muat() async {
    if (_sudahMuat) return;
    _sudahMuat = true;
    final prefs = await SharedPreferences.getInstance();
    _daftar = prefs.getStringList(_kunci) ?? [];
    notifyListeners();
  }

  Future<void> catat(String q) async {
    final teks = q.trim();
    if (teks.isEmpty) return;
    _daftar.removeWhere((e) => e.toLowerCase() == teks.toLowerCase());
    _daftar.insert(0, teks);
    if (_daftar.length > _maks) _daftar = _daftar.sublist(0, _maks);
    notifyListeners();
    await _simpan();
  }

  Future<void> hapus(String q) async {
    _daftar.removeWhere((e) => e == q);
    notifyListeners();
    await _simpan();
  }

  Future<void> kosongkan() async {
    _daftar = [];
    notifyListeners();
    await _simpan();
  }

  Future<void> _simpan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kunci, _daftar);
  }
}
