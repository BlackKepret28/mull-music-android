import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import '../ytdlp.dart';
import 'finder_service.dart';
import 'playlist_service.dart';

class AkunGagal implements Exception {
  const AkunGagal(this.pesan);
  final String pesan;

  @override
  String toString() => pesan;
}

/// Akun Mull (Firebase), sama dengan `mull/cloud.py` versi Windows: login
/// Google, lalu playlist dan lagu yang pernah dikenali disinkronkan lewat
/// Firestore `users/{uid}/...`. Login dengan Gmail yang sama di HP dan di
/// laptop = playlist-nya sama.
///
/// Login Google pakai alur yang sama dengan versi Windows (OAuth untuk app
/// desktop, PKCE + alamat balik http://127.0.0.1:<port>): app membuka
/// browser, Google mengarahkan balik ke server kecil di HP ini, kodenya
/// ditukar jadi sesi Firebase.
///
/// Konfigurasinya di `assets/cloud_config.json` (nggak di-commit karena repo
/// ini publik; di GitHub Actions ditulis dari secret `CLOUD_CONFIG_JSON`).
/// Kalau kosong, semua fitur akun disembunyikan.
class AkunService extends ChangeNotifier {
  AkunService._();
  static final instance = AkunService._();

  @visibleForTesting
  factory AkunService.baru() => AkunService._();

  static const _auth = 'https://identitytoolkit.googleapis.com/v1';
  static const _token = 'https://securetoken.googleapis.com/v1';
  static const _store = 'https://firestore.googleapis.com/v1';
  static const _googleAuth = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _googleToken = 'https://oauth2.googleapis.com/token';
  static const _kunci = 'akun';
  static const _maksDok = 900000; // batas dokumen Firestore 1 MiB
  static const _maksFinds = 200;

  final _http = http.Client();
  Map<String, dynamic> _cfg = const {};
  Map<String, dynamic> _state = {};
  String? _idToken;
  DateTime _tokenHabis = DateTime.fromMillisecondsSinceEpoch(0);

  bool _sibuk = false;
  bool get sibuk => _sibuk;
  String? _galat;
  String? get galat => _galat;
  Timer? _tunda;

  /// Fitur akun aktif di build ini (config terisi).
  bool get aktif =>
      '${_cfg['apiKey'] ?? ''}'.isNotEmpty &&
      '${_cfg['projectId'] ?? ''}'.isNotEmpty &&
      '${_cfg['googleClientId'] ?? ''}'.isNotEmpty;

  bool get masuk => _state['refreshToken'] is String && _state['uid'] is String;
  String? get email => _state['email'] as String?;
  String? get nama => _state['name'] as String?;
  String? get foto => _state['photo'] as String?;
  DateTime? get terakhirSinkron {
    final t = _state['lastSync'];
    return t is num ? DateTime.fromMillisecondsSinceEpoch((t * 1000).round()) : null;
  }

  Future<void> muat() async {
    try {
      final isi = await rootBundle.loadString('assets/cloud_config.json');
      final j = jsonDecode(isi);
      if (j is Map) _cfg = Map<String, dynamic>.from(j);
    } catch (_) {
      _cfg = const {};
    }
    final prefs = await SharedPreferences.getInstance();
    try {
      final j = jsonDecode(prefs.getString(_kunci) ?? '{}');
      if (j is Map) _state = Map<String, dynamic>.from(j);
    } catch (_) {
      _state = {};
    }
    PlaylistService.instance.onBerubah = jadwalkan;
    notifyListeners();
    if (aktif && masuk) sinkron(diam: true).ignore();
  }

