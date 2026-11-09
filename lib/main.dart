import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app.dart';
import 'services/player_service.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Panasin shader kaca duluan. Tanpa ini, panel bawah sempat kedip polos
  // di frame-frame pertama.
  await LiquidGlassWidgets.initialize();

  final settings = await AppSettings.muat();

  // Daftarkan pemutar ke sistem supaya notifikasi dan kontrol di layar kunci
  // langsung jalan begitu lagu pertama diputar.
  await initAudio();

  runApp(
    LiquidGlassWidgets.wrap(
      // Turunkan mutu sendiri kalau frame mulai jatuh. HP target (Infinix
      // Note 30, Helio G99) nggak kuat kaca mutu penuh terus-terusan.
      adaptiveQuality: true,
      child: MullApp(settings: settings),
    ),
  );
}
