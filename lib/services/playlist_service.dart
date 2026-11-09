import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';

/// Playlist buatan pengguna, disimpan lokal.
class Playlist {
  Playlist({
    required this.id,
    required this.nama,
    required this.dibuat,
    required this.diubah,
    required this.lagu,
  });

  final String id;
  String nama;
  final DateTime dibuat;
  DateTime diubah;
  final List<Track> lagu;

  Duration get totalDurasi => lagu.fold(
        Duration.zero,
        (jumlah, t) => jumlah + (t.duration ?? Duration.zero),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': nama,
        'created': dibuat.millisecondsSinceEpoch ~/ 1000,
        'updated': diubah.millisecondsSinceEpoch ~/ 1000,
        'items': lagu.map((t) => t.toJson()).toList(),
      };

  factory Playlist.fromJson(Map<String, dynamic> j) {
    DateTime waktu(Object? v) => v is num
        ? DateTime.fromMillisecondsSinceEpoch((v * 1000).round())
        : DateTime.fromMillisecondsSinceEpoch(0);

    return Playlist(
      id: (j['id'] ?? '') as String,
      nama: (j['name'] ?? 'Tanpa nama') as String,
      dibuat: waktu(j['created']),
      diubah: waktu(j['updated']),
      lagu: ((j['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Track.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Simpanan playlist di `playlists.json` dalam folder app.
///
/// Bentuk berkasnya sengaja dibikin mirip `playlists.json` versi Windows
/// (`{"playlists": [{id, name, created, updated, items}]}`) supaya nanti
/// gampang disinkronkan. Belum identik: versi Windows punya `kind`, `mode`,
/// dan `iid` per item yang di Android belum kepakai.
class PlaylistService extends ChangeNotifier {
  PlaylistService._();
  static final instance = PlaylistService._();

  /// Instance bersih buat tes, boleh diarahkan ke folder sementara.
  @visibleForTesting
  factory PlaylistService.baru({Directory? folder}) {
    final s = PlaylistService._();
    s._folderTes = folder;
    return s;
  }

  static const _maksItem = 5000;

  Directory? _folderTes;
  List<Playlist> _daftar = [];
  bool _sudahMuat = false;

  List<Playlist> get daftar => List.unmodifiable(_daftar);
  bool get sudahMuat => _sudahMuat;

  Future<File> _berkas() async {
    final dasar = _folderTes ?? await getApplicationSupportDirectory();
    if (!await dasar.exists()) await dasar.create(recursive: true);
    return File('${dasar.path}/playlists.json');
  }

  Future<void> muat() async {
    try {
      final f = await _berkas();
      if (await f.exists()) {
        final isi = jsonDecode(await f.readAsString());
        final list = (isi is Map ? isi['playlists'] : null) as List?;
        _daftar = (list ?? const [])
            .whereType<Map>()
            .map((e) => Playlist.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        // Yang terakhir diubah di atas.
        _daftar.sort((a, b) => b.diubah.compareTo(a.diubah));
      }
    } catch (_) {
      // Berkas rusak jangan bikin app mati; mulai dari kosong.
      _daftar = [];
    } finally {
      _sudahMuat = true;
      notifyListeners();
    }
  }

  Future<void> _simpan() async {
    try {
      final f = await _berkas();
      await f.writeAsString(
        jsonEncode({'playlists': _daftar.map((p) => p.toJson()).toList()}),
      );
    } catch (_) {
      // Gagal nulis: isi di memori tetap benar sampai app ditutup.
    }
  }

  static final _acak = Random();
  static String _idBaru() {
    const huruf = 'abcdef0123456789';
    return List.generate(12, (_) => huruf[_acak.nextInt(huruf.length)]).join();
  }

  Future<Playlist> buat(String nama) async {
    final sekarang = DateTime.now();
    final p = Playlist(
      id: _idBaru(),
      nama: nama.trim().isEmpty ? 'Playlist baru' : nama.trim(),
      dibuat: sekarang,
      diubah: sekarang,
      lagu: [],
    );
    _daftar.insert(0, p);
    notifyListeners();
    await _simpan();
    return p;
  }

  Future<void> gantiNama(Playlist p, String nama) async {
    if (nama.trim().isEmpty) return;
    p.nama = nama.trim();
    p.diubah = DateTime.now();
    notifyListeners();
    await _simpan();
  }

  Future<void> hapus(Playlist p) async {
    _daftar.remove(p);
    notifyListeners();
    await _simpan();
  }

  /// Tambah lagu, lewati yang sudah ada.
  Future<int> tambahLagu(Playlist p, List<Track> lagu) async {
    final punya = p.lagu.map((t) => t.id).toSet();
    var ditambah = 0;
    for (final t in lagu) {
      if (p.lagu.length >= _maksItem) break;
      if (!punya.add(t.id)) continue;
      p.lagu.add(t);
      ditambah++;
    }
    if (ditambah > 0) {
      p.diubah = DateTime.now();
      notifyListeners();
      await _simpan();
    }
    return ditambah;
  }

  Future<void> hapusLagu(Playlist p, Track t) async {
    p.lagu.removeWhere((e) => e.id == t.id);
    p.diubah = DateTime.now();
    notifyListeners();
    await _simpan();
  }

  Future<void> pindahLagu(Playlist p, int dari, int ke) async {
    if (dari < 0 || dari >= p.lagu.length) return;
    final t = p.lagu.removeAt(dari);
    p.lagu.insert(ke.clamp(0, p.lagu.length), t);
    p.diubah = DateTime.now();
    notifyListeners();
    await _simpan();
  }
}
