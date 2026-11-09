import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/services/lyrics_service.dart';

void main() {
  group('parseLrc', () {
    test('baca stempel waktu dan urutkan', () {
      final baris = LyricsService.parseLrc('''
[00:12.50]Baris kedua
[00:05.00]Baris pertama
[01:03.25]Baris ketiga
''');

      expect(baris, hasLength(3));
      expect(baris[0].teks, 'Baris pertama');
      expect(baris[0].waktu, const Duration(seconds: 5));
      expect(baris[1].waktu, const Duration(seconds: 12, milliseconds: 500));
      expect(baris[2].waktu, const Duration(minutes: 1, seconds: 3, milliseconds: 250));
    });

    test('satu baris dengan beberapa stempel jadi beberapa entri', () {
      final baris = LyricsService.parseLrc('[00:10.00][00:40.00]Reff diulang');

      expect(baris, hasLength(2));
      expect(baris[0].waktu, const Duration(seconds: 10));
      expect(baris[1].waktu, const Duration(seconds: 40));
      expect(baris.every((b) => b.teks == 'Reff diulang'), isTrue);
    });

    test('baris tanpa stempel dan tag metadata diabaikan', () {
      final baris = LyricsService.parseLrc('''
[ar:Kevin MacLeod]
[ti:Carefree]
Baris tanpa waktu
[00:03.00]Yang ini kepakai
''');

      expect(baris, hasLength(1));
      expect(baris.single.teks, 'Yang ini kepakai');
    });

    test('pecahan detik satu sampai tiga angka', () {
      expect(LyricsService.parseLrc('[00:01.5]a').single.waktu,
          const Duration(seconds: 1, milliseconds: 500));
      expect(LyricsService.parseLrc('[00:01.50]a').single.waktu,
          const Duration(seconds: 1, milliseconds: 500));
      expect(LyricsService.parseLrc('[00:01.500]a').single.waktu,
          const Duration(seconds: 1, milliseconds: 500));
    });

    test('kosong atau null balik daftar kosong', () {
      expect(LyricsService.parseLrc(null), isEmpty);
      expect(LyricsService.parseLrc('   '), isEmpty);
    });
  });

  group('bersihkanJudul', () {
    test('buang embel-embel YouTube', () {
      final (judul, artis) =
          LyricsService.bersihkanJudul('Carefree (No Copyright Music)', 'Kevin MacLeod');
      expect(judul, 'Carefree');
      expect(artis, 'Kevin MacLeod');
    });

    test('pola "Artis - Judul" dipisah kalau kirinya memang artisnya', () {
      final (judul, artis) =
          LyricsService.bersihkanJudul('Kevin MacLeod - Carefree', 'Kevin MacLeod');
      expect(judul, 'Carefree');
      expect(artis, 'Kevin MacLeod');
    });

    test('tanpa artis, bagian kiri dianggap artis', () {
      final (judul, artis) = LyricsService.bersihkanJudul('Kevin MacLeod - Carefree', '');
      expect(judul, 'Carefree');
      expect(artis, 'Kevin MacLeod');
    });

    test('kanal "- Topic" dirapikan', () {
      final (_, artis) = LyricsService.bersihkanJudul('Carefree', 'Kevin MacLeod - Topic');
      expect(artis, 'Kevin MacLeod');
    });

    test('feat dibuang dari judul', () {
      final (judul, _) = LyricsService.bersihkanJudul('Lagu Enak (feat. Seseorang)', 'Artis');
      expect(judul, 'Lagu Enak');
    });

    test('judul yang memang pakai tanda hubung nggak dipotong sembarangan', () {
      final (judul, artis) = LyricsService.bersihkanJudul('Spider-Man Theme', 'Danny Elfman');
      expect(judul, 'Spider-Man Theme');
      expect(artis, 'Danny Elfman');
    });

    test('tanda pisah en dash ikut dikenali', () {
      final (judul, artis) =
          LyricsService.bersihkanJudul('Kevin MacLeod – Carefree', 'Kevin MacLeod');
      expect(judul, 'Carefree');
      expect(artis, 'Kevin MacLeod');
    });
  });

  group('keLrc', () {
    test('tulis ulang jadi LRC yang bisa dibaca lagi', () {
      const asli = '[00:05.00]Satu\n[01:10.25]Dua\n';
      final baris = LyricsService.parseLrc(asli);
      final teks = LyricsService.keLrc(
        Lirik(tersinkron: baris, polos: 'Satu\nDua', sumber: 'LRCLIB'),
      );

      final ulang = LyricsService.parseLrc(teks);
      expect(ulang, hasLength(2));
      expect(ulang[0].waktu, const Duration(seconds: 5));
      expect(ulang[0].teks, 'Satu');
      expect(ulang[1].waktu, const Duration(minutes: 1, seconds: 10, milliseconds: 250));
    });

    test('lirik tanpa waktu disimpan apa adanya', () {
      final teks = LyricsService.keLrc(
        const Lirik(tersinkron: [], polos: 'Cuma teks biasa', sumber: 'LRCLIB'),
      );
      expect(teks, 'Cuma teks biasa');
    });
  });
}
