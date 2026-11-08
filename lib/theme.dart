import 'package:flutter/material.dart';

/// Palet Mull. Aksen violet, sama dengan versi Windows
/// (`--accent` di `ui/shell.css`: #6344FB terang, #8B7CFF gelap).
abstract final class MullColors {
  static const seed = Color(0xFF6344FB);

  static const accentLight = Color(0xFF6344FB);
  static const accentDark = Color(0xFF8B7CFF);

  /// Latar paling bawah.
  static const bgLight = Color(0xFFFFFFFF);
  static const bgDark = Color(0xFF0B0C0E);

  /// Kartu, bar, panel.
  static const cardLight = Color(0xFFF4F5F7);
  static const cardDark = Color(0xFF1F2125);

  static const inkLight = Color(0xFF1F2125);
  static const inkDark = Color(0xFFF4F5F7);

  static const dimLight = Color(0xFF6E747E);
  static const dimDark = Color(0xFF9AA0AA);
}

abstract final class MullTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final accent = dark ? MullColors.accentDark : MullColors.accentLight;
    final bg = dark ? MullColors.bgDark : MullColors.bgLight;
    final card = dark ? MullColors.cardDark : MullColors.cardLight;
    final ink = dark ? MullColors.inkDark : MullColors.inkLight;
    final dim = dark ? MullColors.dimDark : MullColors.dimLight;

    final scheme = ColorScheme.fromSeed(
      seedColor: MullColors.seed,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: dark ? const Color(0xFF0F0B24) : Colors.white,
      surface: bg,
      onSurface: ink,
      surfaceContainerLowest: bg,
      surfaceContainer: card,
      surfaceContainerHighest: card,
      onSurfaceVariant: dim,
      outlineVariant: dark ? Colors.white12 : Colors.black12,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      // Tanpa splash ungu di mana-mana; biar kalem.
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? MullColors.bgDark : MullColors.bgLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? accent : dim,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11.5,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? accent : dim,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: dim,
        textColor: ink,
        titleTextStyle: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w500),
        subtitleTextStyle: TextStyle(color: dim, fontSize: 13),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? Colors.white12 : Colors.black12,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: ink),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: TextStyle(color: dim, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: card,
        contentTextStyle: TextStyle(color: ink, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .black
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            titleMedium: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w600),
            bodyMedium: TextStyle(color: ink, fontSize: 14.5),
            bodySmall: TextStyle(color: dim, fontSize: 13),
          ),
    );
  }
}
