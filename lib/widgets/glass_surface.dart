import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../settings.dart';

/// Panel kaca cair. Dipakai buat bar bawah (navigasi + pemutar mini).
///
/// Kalau Pengaturan > Efek kaca dimatikan, atau sistem minta "kurangi
/// transparansi", panel ini balik jadi permukaan biasa. Jadi di HP lemah
/// atau buat yang nggak nyaman, tampilannya tetap waras.
///
/// Supaya efeknya kelihatan, isi halaman harus lewat DI BAWAH panel ini
/// (`Scaffold(extendBody: true)`), bukan berhenti di atasnya.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.quality = GlassQuality.standard,
  });

  final Widget child;
  final double radius;
  final GlassQuality quality;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gelap = Theme.of(context).brightness == Brightness.dark;

    final nyala = SettingsScope.of(context).glass &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.highContrastOf(context);

    if (!nyala) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(color: cs.surfaceContainer, child: child),
      );
    }

    return AdaptiveGlass(
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      quality: quality,
      // Sengaja kalem: pembiasan tipis, tanpa pelangi berlebihan.
      // Angka besar bikin teks di belakangnya susah dibaca.
      settings: LiquidGlassSettings(
        blur: gelap ? 18 : 16,
        thickness: 14,
        // Lapisan dasar semi-pekat. Tanpa ini label navigasi hilang waktu
        // ada sampul terang lewat di belakang panel (kejadian di Infinix).
        backerColor: gelap ? const Color(0xCC14161A) : const Color(0xCCF7F8FA),
        glassColor: gelap
            ? const Color(0x1AFFFFFF)
            : const Color(0x14FFFFFF),
        frost: gelap ? 0.42 : 0.48,
        chromaticAberration: 0.004,
        refractiveIndex: 1.15,
        saturation: 1.1,
        lightIntensity: gelap ? 0.35 : 0.5,
        glowIntensity: 0.3,
        specularSharpness: GlassSpecularSharpness.soft,
      ),
      child: child,
    );
  }
}
