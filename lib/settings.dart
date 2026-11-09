import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan app yang dipakai lintas layar, disimpan di disk.
///
/// Dibaca sekali waktu start lewat [muat]. Tiap perubahan langsung ditulis
/// (fire and forget) karena isinya cuma beberapa nilai kecil.
class AppSettings extends ChangeNotifier {
  AppSettings({this._prefs});

  static const _kTema = 'themeMode';
  static const _kKaca = 'glass';
  static const _kFormatAudio = 'audioFormat';
  static const _kUpdateTerakhir = 'ytdlpUpdatedAt';

  final SharedPreferences? _prefs;

  /// Baca pengaturan tersimpan. Aman dipanggil sebelum `runApp`.
  static Future<AppSettings> muat() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppSettings(prefs: prefs);
    s._themeMode = switch (prefs.getString(_kTema)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    s._glass = prefs.getBool(_kKaca) ?? true;
    s._formatAudio = prefs.getString(_kFormatAudio) ?? 'm4a';
    return s;
  }

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode v) {
    if (v == _themeMode) return;
    _themeMode = v;
    _prefs?.setString(_kTema, switch (v) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
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
