import 'package:flutter/material.dart';

import 'settings.dart';
import 'shell.dart';
import 'theme.dart';

class MullApp extends StatefulWidget {
  const MullApp({super.key, this.settings});

  /// Pengaturan yang sudah dibaca dari disk. Kalau null (mis. di tes),
  /// dipakai pengaturan bawaan yang nggak disimpan ke mana-mana.
  final AppSettings? settings;

  @override
  State<MullApp> createState() => _MullAppState();
}

class _MullAppState extends State<MullApp> {
  late final AppSettings _settings = widget.settings ?? AppSettings();
  late final bool _punyaSendiri = widget.settings == null;

  @override
  void dispose() {
    if (_punyaSendiri) _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: _settings,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) => MaterialApp(
          title: 'Mull Music',
          debugShowCheckedModeBanner: false,
          themeMode: _settings.themeMode,
          theme: MullTheme.light(),
          darkTheme: MullTheme.dark(),
          home: const AppShell(),
        ),
      ),
    );
  }
}
