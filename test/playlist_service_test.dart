import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/models/track.dart';
import 'package:mullmusic/services/playlist_service.dart';

const _carefree = Track(
  id: 'owrhKIN3Y90',
  title: 'Carefree',
  artist: 'Kevin MacLeod',
  duration: Duration(seconds: 206),
);

const _bunny = Track(
  id: 'aqz-KE-bpKQ',
  title: 'Big Buck Bunny',
  artist: 'Blender',
  duration: Duration(seconds: 634),
);

void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('mull_playlist_test');
  });

  tearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  PlaylistService baru() => PlaylistService.baru(folder: folder);

  test('awalnya kosong', () async {
    final s = baru();
    await s.muat();
    expect(s.daftar, isEmpty);
    expect(s.sudahMuat, isTrue);
  });

  test('bikin playlist lalu isinya kebaca lagi setelah dimuat ulang', () async {
    final s = baru();
    await s.muat();
    final p = await s.buat('Lagu belajar');
    await s.tambahLagu(p, [_carefree, _bunny]);

    final lagi = baru();
    await lagi.muat();

    expect(lagi.daftar, hasLength(1));
    expect(lagi.daftar.single.nama, 'Lagu belajar');
    expect(lagi.daftar.single.lagu.map((t) => t.id), ['owrhKIN3Y90', 'aqz-KE-bpKQ']);
    expect(lagi.daftar.single.lagu.first.artist, 'Kevin MacLeod');
  });

  test('nama kosong diganti nama bawaan', () async {
    final s = baru();
    await s.muat();
    final p = await s.buat('   ');
    expect(p.nama, 'Playlist baru');
  });

  test('lagu yang sama nggak dobel', () async {
    final s = baru();
    await s.muat();
    final p = await s.buat('Tes');

    expect(await s.tambahLagu(p, [_carefree]), 1);
    expect(await s.tambahLagu(p, [_carefree]), 0);
    expect(p.lagu, hasLength(1));
  });

  test('hapus lagu dan hapus playlist', () async {
    final s = baru();
    await s.muat();
    final p = await s.buat('Tes');
    await s.tambahLagu(p, [_carefree, _bunny]);

    await s.hapusLagu(p, _carefree);
    expect(p.lagu.map((t) => t.id), ['aqz-KE-bpKQ']);

    await s.hapus(p);
    expect(s.daftar, isEmpty);

    final lagi = baru();
    await lagi.muat();
    expect(lagi.daftar, isEmpty);
  });

  test('urutan lagu bisa digeser', () async {
    final s = baru();
    await s.muat();
    final p = await s.buat('Tes');
    await s.tambahLagu(p, [_carefree, _bunny]);

    await s.pindahLagu(p, 0, 1);
    expect(p.lagu.map((t) => t.id), ['aqz-KE-bpKQ', 'owrhKIN3Y90']);
  });

  test('ganti nama tersimpan, nama kosong diabaikan', () async {
    final s = baru();
    await s.muat();
    final p = await s.buat('Lama');

    await s.gantiNama(p, '  ');
    expect(p.nama, 'Lama');

    await s.gantiNama(p, 'Baru');

    final lagi = baru();
    await lagi.muat();
    expect(lagi.daftar.single.nama, 'Baru');
  });

  test('total durasi dijumlah dari lagunya', () async {
    final s = baru();
    await s.muat();
    final p = await s.buat('Tes');
    await s.tambahLagu(p, [_carefree, _bunny]);

    expect(p.totalDurasi, const Duration(seconds: 206 + 634));
  });

  test('berkas rusak nggak bikin app mati', () async {
    await File('${folder.path}/playlists.json').writeAsString('{ini bukan json');

    final s = baru();
    await s.muat();

    expect(s.daftar, isEmpty);
    expect(s.sudahMuat, isTrue);
  });

  test('bentuk JSON-nya mirip playlists.json versi Windows', () async {
    final s = baru();
    await s.muat();
    final p = await s.buat('Tes');
    await s.tambahLagu(p, [_carefree]);

    final isi = jsonDecode(await File('${folder.path}/playlists.json').readAsString());

    expect(isi, isA<Map>());
    expect(isi['playlists'], isA<List>());
    final satu = isi['playlists'][0] as Map;
    expect(satu.keys, containsAll(['id', 'name', 'created', 'updated', 'items']));
    expect((satu['items'] as List).first, containsPair('title', 'Carefree'));
  });
}