  Future<void> _simpanState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kunci, jsonEncode(_state));
  }

  // ---------------------------------------------------------------- HTTP

  Future<dynamic> _req(String metode, String url, {Object? body, bool form = false, String? token}) async {
    final req = http.Request(metode, Uri.parse(url));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      if (form) {
        req.bodyFields = {for (final e in (body as Map).entries) '${e.key}': '${e.value}'};
      } else {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
    }
    final http.Response r;
    try {
      r = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 20)));
    } catch (_) {
      throw const AkunGagal('Nggak bisa nyambung. Cek internet lalu coba lagi.');
    }
    if (r.statusCode == 404 && metode == 'GET') return null;
    final teks = utf8.decode(r.bodyBytes, allowMalformed: true);
    if (r.statusCode >= 400) {
      final l = teks.toLowerCase();
      if (l.contains('token_expired') || l.contains('invalid_refresh_token') || l.contains('user_not_found')) {
        throw const AkunGagal('Sesi login habis. Masuk lagi, ya.');
      }
      if (r.statusCode == 403) throw const AkunGagal('Akun ini nggak diizinkan mengakses data. Coba masuk ulang.');
      throw AkunGagal('Server menolak permintaan (HTTP ${r.statusCode}). Coba lagi nanti.');
    }
    return teks.isEmpty ? null : jsonDecode(teks);
  }

  // ---------------------------------------------------------------- login

  static String _acak(int n) {
    final r = Random.secure();
    return base64Url.encode(List.generate(n, (_) => r.nextInt(256))).replaceAll('=', '');
  }

  HttpServer? _server;

  /// Login Google lewat browser. Batal / ditinggal 3 menit = gagal.
  Future<void> masukGoogle() async {
    if (!aktif) throw const AkunGagal('Login belum diaktifkan di versi ini.');
    if (_sibuk) return;
    _set(sibuk: true);
    try {
      final verifier = _acak(64);
      final challenge = base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
      final state = _acak(16);

      await _server?.close(force: true);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      final redirect = 'http://127.0.0.1:${server.port}/';
      final kode = Completer<String?>();

      server.listen((req) async {
        if (req.uri.path != '/') {
          req.response.statusCode = 404;
          await req.response.close();
          return;
        }
        final q = req.uri.queryParameters;
        final ok = q['state'] == state && (q['code'] ?? '').isNotEmpty;
        req.response.headers.contentType = ContentType.html;
        req.response.write(_halaman(ok));
        await req.response.close();
        if (!kode.isCompleted && q['state'] == state) kode.complete(ok ? q['code'] : null);
      });

      final url = Uri.parse(_googleAuth).replace(queryParameters: {
        'client_id': '${_cfg['googleClientId']}',
        'redirect_uri': redirect,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': state,
        'prompt': 'select_account',
      });
      await YtDlp.openUrl(url.toString());

      final String? c;
      try {
        c = await kode.future.timeout(const Duration(minutes: 3));
      } on TimeoutException {
        throw const AkunGagal('Login Google kelamaan nggak diselesaikan. Coba lagi.');
      } finally {
        await server.close(force: true);
        _server = null;
      }
      if (c == null) throw const AkunGagal('Login Google dibatalkan.');

      final tok = await _req('POST', _googleToken, form: true, body: {
        'code': c,
        'client_id': '${_cfg['googleClientId']}',
        if ('${_cfg['googleClientSecret'] ?? ''}'.isNotEmpty) 'client_secret': '${_cfg['googleClientSecret']}',
        'redirect_uri': redirect,
        'grant_type': 'authorization_code',
        'code_verifier': verifier,
      }) as Map?;
      final idTokenGoogle = tok?['id_token'];
      if (idTokenGoogle is! String) throw const AkunGagal('Google nggak ngasih token login. Coba lagi.');

      final res = await _req('POST', '$_auth/accounts:signInWithIdp?key=${_cfg['apiKey']}', body: {
        'postBody': 'id_token=${Uri.encodeQueryComponent(idTokenGoogle)}&providerId=google.com',
        'requestUri': redirect,
        'returnIdToken': true,
        'returnSecureToken': true,
      }) as Map;
      _state = {
        'uid': res['localId'],
        'email': res['email'],
        'name': res['displayName'] ?? res['fullName'],
        'photo': res['photoUrl'],
        'refreshToken': res['refreshToken'],
      };
      _idToken = res['idToken'] as String?;
      _tokenHabis = DateTime.now().add(Duration(seconds: int.tryParse('${res['expiresIn']}') ?? 3600) - const Duration(minutes: 1));
      await _simpanState();
      _set(sibuk: false, galat: null);
      await sinkron();
    } on AkunGagal catch (e) {
      _set(sibuk: false, galat: e.pesan);
      rethrow;
    } catch (e) {
      _set(sibuk: false, galat: 'Login gagal: $e');
      throw AkunGagal('Login gagal: $e');
    }
  }

  /// Batalkan login yang lagi nunggu browser.
  void batalMasuk() {
    _server?.close(force: true);
  }

  static String _halaman(bool ok) => '''<!doctype html><html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Mull Music</title>
<style>body{font-family:system-ui,sans-serif;background:#0f1117;color:#eef;display:grid;place-items:center;height:100vh;margin:0}
div{max-width:320px;padding:24px;text-align:center}h1{font-size:20px;margin:0 0 8px}p{color:#aab;line-height:1.5}</style></head>
<body><div><h1>${ok ? 'Berhasil masuk' : 'Login dibatalkan'}</h1>
<p>${ok ? 'Kembali ke Mull Music. Tab ini boleh ditutup.' : 'Tutup tab ini, lalu coba lagi dari Mull Music.'}</p></div></body></html>''';

  Future<void> keluar() async {
    _tunda?.cancel();
    _state = {};
    _idToken = null;
    await _simpanState();
    _set(galat: null);
  }

  Future<String> _tokenSah() async {
    if (_idToken != null && DateTime.now().isBefore(_tokenHabis)) return _idToken!;
    final rt = _state['refreshToken'];
    if (rt is! String) throw const AkunGagal('Belum masuk.');
    final Map res;
    try {
      res = await _req('POST', '$_token/token?key=${_cfg['apiKey']}', form: true, body: {
        'grant_type': 'refresh_token',
        'refresh_token': rt,
      }) as Map;
    } on AkunGagal catch (e) {
      if (e.pesan.startsWith('Sesi login habis')) await keluar();
      rethrow;
    }
    _idToken = res['id_token'] as String?;
    _tokenHabis = DateTime.now().add(Duration(seconds: int.tryParse('${res['expires_in']}') ?? 3600) - const Duration(minutes: 1));
    if (res['refresh_token'] is String && res['refresh_token'] != rt) {
      _state['refreshToken'] = res['refresh_token'];
      await _simpanState();
    }
    return _idToken!;
  }

  // ---------------------------------------------------------------- Firestore

  String get _docs => '$_store/projects/${_cfg['projectId']}/databases/(default)/documents/users/${_state['uid']}';

  @visibleForTesting
  static Map<String, dynamic> enc(Object? v) {
    if (v == null) return {'nullValue': null};
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': '$v'};
    if (v is double) return {'doubleValue': v};
    if (v is String) return {'stringValue': v};
    if (v is List) return {'arrayValue': {'values': v.map(enc).toList()}};
    if (v is Map) return {'mapValue': {'fields': {for (final e in v.entries) '${e.key}': enc(e.value)}}};
    return {'stringValue': '$v'};
  }

  @visibleForTesting
  static Object? dec(Map v) {
    if (v.containsKey('nullValue')) return null;
    for (final k in const ['booleanValue', 'stringValue', 'doubleValue', 'timestampValue']) {
      if (v.containsKey(k)) return v[k];
    }
    if (v.containsKey('integerValue')) return int.tryParse('${v['integerValue']}');
    if (v['arrayValue'] is Map) {
      return [for (final x in ((v['arrayValue'] as Map)['values'] as List?) ?? const []) dec(x as Map)];
    }
    if (v['mapValue'] is Map) {
      return {for (final e in (((v['mapValue'] as Map)['fields'] as Map?) ?? const {}).entries) '${e.key}': dec(e.value as Map)};
    }
    return null;
  }

  static Map<String, dynamic> _fields(Map doc) =>
      {for (final e in ((doc['fields'] as Map?) ?? const {}).entries) '${e.key}': dec(e.value as Map)};

  Future<List<Map>> _list(String koleksi) async {
    final hasil = <Map>[];
    String? halaman;
    do {
      final q = 'pageSize=300${halaman == null ? '' : '&pageToken=${Uri.encodeQueryComponent(halaman)}'}';
      final r = await _req('GET', '$_docs/$koleksi?$q', token: await _tokenSah()) as Map? ?? const {};
      hasil.addAll(((r['documents'] as List?) ?? const []).whereType<Map>());
      halaman = r['nextPageToken'] as String?;
    } while (halaman != null);
    return hasil;
  }

  Future<Map<String, dynamic>?> _get(String path) async {
    final d = await _req('GET', '$_docs/$path', token: await _tokenSah());
    return d is Map ? _fields(d) : null;
  }

  Future<void> _put(String path, Map<String, Object?> data) async {
    await _req('PATCH', '$_docs/$path', token: await _tokenSah(), body: {
      'fields': {for (final e in data.entries) e.key: enc(e.value)},
    });
  }

  Future<void> _delete(String path) async {
    try {
      await _req('DELETE', '$_docs/$path', token: await _tokenSah());
    } on AkunGagal {
      // Sudah nggak ada pun nggak apa-apa.
    }
  }

  // ---------------------------------------------------------------- bentuk data

  static final _vid = RegExp(r'^[\w-]{11}$');

  /// Item Android -> item playlist versi Windows (`playlists.norm_item`).
  @visibleForTesting
  static Map<String, dynamic> keDesktop(Track t) {
    final vid = _vid.hasMatch(t.id) ? t.id : null;
    final url = (t.webpageUrl?.startsWith('http') ?? false) ? t.webpageUrl : null;
    final it = <String, dynamic>{
      'iid': t.iid,
      'title': t.title,
      if (t.artist != null) 'artist': t.artist,
      if (t.duration != null) 'duration': t.duration!.inSeconds,
      if (t.thumbUrl != null && t.thumbUrl!.startsWith('http')) 'thumb': t.thumbUrl,
      'mode': t.isVideo ? 'video' : 'audio',
    };
    if (vid != null || url != null) {
      it['kind'] = 'yt';
      it['url'] = url ?? 'https://music.youtube.com/watch?v=$vid';
      if (vid != null) it['videoId'] = vid;
    } else {
      // Berkas di HP tanpa sumber online: di laptop cuma kelihatan, nggak bisa diputar.
      it['kind'] = 'local';
      it['path'] = t.localPath ?? t.id;
      it['localOnly'] = true;
    }
    return it;
  }

  /// Item versi Windows -> Track. Null kalau nggak bisa diputar di HP
  /// (berkas lokal Windows tanpa tautan).
  @visibleForTesting
  static Track? dariDesktop(Map it) {
    final url = (it['url'] is String && (it['url'] as String).startsWith('http')) ? it['url'] as String : null;
    final vid = it['videoId'] is String ? it['videoId'] as String : null;
    final path = it['path'] is String ? it['path'] as String : null;
    final d = it['duration'];
    final durasi = d is num && d > 0 ? Duration(seconds: d.round()) : null;
    final judul = '${it['title'] ?? vid ?? url ?? path ?? 'Tanpa judul'}';
    final artis = it['artist'] is String && (it['artist'] as String).isNotEmpty ? it['artist'] as String : null;
    final video = it['mode'] == 'video';
    final iid = it['iid'] is String ? it['iid'] as String : null;
    final thumb = it['thumb'] is String ? it['thumb'] as String : null;

    if (it['kind'] == 'local' && path != null && path.startsWith('content://')) {
      // Berkas dari HP ini sendiri.
      return Track(id: path, title: judul, artist: artis, duration: durasi, thumbUrl: path, localPath: path, isVideo: video, iid: iid);
    }
    if (vid == null && url == null) return null;
    return Track(
      id: vid ?? url!,
      title: judul,
      artist: artis,
      duration: durasi,
      thumbUrl: thumb ?? (vid == null ? null : 'https://i.ytimg.com/vi/$vid/hqdefault.jpg'),
      webpageUrl: url ?? 'https://music.youtube.com/watch?v=$vid',
      isVideo: video,
      iid: iid,
    );
  }

  static double _detik(DateTime t) => t.millisecondsSinceEpoch / 1000;

  @visibleForTesting
  static Map<String, Object?> bungkus(Playlist p) {
    var items = [...p.lagu.map(keDesktop), ...p.asing];
    var mentah = jsonEncode(items);
    while (utf8.encode(mentah).length > _maksDok && items.isNotEmpty) {
      items = items.sublist(0, (items.length * 0.9).floor());
      mentah = jsonEncode(items);
    }
    return {
      'name': p.nama,
      'created': _detik(p.dibuat),
      'updated': _detik(p.diubah),
      'items': mentah,
    };
  }

  @visibleForTesting
  static Playlist buka(String id, Map<String, dynamic> f) {
    List items;
    try {
      items = jsonDecode('${f['items'] ?? '[]'}') as List;
    } catch (_) {
      items = const [];
    }
    final lagu = <Track>[];
    final asing = <Map<String, dynamic>>[];
    for (final it in items.whereType<Map>()) {
      final t = dariDesktop(it);
      if (t != null) {
        lagu.add(t);
      } else {
        asing.add(Map<String, dynamic>.from(it));
      }
    }
    DateTime waktu(Object? v) =>
        v is num ? DateTime.fromMillisecondsSinceEpoch((v * 1000).round()) : DateTime.fromMillisecondsSinceEpoch(0);
    return Playlist(
      id: id,
      nama: '${f['name'] ?? 'Playlist'}',
      dibuat: waktu(f['created']),
      diubah: waktu(f['updated']),
      lagu: lagu,
      asing: asing,
    );
  }

  // ---------------------------------------------------------------- sinkron

  /// Sinkron beberapa detik setelah playlist diubah (biar hemat tulis).
  void jadwalkan() {
    if (!aktif || !masuk) return;
    _tunda?.cancel();
    _tunda = Timer(const Duration(seconds: 4), () => sinkron(diam: true).ignore());
  }

  bool _lagiSinkron = false;
  bool _ulangi = false;

  /// Gabungkan playlist di HP dengan yang di akun. Per playlist, yang terakhir
  /// diubah yang menang (sama dengan versi Windows).
  Future<void> sinkron({bool diam = false}) async {
    if (!aktif || !masuk) return;
    if (_lagiSinkron) {
      _ulangi = true;
      return;
    }
    _lagiSinkron = true;
    if (!diam) _set(sibuk: true);
    try {
      final svc = PlaylistService.instance;
      if (!svc.sudahMuat) await svc.muat();

      final remote = <String, Playlist>{};
      for (final d in await _list('playlists')) {
        final id = '${d['name']}'.split('/').last;
        remote[id] = buka(id, _fields(d));
      }
      final dihapus = svc.dihapus;
      final lokal = {for (final p in svc.daftar) p.id: p};

      // Item lama tanpa iid dikasih iid tetap dulu.
      for (final p in lokal.values) {
        for (var i = 0; i < p.lagu.length; i++) {
          if (p.lagu[i].iid == null) p.lagu[i] = p.lagu[i].copyWith(iid: PlaylistService.idItem());
        }
      }

      final gabung = <Playlist>[];
      final kirim = <Playlist>[];
      for (final id in {...lokal.keys, ...remote.keys}) {
        final lo = lokal[id];
        final re = remote[id];
        if (lo != null && re != null) {
          final a = _detik(lo.diubah);
          final b = _detik(re.diubah);
          if (a >= b) {
            gabung.add(lo);
            if (a > b) kirim.add(lo);
          } else {
            gabung.add(re);
          }
        } else if (lo != null) {
          gabung.add(lo);
          kirim.add(lo);
        } else if (re != null && !dihapus.contains(id)) {
          gabung.add(re);
        }
      }
      for (final p in kirim) {
        await _put('playlists/${p.id}', bungkus(p));
      }
      for (final id in dihapus) {
        if (remote.containsKey(id)) await _delete('playlists/$id');
      }
      await svc.gantiSemua(gabung, sudahDihapus: dihapus);

      await _sinkronFinds();

      _state['lastSync'] = DateTime.now().millisecondsSinceEpoch / 1000;
      await _simpanState();
      _set(sibuk: false, galat: null);
    } on AkunGagal catch (e) {
      _set(sibuk: false, galat: e.pesan);
      if (!diam) rethrow;
    } catch (e) {
      _set(sibuk: false, galat: 'Sinkron gagal: $e');
      if (!diam) throw AkunGagal('Sinkron gagal: $e');
    } finally {
      _lagiSinkron = false;
      if (_ulangi) {
        _ulangi = false;
        jadwalkan();
      }
    }
  }

  /// Lagu yang pernah dikenali (`meta/finds`), digabung seperti versi Windows.
  Future<void> _sinkronFinds() async {
    final finder = FinderService.instance;
    await finder.muat();
    final r = await _get('meta/finds') ?? const {};
    List rf;
    try {
      rf = jsonDecode('${r['items'] ?? '[]'}') as List;
    } catch (_) {
      rf = const [];
    }
    final lokal = finder.riwayat;
    final ids = {for (final x in lokal) x.id};
    final keys = {for (final x in lokal) if (x.key.isNotEmpty) x.key};
    final baru = <LaguDikenali>[];
    for (final x in rf.whereType<Map>()) {
      final l = LaguDikenali.fromJson(Map<String, dynamic>.from(x));
      if (ids.contains(l.id) || (l.key.isNotEmpty && keys.contains(l.key))) continue;
      baru.add(l);
    }
    final semua = [...lokal, ...baru]..sort((a, b) => b.waktu.compareTo(a.waktu));
    final potong = semua.take(_maksFinds).toList();
    if (baru.isNotEmpty) await finder.gantiSemua(potong);
    final idRemote = {for (final x in rf.whereType<Map>()) x['id']};
    if (!setEquals(idRemote, {for (final x in potong) x.id})) {
      await _put('meta/finds', {
        'items': jsonEncode(potong.map((e) => e.toJson()).toList()),
        'updated': DateTime.now().millisecondsSinceEpoch / 1000,
      });
    }
  }

  void _set({bool? sibuk, Object? galat = _tetap}) {
    if (sibuk != null) _sibuk = sibuk;
    if (!identical(galat, _tetap)) _galat = galat as String?;
    notifyListeners();
  }

  static const _tetap = Object();
}
