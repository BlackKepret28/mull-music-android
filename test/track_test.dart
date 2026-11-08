import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/models/track.dart';

void main() {
  group('Track.fromYtDlp', () {
    test('baca judul, artis, durasi, dan sampul', () {
      final t = Track.fromYtDlp({
        'id': 'owrhKIN3Y90',
        'title': 'Carefree',
        'artist': 'Kevin MacLeod',
        'duration': 192.4,
        'webpage_url': 'https://music.youtube.com/watch?v=owrhKIN3Y90',
        'thumbnails': [
          {'url': 'https://i.ytimg.com/kecil.jpg'},
          {'url': 'https://i.ytimg.com/besar.jpg'},
        ],
      });

      expect(t.id, 'owrhKIN3Y90');
      expect(t.title, 'Carefree');
      expect(t.artist, 'Kevin MacLeod');
      expect(t.duration, const Duration(seconds: 192));
      // Thumbnail terakhir itu yang paling besar.
      expect(t.thumbUrl, 'https://i.ytimg.com/besar.jpg');
      expect(t.isVideo, isFalse);
    });

    test('pakai uploader kalau artist kosong, durasi 0 dianggap nggak ada', () {
      final t = Track.fromYtDlp({
        'id': 'aqz-KE-bpKQ',
        'title': 'Big Buck Bunny',
        'uploader': 'Blender',
        'duration': 0,
        'vcodec': 'avc1.640028',
      });

      expect(t.artist, 'Blender');
      expect(t.duration, isNull);
      expect(t.isVideo, isTrue);
    });

    test('judul kosong dikasih teks ganti', () {
      expect(Track.fromYtDlp({'id': 'x'}).title, 'Tanpa judul');
    });
  });

  test('resolvableUrl jatuh ke tautan YouTube kalau webpageUrl kosong', () {
    const t = Track(id: 'abc12345678', title: 'Tes');
    expect(t.resolvableUrl, 'https://www.youtube.com/watch?v=abc12345678');
  });

  test('toJson lalu fromJson hasilnya sama', () {
    const asli = Track(
      id: 'owrhKIN3Y90',
      title: 'Carefree',
      artist: 'Kevin MacLeod',
      thumbUrl: 'https://i.ytimg.com/besar.jpg',
      duration: Duration(seconds: 192),
      webpageUrl: 'https://music.youtube.com/watch?v=owrhKIN3Y90',
      localPath: '/sdcard/Music/Mull/carefree.m4a',
    );

    final ulang = Track.fromJson(asli.toJson());

    expect(ulang.title, asli.title);
    expect(ulang.artist, asli.artist);
    expect(ulang.duration, asli.duration);
    expect(ulang.webpageUrl, asli.webpageUrl);
    expect(ulang.localPath, asli.localPath);
    expect(ulang.isDownloaded, isTrue);
  });

  group('formatDuration', () {
    test('di bawah sejam jadi m:ss', () {
      expect(formatDuration(const Duration(minutes: 3, seconds: 12)), '3:12');
      expect(formatDuration(const Duration(seconds: 7)), '0:07');
    });

    test('sejam atau lebih jadi h:mm:ss', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });
  });
}
