import 'package:flutter/material.dart';

/// Token warna Mull. Diakses lewat `context.mull`.
///
/// Nilainya disalin PERSIS dari app MSA milik Mulya
/// (`my_secret_app/lib/core/theme/app_colors.dart`): latar putih keabuan
/// dengan cahaya pastel, kartu solid yang kalem, kaca cuma buat kontrol yang
/// melayang. Bedanya cuma satu: aksennya violet Mull (sama dengan `--accent`
/// versi Windows, #8B7CFF di tema gelap), bukan biru MSA. Mull cuma punya
/// tema gelap (diputuskan 17 Nov 2026).
@immutable
class MullColors extends ThemeExtension<MullColors> {
  const MullColors({
    required this.bg,
    required this.surface,
    required this.surfaceSolid,
    required this.border,
    required this.divider,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.icon,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.onAccent,
    required this.warning,
    required this.warningSoft,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.violet,
    required this.violetSoft,
    required this.checkBorder,
    required this.track,
    required this.chipBg,
    required this.glassTint,
    required this.glassBorder,
    required this.shadow,
    required this.cardShadow,
    required this.snackBg,
    required this.blobBlue,
    required this.blobLavender,
    required this.blobPeach,
    required this.blobMint,
    required this.blobOpacity,
  });

  final Color bg;

  /// Isi kartu (sedikit tembus, biar cahaya pastel samar kelihatan).
  final Color surface;
  final Color surfaceSolid;
  final Color border;
  final Color divider;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color icon;
  final Color accent;

  /// Aksen buat teks/ikon di atas latar terang-lembut (tautan "Lihat semua",
  /// label tab aktif). Di tema gelap lebih muda supaya kebaca.
  final Color accentStrong;
  final Color accentSoft;
  final Color onAccent;
  final Color warning;
  final Color warningSoft;
  final Color success;
  final Color successSoft;
  final Color danger;
  final Color dangerSoft;
  final Color violet;
  final Color violetSoft;
  final Color checkBorder;
  final Color track;
  final Color chipBg;
  final Color glassTint;
  final Color glassBorder;
  final Color shadow;
  final Color cardShadow;
  final Color snackBg;
  final Color blobBlue;
  final Color blobLavender;
  final Color blobPeach;
  final Color blobMint;
  final double blobOpacity;

