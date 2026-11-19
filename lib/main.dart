import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app.dart';
import 'services/log_service.dart';
import 'services/player_service.dart';
import 'services/ytdlp_service.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Semua error Dart yang lolos dicatat ke berkas log (Pengaturan > Pemutar
  // > Diagnostik), jadi bisa dibaca walau app sempat crash.
  await LogService.instance.mulai();
  FlutterError.onError = (d) {
    LogService.instance.catat('flutter', d.exceptionAsString());
    FlutterError.presentError(d);
  };
  PlatformDispatcher.instance.onError = (e, s) {
    LogService.instance.catat('error', '$e\n$s');
    return true;
  };

  // Panasin shader kaca duluan. Tanpa ini, panel bawah sempat kedip polos
  // di frame-frame pertama.
  await LiquidGlassWidgets.initialize();

  final settings = await AppSettings.muat();

  // YouTube sering berubah, jadi yt-dlp diperbarui lagi kalau sudah lewat
  // seminggu. Dikerjakan di dalam ensureReady, bukan di sini, supaya start
  // app nggak kehalang jaringan.
  YtDlpService.instance
    ..perluUpdateBerkala = settings.ytdlpPerluDiperbarui
    ..onDiperbarui = settings.tandaiYtDlpDiperbarui;

  // Daftarkan pemutar ke sistem supaya notifikasi dan kontrol di layar kunci
  // langsung jalan begitu lagu pertama diputar.
  try {
    await initAudio();
  } catch (e, s) {
    LogService.instance.catat('init', 'initAudio GAGAL: $e\n$s');
  }

  runApp(
    LiquidGlassWidgets.wrap(
      // Turunkan mutu sendiri kalau frame mulai jatuh. HP target (Infinix
      // Note 30, Helio G99) nggak kuat kaca mutu penuh terus-terusan.
      adaptiveQuality: true,
      child: MullApp(settings: settings),
    ),
  );
}
