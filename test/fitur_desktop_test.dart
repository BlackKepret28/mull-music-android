import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/models/track.dart';
import 'package:mullmusic/services/finder_service.dart';
import 'package:mullmusic/services/import_service.dart';
import 'package:mullmusic/services/pencocok.dart';
import 'package:mullmusic/services/playlist_service.dart';
import 'package:mullmusic/services/update_service.dart';

void main() {
  group('Impor: kenali sumber', () {
    test('playlist YouTube Music dan YouTube', () {
      final a = ImportService.kenali('https://music.youtube.com/playlist?list=PLabc_123-x&si=zz');
      expect(a.jenis, JenisImpor.ytm);
      expect(a.id, 'PLabc_123-x');
      final b = ImportService.kenali('https://youtube.com/playlist?list=PLxyz');
      expect(b.jenis, JenisImpor.yt);
    });

    test('playlist, album, dan daftar lagu Spotify', () {
      final p = ImportService.kenali('https://open.spotify.com/intl-id/playlist/37i9dQZF1DXcBWIGoYBM5M?si=1');
      expect(p.jenis, JenisImpor.spotify);
      expect(p.tipe, 'playlist');
      expect(p.id, '37i9dQZF1DXcBWIGoYBM5M');
      final l = ImportService.kenali(
        'https://open.spotify.com/track/3zOYmiNOuyDL0ClxJcEJ0T\n'
        'https://open.spotify.com/track/3zOYmiNOuyDL0ClxJcEJ0T\n'
        'spotify:track:4uLU6hMCjMI75M1A2tKUQC',
      );
      expect(l.jenis, JenisImpor.spotifyLagu);
      expect(l.idLagu, ['3zOYmiNOuyDL0ClxJcEJ0T', '4uLU6hMCjMI75M1A2tKUQC']);
    });

    test('teks dan tautan yang belum didukung', () {
      final t = ImportService.kenali('- Carefree - Kevin MacLeod\n\nhttps://x.y\n• Monkeys Spinning Monkeys');
      expect(t.jenis, JenisImpor.teks);
      expect(t.baris, ['Carefree - Kevin MacLeod', 'Monkeys Spinning Monkeys']);
      expect(() => ImportService.kenali('https://example.com/lagu'), throwsA(isA<ImporGagal>()));
      expect(() => ImportService.kenali('  '), throwsA(isA<ImporGagal>()));
    });

    test('tampakPlaylist buat ngarahin tempelan di Beranda', () {
      expect(ImportService.tampakPlaylist('https://music.youtube.com/playlist?list=PLabc'), isTrue);
      expect(ImportService.tampakPlaylist('https://open.spotify.com/album/37i9dQZF1DXcBWIGoYBM5M'), isTrue);
      expect(ImportService.tampakPlaylist('https://www.youtube.com/watch?v=owrhKIN3Y90'), isFalse);
      expect(ImportService.tampakPlaylist('https://www.youtube.com/watch?v=owrhKIN3Y90&list=RDowrhKIN3Y90'), isFalse);
      expect(ImportService.tampakPlaylist('https://open.spotify.com/track/3zOYmiNOuyDL0ClxJcEJ0T'), isFalse);
      expect(ImportService.tampakPlaylist('kevin macleod'), isFalse);
    });
  });

  test('halaman embed Spotify kebaca (bentuk __NEXT_DATA__ per Nov 2026)', () {
    final data = {
      'props': {
        'pageProps': {
          'state': {
            'data': {
              'entity': {
                'type': 'playlist',
                'name': 'Today&#39;s Top Hits',
                'subtitle': 'Spotify',
                'trackList': [
                  {'uri': 'spotify:track:3zOYmiNOuyDL0ClxJcEJ0T', 'title': 'Stop The Wedding!', 'subtitle': 'Ashe', 'duration': 198840},
                  {'uri': 'spotify:episode:xyz', 'title': 'Podcast', 'subtitle': 'X', 'duration': 1000},
                ],
              },
            },
          },
        },
      },
    };
    final html = '<html><script src="a.js"></script>'
        '<script id="__NEXT_DATA__" type="application/json">${jsonEncode(data)}</script></html>';
    final p = ImportService.bacaEmbedSpotify(html, 'playlist', '37i9dQZF1DXcBWIGoYBM5M');
    expect(p.nama, "Today's Top Hits");
    expect(p.pemilik, 'Spotify');
    expect(p.lagu.length, 1);
    expect(p.lagu.single.judul, 'Stop The Wedding!');
    expect(p.lagu.single.artis, 'Ashe');
    expect(p.lagu.single.detik, 199);
    expect(p.perluCocok, isTrue);
    expect(() => ImportService.bacaEmbedSpotify('<html></html>', 'playlist', 'x'), throwsA(isA<ImporGagal>()));
  });

  test('teks "Judul - Artis" dipisah', () {
    final p = ImportService.dariTeks(['Carefree - Kevin MacLeod', 'Cuma judul']);
    expect(p.lagu[0].judul, 'Carefree');
    expect(p.lagu[0].artis, 'Kevin MacLeod');
    expect(p.lagu[1].artis, '');
  });

  group('kode bagikan', () {
    Playlist contoh() => Playlist(
          id: 'a',
          nama: 'Santai',
          dibuat: DateTime(2026),
          diubah: DateTime(2026),
          lagu: const [
            Track(id: 'owrhKIN3Y90', title: 'Carefree', artist: 'Kevin MacLeod', duration: Duration(seconds: 206)),
            Track(id: 'content://media/1', title: 'Lagu HP', localPath: 'content://media/1'),
            Track(id: 'aqz-KE-bpKQ', title: 'Big Buck Bunny', isVideo: true),
          ],
        );

    test('bolak-balik', () {
      final b = ImportService.bagikan(contoh());
      expect(b.kode, startsWith('mull-playlist:1:'));
      expect(b.jumlah, 2);
      expect(b.dilewati, 1);
      expect(b.teks, contains('https://music.youtube.com/watch?v=owrhKIN3Y90'));
      final p = ImportService.bacaKode('Coba ini: ${b.kode} ya');
      expect(p.nama, 'Santai');
      expect(p.lagu.map((l) => l.yt!.id), ['owrhKIN3Y90', 'aqz-KE-bpKQ']);
      expect(p.lagu.first.yt!.duration, const Duration(seconds: 206));
      expect(p.lagu.last.yt!.isVideo, isTrue);
      expect(p.lagu.first.yt!.webpageUrl, 'https://music.youtube.com/watch?v=owrhKIN3Y90');
    });

    test('kode dari versi Windows kebaca', () {
      // Dibuat playlists.share() versi Windows (Python zlib level 9).
      final mentah = utf8.encode(jsonEncode({
        'n': 'Dari laptop',
        'i': [
          {'t': 'Carefree', 'v': 'owrhKIN3Y90', 'a': 'Kevin MacLeod', 'd': 206},
        ],
      }));
      final kode = 'mull-playlist:1:${base64Url.encode(ZLibCodec(level: 9).encode(mentah)).replaceAll('=', '')}';
      final p = ImportService.bacaKode(kode);
      expect(p.nama, 'Dari laptop');
      expect(p.lagu.single.yt!.artist, 'Kevin MacLeod');
    });

    test('kode rusak', () {
      expect(() => ImportService.bacaKode('mull-playlist:1:abc'), throwsA(isA<ImporGagal>()));
    });
  });

  group('Pencocok', () {
    test('norm buang aksen dan isi kurung', () {
      expect(Pencocok.norm('Beyoncé – Halo (Official Video) [HD]'), 'beyonce halo');
    });

    test('skor lebih tinggi buat pasangan yang benar', () {
      const benar = Track(id: 'a', title: 'Kevin MacLeod - Carefree', artist: 'Kevin MacLeod', duration: Duration(seconds: 206));
      const salah = Track(id: 'b', title: 'Carefree (Live Remix)', artist: 'Orang Lain', duration: Duration(seconds: 400));
      final a = Pencocok.skor('Carefree', 'Kevin MacLeod', benar, detik: 206);
      final b = Pencocok.skor('Carefree', 'Kevin MacLeod', salah, detik: 206);
      expect(a, greaterThan(0.9));
      expect(b, lessThan(0.5));
    });

    test('artis pertama', () {
      expect(Pencocok.artisPertama('Tulus, Rossa & Raisa feat. X'), 'Tulus');
    });
  });

  group('Kenali lagu', () {
    test('jawaban Shazam diurai', () {
      final l = FinderService.parse({
        'matches': [
          {'offset': 31.2},
        ],
        'track': {
          'key': '123',
          'title': 'Gaiety in the Golden Age',
          'subtitle': 'Aaron Kenny',
          'url': 'https://www.shazam.com/track/123',
          'genres': {'primary': 'Soundtrack'},
          'images': {'coverart': 'https://x/400x400cc.jpg'},
          'sections': [
            {
              'type': 'SONG',
              'metadata': [
                {'title': 'Album', 'text': 'YouTube Audio Library'},
                {'title': 'Released', 'text': '2019'},
              ],
            },
            {
              'type': 'LYRICS',
              'text': ['baris satu', 'baris dua'],
            },
          ],
        },
      }, sumber: 'file');
      expect(l, isNotNull);
      expect(l!.judul, 'Gaiety in the Golden Age');
      expect(l.artis, 'Aaron Kenny');
      expect(l.album, 'YouTube Audio Library');
      expect(l.tahun, '2019');
      expect(l.genre, 'Soundtrack');
      expect(l.sampul, 'https://x/800x800cc.jpg');
      expect(l.lirik, 'baris satu\nbaris dua');
      expect(FinderService.parse({'matches': [], 'track': {}}), isNull);
      expect(FinderService.parse({}), isNull);
    });

    test('titik mulai: tengah dulu, lalu awal dan akhir', () {
      expect(FinderService.titikMulai(null), [0]);
      expect(FinderService.titikMulai(10), [0]);
      expect(FinderService.titikMulai(200), [74, 34, 124]);
      expect(FinderService.titikMulai(200, di: 60), [58]);
      expect(FinderService.titikMulai(200, di: 1), [0]);
    });

    test('rekaman pelan dikuatkan, yang keras dibiarkan', () {
      final pelan = Int16List.fromList(List.generate(16000, (i) => i.isEven ? 300 : -300));
      final b = FinderService.kuatkan(pelan.buffer.asUint8List());
      final hasil = Int16List.sublistView(b);
      expect(hasil[0], greaterThan(3000));
      expect(hasil[0], lessThanOrEqualTo(4900)); // maks 16x
      final keras = Int16List.fromList(List.generate(16000, (i) => i.isEven ? 8000 : -8000)).buffer.asUint8List();
      expect(identical(FinderService.kuatkan(keras), keras), isTrue);
    });

    test('cocokkan potongan lirik', () {
      const lirik = 'Aku ingin begini\nAku ingin begitu\nIngin ini ingin itu banyak sekali';
      expect(FinderService.cocokBaris('ingin ini ingin itu', lirik)!.$1, 1.0);
      expect(FinderService.cocokBaris('begini aku ingin begitu', lirik), isNotNull);
      expect(FinderService.cocokBaris('lagu lain sama sekali', lirik), isNull);
      expect(FinderService.cocokBaris('satu', lirik), isNull);
    });

    test('riwayat: lagu yang sama naik ke atas, nggak dobel', () async {
      final dir = await Directory.systemTemp.createTemp('mull-finds');
      addTearDown(() => dir.delete(recursive: true));
      final f = FinderService.baru(folder: dir);
      LaguDikenali l(String id, String key) =>
          LaguDikenali(id: id, key: key, judul: 'J$id', artis: 'A', waktu: DateTime(2026), sumber: 'mic');
      await f.catat(l('1', 'k1'));
      await f.catat(l('2', 'k2'));
      await f.catat(l('3', 'k1'));
      expect(f.riwayat.map((e) => e.id), ['3', '2']);
      final f2 = FinderService.baru(folder: dir);
      await f2.muat();
      expect(f2.riwayat.map((e) => e.judul), ['J3', 'J2']);
    });
  });

  group('Update', () {
    test('banding versi', () {
      expect(UpdateService.lebihBaru('1.1.0', '1.0.0'), isTrue);
      expect(UpdateService.lebihBaru('v1.0.10', '1.0.9'), isTrue);
      expect(UpdateService.lebihBaru('1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.lebihBaru('1.0', '1.0.1'), isFalse);
      expect(UpdateService.lebihBaru('2.0.0-beta', '1.9.9'), isTrue);
    });

    test('pilih APK sesuai ABI HP', () {
      final aset = [
        {'name': 'app-armeabi-v7a-release.apk'},
        {'name': 'app-arm64-v8a-release.apk'},
        {'name': 'app-arm64-v8a-release.apk.sha256'},
        {'name': 'app-x86_64-release.apk'},
      ];
      expect(UpdateService.pilihAset(aset, ['arm64-v8a', 'armeabi-v7a'])!['name'], 'app-arm64-v8a-release.apk');
      expect(UpdateService.pilihAset(aset, ['armeabi-v7a'])!['name'], 'app-armeabi-v7a-release.apk');
      expect(UpdateService.pilihAset([{'name': 'mull.apk'}], ['arm64-v8a'])!['name'], 'mull.apk');
      expect(UpdateService.pilihAset([{'name': 'x.zip'}], ['arm64-v8a']), isNull);
    });
  });
}
