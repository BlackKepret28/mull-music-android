import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../settings.dart';
import '../theme.dart';

/// Panel kaca cair (MsaGlass). KHUSUS buat kontrol yang melayang di atas
/// konten: navigasi bawah, bar pemutar mini, header halaman, tombol bulat.
/// Jangan dipakai buat item daftar; itu tugas [KartuMull] yang solid.
///
/// Setelan kacanya ikut engine MSA (`glass_engine_liquid.dart`). Kalau
/// Pengaturan > Efek kaca dimatikan, atau sistem minta "kurangi animasi" /
/// kontras tinggi, panel ini jadi kartu pekat dengan garis tepi dan sudut
/// yang sama, cuma tanpa blur.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = MullUkuran.panel,
    this.quality = GlassQuality.standard,
    this.padding,
    this.width,
    this.height,
  });

  final Widget child;
  final double radius;
  final GlassQuality quality;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  static bool nyala(BuildContext context) =>
      SettingsScope.of(context).glass &&
      !MediaQuery.disableAnimationsOf(context) &&
      !MediaQuery.highContrastOf(context);

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final gelap = context.gelap;
    final isi = padding == null ? child : Padding(padding: padding!, child: child);

    if (!nyala(context)) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: c.surfaceSolid,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 26)],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: isi),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: AdaptiveGlass(
          shape: LiquidRoundedSuperellipse(borderRadius: radius),
          quality: quality,
          settings: LiquidGlassSettings(
            // Angka dari engine kaca MSA.
            glassColor: c.glassTint,
            thickness: 22,
            blur: gelap ? 14 : 12,
            lightIntensity: gelap ? 0.45 : 0.7,
            saturation: 1.6,
            refractiveIndex: 1.2,
            chromaticAberration: 0.008,
            // Tambahan Mull: lapisan dasar semi-pekat. Di MSA kaca melayang di
            // atas latar pastel polos, di Mull sering di atas sampul terang.
            // Tanpa ini label navigasi hilang (kejadian di Infinix, 9 Nov).
            backerColor: gelap ? const Color(0xB30B0D12) : const Color(0xB3F6F7FB),
            frost: gelap ? 0.3 : 0.35,
            specularSharpness: GlassSpecularSharpness.soft,
          ),
          child: isi,
        ),
      ),
    );
  }
}
