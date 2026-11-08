import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/models/track.dart';
import 'package:mullmusic/theme.dart';
import 'package:mullmusic/widgets/mini_player.dart';

const _lagu = Track(
  id: 'owrhKIN3Y90',
  title: 'Carefree',
  artist: 'Kevin MacLeod',
);

Widget _bungkus(Widget child) => MaterialApp(
      theme: MullTheme.dark(),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('tampilkan judul dan artis, tombol Putar waktu jeda', (tester) async {
    await tester.pumpWidget(_bungkus(
      const MiniPlayer(track: _lagu, playing: false),
    ));

    expect(find.text('Carefree'), findsOneWidget);
    expect(find.text('Kevin MacLeod'), findsOneWidget);
    expect(find.byTooltip('Putar'), findsOneWidget);
  });

  testWidgets('tombol jadi Jeda waktu sedang diputar', (tester) async {
    await tester.pumpWidget(_bungkus(
      const MiniPlayer(track: _lagu, playing: true),
    ));

    expect(find.byTooltip('Jeda'), findsOneWidget);
  });

  testWidgets('waktu menyiapkan: artis diganti teks status dan tombol mati', (tester) async {
    var ditekan = 0;
    await tester.pumpWidget(_bungkus(
      MiniPlayer(
        track: _lagu,
        playing: false,
        buffering: true,
        onTogglePlay: () => ditekan++,
      ),
    ));

    expect(find.text('Menyiapkan...'), findsOneWidget);
    expect(find.text('Kevin MacLeod'), findsNothing);

    await tester.tap(find.byType(IconButton), warnIfMissed: false);
    expect(ditekan, 0);
  });

  testWidgets('ketukan panggil onTogglePlay dan onTap', (tester) async {
    var putar = 0;
    var buka = 0;
    await tester.pumpWidget(_bungkus(
      MiniPlayer(
        track: _lagu,
        playing: false,
        onTogglePlay: () => putar++,
        onTap: () => buka++,
      ),
    ));

    await tester.tap(find.byTooltip('Putar'));
    expect(putar, 1);

    await tester.tap(find.text('Carefree'));
    expect(buka, 1);
  });
}
