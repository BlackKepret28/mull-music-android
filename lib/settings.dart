import 'package:flutter/material.dart';

/// Pengaturan app yang dipakai lintas layar.
///
/// Belum disimpan ke disk: begitu app ditutup, pilihannya balik ke bawaan.
/// Penyimpanan (shared_preferences) nyusul di commit berikutnya.
class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode v) {
    if (v == _themeMode) return;
    _themeMode = v;
    notifyListeners();
  }

  /// Efek kaca di bar pemutar dan navigasi. Bisa dimatikan buat HP lemah.
  bool _glass = true;
  bool get glass => _glass;
  set glass(bool v) {
    if (v == _glass) return;
    _glass = v;
    notifyListeners();
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
