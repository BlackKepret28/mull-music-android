import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/services/ytdlp_service.dart';

/// Satu entri hasil `yt-dlp -J --flat-playlist ytsearch...`.
Map<String, dynamic> _entri(String id, String judul, {num? durasi}) => {
      'id': id,
      'title': judul,
      'uploader': 'Kanal $judul',
      'duration': ?durasi,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mull/ytdlp');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Semua panggilan yang masuk ke sisi native, buat dicek di tes.
  late List<String> dipanggil;
  late Map<String, Object?> balasan;

  void pasangMock() {
    dipanggil = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      dipanggil.add(call.method);
      final r = balasan[call.method];
      if (r is Exception) throw r;
      return r;
    });
  }

  setUp(() {
    balasan = {
      'init': {'ms': 120},
      'version': {'version': '2026.10.26'},
      'updateYtDlp': {'status': 'DONE', 'version': '2026.11.01', 'ms': 2200},
    };
    pasangMock();
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('ensureReady', () {
    test('kalau versi sudah tercatat, nggak usah update', () async {
      final s = YtDlpService.baru();
      await s.ensureReady();

      expect(s.status, EngineStatus.siap);
      expect(s.version, '2026.10.26');
      expect(dipanggil, ['init', 'version']);
    });

    test('versi null (yt-dlp bawaan paket) memicu update sekali', () async {
      balasan['version'] = {'version': null};

      final s = YtDlpService.baru();
      await s.ensureReady();

      expect(dipanggil, ['init', 'version', 'updateYtDlp']);
      expect(s.version, '2026.11.01');
      expect(s.status, EngineStatus.siap);
    });

    test('dipanggil dua kali cuma kerja sekali', () async {
      final s = YtDlpService.baru();
      await s.ensureReady();
      await s.ensureReady();

      expect(dipanggil, ['init', 'version']);
    });

    test('init gagal: status jadi gagal dan masih bisa dicoba ulang', () async {
      balasan['init'] = Exception('no space left on device');

      final s = YtDlpService.baru();
      await expectLater(s.ensureReady(), throwsA(isA<Exception>()));
      expect(s.status, EngineStatus.gagal);
      expect(s.error, 'Ruang penyimpanan HP habis. Hapus beberapa file dulu.');

      // Percobaan kedua jalan lagi setelah masalahnya beres.
      balasan['init'] = {'ms': 120};
      await s.ensureReady();
      expect(s.status, EngineStatus.siap);
    });
  });

  group('search', () {
    void pasangHasilCari(List<Map<String, dynamic>> entries) {
      balasan['getInfo'] = {
        'json': jsonEncode({'_type': 'playlist', 'entries': entries}),
        'ms': 900,
      };
    }

    test('kata kunci jadi daftar Track', () async {
      pasangHasilCari([
        _entri('owrhKIN3Y90', 'Carefree', durasi: 192),
        _entri('aqz-KE-bpKQ', 'Big Buck Bunny', durasi: 634),
      ]);

      final s = YtDlpService.baru();
      final hasil = await s.search('carefree');

      expect(hasil, hasLength(2));
      expect(hasil.first.id, 'owrhKIN3Y90');
      expect(hasil.first.title, 'Carefree');
      expect(hasil.first.duration, const Duration(seconds: 192));
      expect(dipanggil, contains('getInfo'));
    });

    test('entri tanpa id dibuang', () async {
      pasangHasilCari([
        _entri('owrhKIN3Y90', 'Carefree'),
        {'title': 'Rusak, tanpa id'},
      ]);

      final s = YtDlpService.baru();
      expect(await s.search('apa aja'), hasLength(1));
    });

    test('query sama nggak manggil yt-dlp dua kali', () async {
      pasangHasilCari([_entri('owrhKIN3Y90', 'Carefree')]);

      final s = YtDlpService.baru();
      await s.search('carefree');
      final sesudahPertama = dipanggil.where((m) => m == 'getInfo').length;
      await s.search('carefree');

      expect(dipanggil.where((m) => m == 'getInfo').length, sesudahPertama);
    });

    test('query kosong balik daftar kosong tanpa nyentuh native', () async {
      final s = YtDlpService.baru();
      expect(await s.search('   '), isEmpty);
      expect(dipanggil, isEmpty);
    });

    test('tautan satu video jadi satu Track', () async {
      balasan['getInfo'] = {
        'json': jsonEncode({
          'id': 'owrhKIN3Y90',
          'title': 'Carefree',
          'artist': 'Kevin MacLeod',
          'duration': 192,
          'webpage_url': 'https://music.youtube.com/watch?v=owrhKIN3Y90',
        }),
        'ms': 27000,
      };

      final s = YtDlpService.baru();
      final hasil = await s.search('https://music.youtube.com/watch?v=owrhKIN3Y90');

      expect(hasil, hasLength(1));
      expect(hasil.single.artist, 'Kevin MacLeod');
    });

    test('galat jaringan diterjemahkan ke bahasa pengguna', () async {
      balasan['getInfo'] = Exception('ERROR: Unable to download webpage');

      final s = YtDlpService.baru();
      await expectLater(
        s.search('carefree'),
        throwsA(predicate((e) => e.toString().contains('Nggak bisa nyambung ke internet'))),
      );
    });
  });

  group('isUrl', () {
    test('kenali tautan', () {
      expect(YtDlpService.isUrl('https://youtu.be/abc'), isTrue);
      expect(YtDlpService.isUrl('HTTP://example.com'), isTrue);
      expect(YtDlpService.isUrl('  https://a.b  '), isTrue);
    });

    test('kata biasa bukan tautan', () {
      expect(YtDlpService.isUrl('carefree kevin macleod'), isFalse);
      expect(YtDlpService.isUrl('youtube.com tanpa skema'), isFalse);
    });
  });
}
