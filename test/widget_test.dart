import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/app.dart';
import 'package:mullmusic/widgets/bottom_nav.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mull/ytdlp');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    // Sisi native nggak ada di tes widget, jadi dipalsukan seperlunya.
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'init' => {'ms': 1},
        'version' => {'version': '2026.10.26'},
        'listLibrary' => {'items': <Object?>[]},
        'ensureNotificationPermission' => {'granted': true},
        _ => null,
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  /// "Pustaka" dan "Cari lagu" juga muncul di petak akses cepat Beranda,
  /// jadi tombol navigasinya harus dicari di dalam [BottomNav].
  Finder tombolNav(String label) => find.descendant(
        of: find.byType(BottomNav),
        matching: find.text(label),
      );

  testWidgets('Kerangka: empat tab tampil, Beranda yang kebuka duluan', (tester) async {
    await tester.pumpWidget(const MullApp());
    await tester.pumpAndSettle();

    expect(tombolNav('Beranda'), findsOneWidget);
    expect(tombolNav('Cari'), findsOneWidget);
    expect(tombolNav('Pustaka'), findsOneWidget);
    expect(tombolNav('Unduhan'), findsOneWidget);

    // Belum ada riwayat, unduhan, atau playlist: sambutannya yang muncul.
    expect(find.text('Mulai dari sini'), findsOneWidget);
  });

  testWidgets('Beranda punya salam dan kartu tempel tautan', (tester) async {
    await tester.pumpWidget(const MullApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Selamat '), findsOneWidget);
    expect(find.text('Putar dari tautan'), findsOneWidget);
  });

  testWidgets('Tombol "Cari lagu" di sambutan pindah ke tab Cari', (tester) async {
    await tester.pumpWidget(const MullApp());
    await tester.pumpAndSettle();

    // Beranda sekarang panjang (salam, petak, kartu tempel, sambutan), jadi
    // tombolnya digulir dulu sampai kelihatan.
    final tombol = find.widgetWithText(FilledButton, 'Cari lagu');
    await tester.ensureVisible(tombol);
    await tester.pumpAndSettle();
    await tester.tap(tombol);
    await tester.pumpAndSettle();

    expect(find.text('Mau dengar apa?'), findsOneWidget);
  });

  testWidgets('Navigasi bawah pindah ke Pustaka', (tester) async {
    await tester.pumpWidget(const MullApp());
    await tester.pumpAndSettle();

    await tester.tap(tombolNav('Pustaka'));
    await tester.pumpAndSettle();

    expect(find.text('Lagu'), findsOneWidget);
    expect(find.text('Playlist'), findsWidgets);
    expect(find.text('Belum ada lagu'), findsOneWidget);
  });

  testWidgets('Pustaka: pemilih pil pindah ke tab Video', (tester) async {
    await tester.pumpWidget(const MullApp());
    await tester.pumpAndSettle();

    await tester.tap(tombolNav('Pustaka'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada video'), findsOneWidget);
  });

  testWidgets('Navigasi bawah pindah ke Unduhan', (tester) async {
    await tester.pumpWidget(const MullApp());
    await tester.pumpAndSettle();

    await tester.tap(tombolNav('Unduhan'));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada unduhan'), findsOneWidget);
  });

  testWidgets('Bar pemutar mini belum muncul karena belum ada yang diputar', (tester) async {
    await tester.pumpWidget(const MullApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Putar'), findsNothing);
  });
}
