import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/services/library_service.dart';

void main() {
  group('LibraryService.dariMediaStore', () {
    test('unduhan Mull: judul dan id video dipulihkan dari nama berkas', () {
      final t = LibraryService.dariMediaStore({
        'uri': 'content://media/external/audio/media/12',
        'name': 'Carefree [owrhKIN3Y90].m4a',
        'title': null,
        'artist': 'Kevin MacLeod',
        'durationMs': 206000,
        'mull': true,
        'video': false,
      });
      expect(t.id, 'owrhKIN3Y90');
      expect(t.title, 'Carefree');
      expect(t.artist, 'Kevin MacLeod');
      expect(t.duration, const Duration(seconds: 206));
      expect(t.localPath, 'content://media/external/audio/media/12');
    });

    test('lagu lain di HP: tanpa tag judul pakai nama berkas tanpa ekstensi', () {
      final t = LibraryService.dariMediaStore({
        'uri': 'content://media/external/audio/media/99',
        'name': 'lagu kesukaan.mp3',
        'title': null,
        'artist': '<unknown>',
        'durationMs': 0,
        'mull': false,
        'video': false,
      });
      expect(t.title, 'lagu kesukaan');
      expect(t.artist, isNull, reason: 'MediaStore nulis <unknown> buat artis kosong');
      expect(t.duration, isNull);
      expect(t.id, 'content://media/external/audio/media/99');
    });

    test('sampul diambil dari berkasnya sendiri (content://)', () {
      final t = LibraryService.dariMediaStore({
        'uri': 'content://media/external/audio/media/7',
        'name': 'x.mp3',
        'title': 'Judul Asli',
      });
      expect(t.title, 'Judul Asli');
      expect(t.thumbUrl, 'content://media/external/audio/media/7');
    });
  });
}
