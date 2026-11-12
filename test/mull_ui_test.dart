import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/screens/home_screen.dart';
import 'package:mullmusic/services/cover_color.dart';
import 'package:mullmusic/settings.dart';
import 'package:mullmusic/theme.dart';
import 'package:mullmusic/widgets/glass_surface.dart';
import 'package:mullmusic/widgets/mull_ui.dart';

Widget _bungkus(Widget child, {AppSettings? settings, ThemeData? tema}) => SettingsScope(
      settings: settings ?? AppSettings(),
      child: MaterialApp(theme: tema ?? MullTheme.light(), home: Scaffold(body: child)),
    );

void main() {
  group('Beranda', () {
    test('tanggal ditulis dalam bahasa Indonesia', () {
      expect(HomeScreen.tanggal(DateTime(2026, 11, 12)), 'Kamis, 12 November');
      expect(HomeScreen.tanggal(DateTime(2026, 1, 4)), 'Minggu, 4 Januari');
    });

    test('salam ikut jam, aturannya sama dengan versi Windows', () {
      expect(HomeScreen.salam(DateTime(2026, 1, 1, 3)), 'Selamat malam');
      expect(HomeScreen.salam(DateTime(2026, 1, 1, 4)), 'Selamat pagi');
      expect(HomeScreen.salam(DateTime(2026, 1, 1, 11)), 'Selamat siang');
      expect(HomeScreen.salam(DateTime(2026, 1, 1, 15)), 'Selamat sore');
      expect(HomeScreen.salam(DateTime(2026, 1, 1, 19)), 'Selamat malam');
    });
  });

  group('Tema', () {
    test('aksen tetap violet Mull, sisanya nilai MSA', () {
      expect(MullColors.light.accent, const Color(0xFF6344FB));
      expect(MullColors.dark.accent, const Color(0xFF8B7CFF));
      expect(MullColors.light.bg, const Color(0xFFF6F7FB));
      expect(MullColors.dark.surfaceSolid, const Color(0xFF171B25));
    });

    test('font Plus Jakarta Sans dipasang di tema', () {
      expect(MullTheme.light().textTheme.bodyMedium?.fontFamily, MullTheme.font);
    });
  });

  group('Latar', () {
    test('cahaya dari sampul: pucat di tema terang, redup di tema gelap', () {
      const merah = Color(0xFFD32F2F);
      final terang = LatarMull.cahayaDari(merah, false);
      final gelap = LatarMull.cahayaDari(merah, true);
      expect(terang, hasLength(4));
      expect(gelap, hasLength(4));
      for (final w in terang) {
        expect(HSLColor.fromColor(w).lightness, closeTo(0.84, 0.01));
      }
      for (final w in gelap) {
        expect(HSLColor.fromColor(w).lightness, closeTo(0.32, 0.01));
      }
    });
  });

  group('Kaca', () {
    testWidgets('efek kaca mati: panel jadi kartu pekat bergaris tepi, bentuknya sama', (tester) async {
      final s = AppSettings()..glass = false;
      await tester.pumpWidget(_bungkus(
        const GlassSurface(radius: 30, child: SizedBox(width: 100, height: 40)),
        settings: s,
      ));

      final kotak = tester.widget<Container>(
        find.descendant(of: find.byType(GlassSurface), matching: find.byType(Container)).first,
      );
      final hias = kotak.decoration! as BoxDecoration;
      expect(hias.color, MullColors.light.surfaceSolid);
      expect(hias.border, isNotNull);
      expect(hias.borderRadius, BorderRadius.circular(30));
    });

    testWidgets('header kaca: isi didorong ke bawah setinggi header', (tester) async {
      final s = AppSettings()..glass = false;
      late EdgeInsets dipakai;
      await tester.pumpWidget(_bungkus(
        HalamanKaca(
          header: const HeaderKaca(judul: 'Pustaka', subjudul: '3 lagu', bawah: SizedBox(height: 44)),
          isi: (context, padding) {
            dipakai = padding;
            return const SizedBox.expand();
          },
        ),
        settings: s,
      ));
      await tester.pumpAndSettle();

      final tinggiHeader = tester.getSize(find.byType(HeaderKaca)).height;
      expect(find.text('Pustaka'), findsOneWidget);
      expect(find.text('3 lagu'), findsOneWidget);
      expect(dipakai.top, greaterThanOrEqualTo(tinggiHeader));
    });
  });

  group('CoverColor', () {
    test('pilih warna pekat, bukan hitam/putih yang lebih banyak', () {
      // 60 piksel hitam, 30 putih, 10 biru: yang mewakili ya birunya.
      final px = <int>[];
      for (var i = 0; i < 60; i++) {
        px.addAll([5, 5, 5, 255]);
      }
      for (var i = 0; i < 30; i++) {
        px.addAll([250, 250, 250, 255]);
      }
      for (var i = 0; i < 10; i++) {
        px.addAll([30, 90, 220, 255]);
      }
      final w = CoverColor.dominanUntukTes(Uint8List.fromList(px))!;
      expect((w.b * 255).round(), greaterThan(200));
      expect((w.r * 255).round(), lessThan(60));
    });

    test('sampul kosong atau url null: tanpa warna', () async {
      expect(await CoverColor.dari(null), isNull);
      expect(await CoverColor.dari(''), isNull);
    });
  });
}
