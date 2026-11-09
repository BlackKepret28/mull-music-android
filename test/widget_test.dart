import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/app.dart';

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

  testWidgets('Kerangka: empat tab tampil, Beranda yang kebuka duluan', (tester) async {
    await tester.pumpWidget(const MullApp());
    await tester.pumpAndSettle();

    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Cari'), findsOneWidget);
    expect(find.text('Pustaka'), findsOneWidget);
    expect(find.text('Unduhan'), findsOneWidget);

    // Beranda masih kosong, jadi yang muncul keadaan kosongnya.
    expect(find.text('Belum ada apa-apa di sini'), findsOneWidget);
  });

  testWidgets('Tombol "Mulai cari" di Beranda pindah ke tab Cari', (tester) async {
    await tester.pumpWidget(const MullApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Mulai cari'));
    await tester.pumpAndSettle();

    expect(find.text('Mau dengar apa?'), findsOneWidget);
  });

  testWidgets('Navigasi bawah pindah ke Pustaka', (tester) async {
    await tester.pumpWidget(const MullApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pustaka'));
    await tester.pumpAndSettle();

    expect(find.text('Lagu'), findsOneWidget);
    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('Belum ada lagu'), findsOneWidget);
  });

  testWidgets('Navigasi bawah pindah ke Unduhan', (tester) async {
    await tester.pumpWidget(const MullApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unduhan'));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada unduhan'), findsOneWidget);
  });

  testWidgets('Bar pemutar mini belum muncul karena belum ada yang diputar', (tester) async {
    await tester.pumpWidget(const MullApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Putar'), findsNothing);
  });
}
