import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/models/track.dart';
import 'package:mullmusic/services/playlist_service.dart';

void main() {
  test('toggleSuka membuat playlist Disukai, menambah, lalu membuang lagu', () async {
    final dir = await Directory.systemTemp.createTemp('mull_suka');
    addTearDown(() => dir.delete(recursive: true));
    final s = PlaylistService.baru(folder: dir);
    const t = Track(id: 'dQw4w9WgXcQ', title: 'Lagu Uji');

    expect(s.disukaiLagu(t), isFalse);
    expect(s.disukai, isNull);

    expect(await s.toggleSuka(t), isTrue);
    expect(s.disukai?.nama, 'Disukai');
    expect(s.disukai?.id, PlaylistService.idDisukai);
    expect(s.disukaiLagu(t), isTrue);

    expect(await s.toggleSuka(t), isFalse);
    expect(s.disukaiLagu(t), isFalse);
    // Playlistnya tetap ada walau kosong.
    expect(s.disukai, isNotNull);
  });
}
