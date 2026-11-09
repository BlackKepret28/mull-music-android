import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/models/track.dart';
import 'package:mullmusic/services/recent_service.dart';

const _a = Track(id: 'aaa', title: 'Lagu A', artist: 'Artis A');
const _b = Track(id: 'bbb', title: 'Lagu B', artist: 'Artis B');

void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('mull_recent_test');
  });

  tearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  RecentService baru() => RecentService.baru(folder: folder);

  test('awalnya kosong', () async {
    final s = baru();
    await s.muat();
    expect(s.daftar, isEmpty);
  });

  test('yang baru dicatat ada di paling atas', () async {
    final s = baru();
    await s.muat();
    await s.catat(_a);
    await s.catat(_b);

    expect(s.daftar.map((t) => t.id), ['bbb', 'aaa']);
  });

  test('lagu yang diputar ulang naik ke atas, bukan jadi dobel', () async {
    final s = baru();
    await s.muat();
    await s.catat(_a);
    await s.catat(_b);
    await s.catat(_a);

    expect(s.daftar.map((t) => t.id), ['aaa', 'bbb']);
    expect(s.daftar, hasLength(2));
  });

  test('tersimpan dan kebaca lagi', () async {
    final s = baru();
    await s.muat();
    await s.catat(_a);

    final lagi = baru();
    await lagi.muat();

    expect(lagi.daftar, hasLength(1));
    expect(lagi.daftar.single.title, 'Lagu A');
    expect(lagi.daftar.single.artist, 'Artis A');
  });

  test('dipotong di 50 entri', () async {
    final s = baru();
    await s.muat();
    for (var i = 0; i < 60; i++) {
      await s.catat(Track(id: 'id$i', title: 'Lagu $i'));
    }

    expect(s.daftar, hasLength(50));
    // Yang terakhir dicatat ada di atas, yang paling lama sudah kebuang.
    expect(s.daftar.first.id, 'id59');
    expect(s.daftar.any((t) => t.id == 'id0'), isFalse);
  });

  test('lagu tanpa id diabaikan', () async {
    final s = baru();
    await s.muat();
    await s.catat(const Track(id: '', title: 'Rusak'));

    expect(s.daftar, isEmpty);
  });

  test('bersihkan mengosongkan dan ikut tersimpan', () async {
    final s = baru();
    await s.muat();
    await s.catat(_a);
    await s.bersihkan();

    final lagi = baru();
    await lagi.muat();
    expect(lagi.daftar, isEmpty);
  });

  test('berkas rusak nggak bikin app mati', () async {
    await File('${folder.path}/recent.json').writeAsString('bukan json');

    final s = baru();
    await s.muat();

    expect(s.daftar, isEmpty);
    expect(s.sudahMuat, isTrue);
  });
}
