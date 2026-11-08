import 'package:flutter/material.dart';

import 'settings.dart';
import 'shell.dart';
import 'theme.dart';

class MullApp extends StatefulWidget {
  const MullApp({super.key});

  @override
  State<MullApp> createState() => _MullAppState();
}

class _MullAppState extends State<MullApp> {
  final _settings = AppSettings();

  @override
  void dispose() {
    _settings.dispose();
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