  static const dark = MullColors(
    bg: Color(0xFF0B0D12),
    surface: Color(0xD6171B25),
    surfaceSolid: Color(0xFF171B25),
    border: Color(0x14FFFFFF),
    divider: Color(0x14FFFFFF),
    text: Color(0xFFEEF1F7),
    textMuted: Color(0xFFA3ACBD),
    textSubtle: Color(0xFF8D96A8),
    icon: Color(0xFFC9D0DC),
    accent: Color(0xFF8B7CFF),
    accentStrong: Color(0xFFC4BBFF),
    accentSoft: Color(0x338B7CFF),
    // Teks gelap di atas violet muda: putih cuma 3,2:1 di sini, kurang kebaca.
    onAccent: Color(0xFF0F0B24),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0x29F59E0B),
    success: Color(0xFF34D399),
    successSoft: Color(0x2934D399),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0x29F87171),
    violet: Color(0xFFC4B5FD),
    violetSoft: Color(0x29A78BFA),
    checkBorder: Color(0xFF4B5466),
    track: Color(0x1AFFFFFF),
    chipBg: Color(0x14FFFFFF),
    glassTint: Color(0x1FFFFFFF),
    glassBorder: Color(0x26FFFFFF),
    shadow: Color(0x73000000),
    cardShadow: Color(0x40000000),
    snackBg: Color(0xFF262B38),
    blobBlue: Color(0xFF2B4C9B),
    blobLavender: Color(0xFF4A3A8C),
    blobPeach: Color(0xFF5A3270),
    blobMint: Color(0xFF1F5E55),
    blobOpacity: 0.6,
  );

  /// Pasangan (latar lembut, warna ikon) buat kotak ikon pastel ala MSA.
  (Color, Color) nada(NadaIkon n) => switch (n) {
        NadaIkon.aksen => (accentSoft, accentStrong),
        NadaIkon.mint => (successSoft, success),
        NadaIkon.lavender => (violetSoft, violet),
        NadaIkon.peach => (warningSoft, warning),
      };

  @override
  MullColors copyWith() => this;

  @override
  MullColors lerp(ThemeExtension<MullColors>? other, double t) {
    if (other is! MullColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// Warna kotak ikon. MSA: mint buat dompet, lavender buat film/tautan, dst.
enum NadaIkon { aksen, mint, lavender, peach }

extension MullThemeContext on BuildContext {
  MullColors get mull => Theme.of(this).extension<MullColors>() ?? MullColors.dark;
  bool get gelap => Theme.of(this).brightness == Brightness.dark;
}

/// Ukuran yang dipakai berulang. Angkanya dari komponen MSA.
abstract final class MullUkuran {
  /// Kartu konten (MsaCard).
  static const kartu = 22.0;

  /// Panel kaca besar (header halaman, MsaGlass bawaan).
  static const panel = 28.0;

  /// Sampul di dalam kartu.
  static const sampul = 16.0;

  /// Jarak tepi layar.
  static const tepi = 16.0;
}

abstract final class MullTheme {
  static const font = 'PlusJakartaSans';

  static ThemeData dark() => _build(MullColors.dark, Brightness.dark);

  static ThemeData _build(MullColors c, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness).copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      surface: c.bg,
      onSurface: c.text,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.surfaceSolid,
      surfaceContainer: c.chipBg,
      surfaceContainerHigh: c.surfaceSolid,
      surfaceContainerHighest: c.surfaceSolid,
      onSurfaceVariant: c.textMuted,
      outline: c.checkBorder,
      outlineVariant: c.border,
      error: c.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: font,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.divider,
      splashFactory: InkRipple.splashFactory,
      extensions: <ThemeExtension<dynamic>>[c],
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.25),
        selectionHandleColor: c.accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: c.text,
        titleTextStyle: TextStyle(
          fontFamily: font,
          color: c.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MullUkuran.kartu),
          side: BorderSide(color: c.border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.icon,
        textColor: c.text,
        titleTextStyle: TextStyle(fontFamily: font, color: c.text, fontSize: 15, fontWeight: FontWeight.w600),
        subtitleTextStyle: TextStyle(fontFamily: font, color: c.textMuted, fontSize: 13, height: 1.35),
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.icon),
      // Tombol pil (MsaPillButton): utama = aksen solid, sekunder = abu chip.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: c.chipBg,
          foregroundColor: c.text,
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentStrong,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontFamily: font, fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
      // Kolom isian MsaInput: kotak putih bersudut 14, garis tipis.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceSolid,
        hintStyle: TextStyle(fontFamily: font, color: c.textSubtle, fontSize: 15, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.checkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brightness == Brightness.dark ? const Color(0xFF353B4A) : const Color(0xFFDCE1EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: c.accent,
        inactiveTrackColor: c.track,
        thumbColor: c.accent,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent, linearTrackColor: c.track),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onAccent : c.surfaceSolid,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.track,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.checkBorder,
        ),
      ),
      // Snackbar MSA: pil gelap melayang, teks putih tebal.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: c.snackBg,
        actionTextColor: const Color(0xFFC4BBFF),
        contentTextStyle: const TextStyle(
          fontFamily: font,
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Lembar bawah ala msa_sheets: kartu pekat bersudut 30, melayang.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceSolid,
        modalBackgroundColor: c.surfaceSolid,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: Colors.black.withValues(alpha: 0.3),
        dragHandleColor: c.checkBorder,
        dragHandleSize: const Size(40, 5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceSolid,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: c.border),
        ),
        titleTextStyle: TextStyle(
          fontFamily: font,
          color: c.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        contentTextStyle: TextStyle(fontFamily: font, color: c.textMuted, fontSize: 14, height: 1.45),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceSolid,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: c.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border),
        ),
        textStyle: TextStyle(fontFamily: font, color: c.text, fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.snackBg, borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: font, color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: _TransisiMsa()},
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(fontFamily: font, bodyColor: c.text, displayColor: c.text)
          .copyWith(
            titleMedium: TextStyle(fontFamily: font, color: c.text, fontSize: 16, fontWeight: FontWeight.w700),
            bodyMedium: TextStyle(fontFamily: font, color: c.text, fontSize: 14.5),
            bodySmall: TextStyle(fontFamily: font, color: c.textMuted, fontSize: 13, height: 1.4),
          ),
    );
  }
}

/// Transisi halaman MSA (`msa_route.dart`): pudar + geser sedikit dari bawah.
class _TransisiMsa extends PageTransitionsBuilder {
  const _TransisiMsa();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
