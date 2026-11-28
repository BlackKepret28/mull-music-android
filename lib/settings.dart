import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan app yang dipakai lintas layar, disimpan di disk.
///
/// Dibaca sekali waktu start lewat [muat]. Tiap perubahan langsung ditulis
/// (fire and forget) karena isinya cuma beberapa nilai kecil.
class AppSettings extends ChangeNotifier {
  AppSettings({this._prefs});

  static const _kKaca = 'glass';
  static const _kFormatAudio = 'audioFormat';
  static const _kUpdateTerakhir = 'ytdlpUpdatedAt';
  static const _kCekUpdate = 'checkAppUpdate';
  static const _kCekUpdateTerakhir = 'appUpdateCheckedAt';
  static const _kIkutUji = 'ikutUji';

  final SharedPreferences? _prefs;

  /// Baca pengaturan tersimpan. Aman dipanggil sebelum `runApp`.
  static Future<AppSettings> muat() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppSettings(prefs: prefs);
    s._glass = prefs.getBool(_kKaca) ?? true;
    s._formatAudio = prefs.getString(_kFormatAudio) ?? 'm4a';
    s._cekUpdate = prefs.getBool(_kCekUpdate) ?? true;
    s._ikutUji = prefs.getBool(_kIkutUji) ?? false;
    return s;
  }

  /// Efek kaca di bar bawah. Bisa dimatikan buat HP lemah.
  bool _glass = true;
  bool get glass => _glass;
  set glass(bool v) {
    if (v == _glass) return;
    _glass = v;
    _prefs?.setBool(_kKaca, v);
    notifyListeners();
  }

  /// Format audio pilihan waktu mengunduh: `m4a` atau `opus`.
  String _formatAudio = 'm4a';
  String get formatAudio => _formatAudio;
  set formatAudio(String v) {
    if (v == _formatAudio) return;
    _formatAudio = v;
    _prefs?.setString(_kFormatAudio, v);
    notifyListeners();
  }

  /// Cek versi baru Mull di GitHub waktu app dibuka (paling sering sehari sekali).
  bool _cekUpdate = true;
  bool get cekUpdate => _cekUpdate;
  set cekUpdate(bool v) {
    if (v == _cekUpdate) return;
    _cekUpdate = v;
    _prefs?.setBool(_kCekUpdate, v);
    notifyListeners();
  }

  /// Ikut build uji (pra-rilis `uji-N`) waktu cek update. Dibaca juga oleh
  /// UpdateService langsung dari penyimpanan dengan kunci yang sama.
  bool _ikutUji = false;
  bool get ikutUji => _ikutUji;
  set ikutUji(bool v) {
    if (v == _ikutUji) return;
    _ikutUji = v;
    _prefs?.setBool(_kIkutUji, v);
    notifyListeners();
  }

  /// Sudah waktunya cek update otomatis lagi? Sekalian dicatat waktunya.
  bool waktunyaCekUpdate() {
    if (!_cekUpdate) return false;
    final ms = _prefs?.getInt(_kCekUpdateTerakhir);
    final sekarang = DateTime.now();
    if (ms != null && sekarang.difference(DateTime.fromMillisecondsSinceEpoch(ms)) < const Duration(hours: 20)) {
      return false;
    }
    _prefs?.setInt(_kCekUpdateTerakhir, sekarang.millisecondsSinceEpoch);
    return true;
  }

  /// Kapan yt-dlp terakhir diperbarui, buat jadwal perbarui mingguan.
  DateTime? get ytdlpUpdatedAt {
    final ms = _prefs?.getInt(_kUpdateTerakhir);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  void tandaiYtDlpDiperbarui() {
    _prefs?.setInt(_kUpdateTerakhir, DateTime.now().millisecondsSinceEpoch);
  }

  /// yt-dlp cepat basi karena YouTube sering berubah. Lebih dari seminggu
  /// dianggap perlu diperbarui.
  bool get ytdlpPerluDiperbarui {
    final t = ytdlpUpdatedAt;
    if (t == null) return true;
    return DateTime.now().difference(t) > const Duration(days: 7);
  }
}

/// Bikin [AppSettings] kebaca dari mana aja lewat `SettingsScope.of(context)`.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({super.key, required AppSettings settings, required super.child})
      : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope tidak ketemu di atas widget ini');
    return scope!.notifier!;
  }
}
