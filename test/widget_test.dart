import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mullmusic/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Channel native nggak ada di test, jadi dipalsukan.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('mull/ytdlp'),
      (call) async => call.method == 'launchArgs' ? {'autorun': false} : null,
    );
  });

  testWidgets('Layar spike tampil dengan tombol tes', (tester) async {
    await tester.pumpWidget(const SpikeApp());
    await tester.pump();
    expect(find.text('Mull Music: uji yt-dlp'), findsOneWidget);
    expect(find.text('Jalankan semua tes'), findsOneWidget);
  });
}
