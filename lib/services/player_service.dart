import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import '../ytdlp.dart';
import 'innertube.dart';
import 'log_service.dart';
import 'recent_service.dart';
import 'ytdlp_service.dart';

/// Pemutar audio + integrasi notifikasi/layar kunci lewat audio_service.
///
/// Antreannya diurus sendiri (bukan ConcatenatingAudioSource) karena tiap
/// lagu butuh URL stream baru dari yt-dlp, dan URL itu baru diambil pas
/// lagunya mau diputar. Lagu berikutnya disiapkan di latar belakang.
class MullAudioHandler extends BaseAudioHandler with SeekHandler {
  MullAudioHandler._();
  static final instance = MullAudioHandler._();

  final _yt = YtDlpService.instance;

  /// Dibikin pas pertama dipakai supaya tes widget yang nggak muter apa pun
  /// nggak perlu plugin just_audio.
  AudioPlayer? _p;
  AudioPlayer get _player {
    final ada = _p;
    if (ada != null) return ada;
    final baru = AudioPlayer(
      // Mulai bunyi begitu ~1 detik audio terkumpul (bawaan 2,5 detik).
      // Cuma soal buffer awal, kualitas suara nggak berubah.
      audioLoadConfiguration: const AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          bufferForPlaybackDuration: Duration(seconds: 1),
          bufferForPlaybackAfterRebufferDuration: Duration(seconds: 3),
        ),
      ),
    );
    _p = baru;
    _pasangPendengar(baru);
    return baru;
  }

  final List<Track> _antrean = [];

  /// Urutan putar: isinya indeks ke [_antrean]. Waktu acak dinyalakan, yang
  /// diaduk cuma daftar ini, isi antreannya tetap utuh. Jadi acak bisa
  /// dimatikan lagi tanpa kehilangan urutan aslinya.
  List<int> _urut = [];

  /// Posisi di [_urut], bukan di [_antrean].
  int _pos = -1;

  int get _index => _pos >= 0 && _pos < _urut.length ? _urut[_pos] : -1;

  bool _acakNyala = false;
  bool get acakNyala => _acakNyala;

  AudioServiceRepeatMode _ulang = AudioServiceRepeatMode.none;
  AudioServiceRepeatMode get modeUlang => _ulang;

  /// Nomor urut permintaan, biar hasil yt-dlp yang telat datang nggak
  /// menimpa lagu yang sudah diganti pengguna.
  int _token = 0;

  /// Galat terakhir yang perlu ditunjukkan ke pengguna.
  final galat = ValueNotifier<String?>(null);

  /// Timer tidur: kapan pemutaran dijeda, atau null kalau mati.
  final timerSampai = ValueNotifier<DateTime?>(null);

  /// Timer tidur "akhir lagu ini": jeda waktu lagu yang sekarang habis.
  final jedaAkhirLagu = ValueNotifier<bool>(false);
  Timer? _timer;

  /// Kecepatan putar (1.0 = normal).
  final kecepatan = ValueNotifier<double>(1.0);

  List<Track> get antrean => List.unmodifiable(_antrean);
  Track? get current => _index >= 0 && _index < _antrean.length ? _antrean[_index] : null;

  /// Posisi buat layar Sedang diputar dan lirik: 4x per detik sudah mulus.
  /// `positionStream` bawaan just_audio bisa sampai ~60x per detik, dan tiap
  /// pancaran bikin panel kaca (blur) digambar ulang. Ini cuma soal tampilan;
  /// pemutaran audionya sendiri nggak tersentuh.
  Stream<Duration> get positionStream => _posisi ??= _player
      .createPositionStream(
        minPeriod: const Duration(milliseconds: 250),
        maxPeriod: const Duration(milliseconds: 250),
      )
      .asBroadcastStream();
  Stream<Duration>? _posisi;

  /// Posisi buat bar progres pemutar mini: sekali per detik cukup.
  Stream<Duration> get positionStreamLambat => _posisiLambat ??= _player
      .createPositionStream(
        minPeriod: const Duration(seconds: 1),
        maxPeriod: const Duration(seconds: 1),
      )
      .asBroadcastStream();
  Stream<Duration>? _posisiLambat;
  Duration get position => _p?.position ?? Duration.zero;

  void _pasangPendengar(AudioPlayer p) {
    p.playbackEventStream.listen(
      (_) => _siarkan(),
      onError: (Object e, StackTrace _) {
        galat.value = 'Gagal memutar. Coba lagi atau pilih lagu lain.';
        _siarkan(mati: true);
      },
    );

    // Lagu habis: lanjut ke berikutnya kalau ada (atau berhenti kalau
    // timer tidur disetel "akhir lagu ini").
    p.processingStateStream.listen((s) {
      if (s != ProcessingState.completed) return;
      if (jedaAkhirLagu.value) {
        jedaAkhirLagu.value = false;
        p.pause();
        p.seek(Duration.zero);
        return;
      }
      _lanjutOtomatis();
    });
  }

  String _stateTerakhir = '';
  int _probeKali = 0;

  void _siarkan({bool memuat = false, bool mati = false}) {
    final ringkas = 'playing=${_p?.playing} proses=${_p?.processingState.name} memuat=$memuat mati=$mati';
    if (ringkas != _stateTerakhir) {
      _stateTerakhir = ringkas;
      LogService.instance.catat('state', ringkas);
    }
    final p = _p;
    final main = p?.playing ?? false;

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (main) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        // Tombol Tutup (X) menggantikan kotak Stop bawaan.
        const MediaControl(
          androidIcon: 'drawable/ic_notif_close',
          label: 'Tutup',
          action: MediaAction.stop,
        ),
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: mati
          ? AudioProcessingState.error
          : memuat
              ? AudioProcessingState.loading
              : switch (p?.processingState) {
                  null || ProcessingState.idle => AudioProcessingState.idle,
                  ProcessingState.loading => AudioProcessingState.loading,
                  ProcessingState.buffering => AudioProcessingState.buffering,
                  ProcessingState.ready => AudioProcessingState.ready,
                  ProcessingState.completed => AudioProcessingState.completed,
                },
      playing: main,
      repeatMode: _ulang,
      shuffleMode:
          _acakNyala ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      updatePosition: p?.position ?? Duration.zero,
      bufferedPosition: p?.bufferedPosition ?? Duration.zero,
      speed: p?.speed ?? 1.0,
      queueIndex: _index < 0 ? null : _index,
    ));
  }

  MediaItem _item(Track t) {
    final url = _urlSampul(t);
    return MediaItem(
      id: t.id,
      title: t.title,
      artist: t.artist,
      duration: t.duration,
      // Kalau sampul sudah diunduh sendiri, pakai berkasnya (cepat, dan nggak
      // bergantung pada pengunduh gambar bawaan audio_service).
      artUri: _sampulLokal[t.id] ?? (url == null ? null : Uri.tryParse(url)),
      extras: {'url': t.resolvableUrl},
    );
  }

  /// Sampul lagu: gambar dari hasil pencarian, atau gambar bawaan YouTube
  /// (16:9 tanpa pita hitam) kalau lagunya dari YouTube tapi nggak punya sampul.
  String? _urlSampul(Track t) {
    final u = t.thumbUrl;
    if (u != null && u.isNotEmpty) return u;
    if (t.localPath == null && Innertube.bisaDipakai(t.id)) {
      return 'https://i.ytimg.com/vi/${t.id}/mqdefault.jpg';
    }
    return null;
  }

  final _sampulLokal = <String, Uri>{};

  /// Unduh sampul ke berkas, lalu kirim ulang ke notifikasi sebagai file://.
  void _pasangSampulLokal(Track t, int aku) {
    final url = _urlSampul(t);
    if (url == null || url.startsWith('file:') || url.startsWith('content:')) return;
    if (_sampulLokal.containsKey(t.id)) return;
    _unduhSampul(url, t.id).then((uri) {
      if (uri == null) return;
      _sampulLokal[t.id] = uri;
      if (aku == _token) {
        mediaItem.add(_item(t).copyWith(duration: mediaItem.value?.duration ?? t.duration));
      }
    });
  }

  Future<Uri?> _unduhSampul(String url, String id) async {
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/sampul');
      if (!await dir.exists()) await dir.create(recursive: true);
      final nama = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final f = File('${dir.path}/$nama.jpg');
      if (!await f.exists() || await f.length() < 500) {
        final klien = HttpClient()..connectionTimeout = const Duration(seconds: 6);
        try {
          final req = await klien.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 6));
          final res = await req.close().timeout(const Duration(seconds: 8));
          if (res.statusCode != 200) {
            await res.drain<void>();
            throw Exception('HTTP ${res.statusCode}');
          }
          await f.writeAsBytes(await consolidateHttpClientResponseBytes(res));
        } finally {
          klien.close(force: true);
        }
      }
      return f.uri;
    } catch (e) {
      LogService.instance.catat('sampul', 'gagal unduh sampul ($url): $e');
      return null;
    }
  }

  /// Putar satu lagu, antrean diisi lagu itu saja.
  Future<void> putarSatu(Track t) => putar([t], 0);

  static final _acak = Random();

  /// Nyalakan acak lalu putar dari awal urutan acaknya.
  Future<void> putarAcak(List<Track> daftar) async {
    _acakNyala = true;
    await putar(daftar, 0);
  }

  /// Susun [_urut]. Lagu yang sedang diputar selalu ditaruh paling depan,
  /// supaya menyalakan acak di tengah lagu nggak bikin lagunya ikut lompat.
  void _susunUrutan({required int mulaiDari}) {
    final semua = List<int>.generate(_antrean.length, (i) => i);
    if (!_acakNyala) {
      _urut = semua;
      _pos = mulaiDari.clamp(0, _urut.length - 1);
      return;
    }
    semua.remove(mulaiDari);
    semua.shuffle(_acak);
    _urut = [mulaiDari, ...semua];
    _pos = 0;
  }

  /// Putar daftar lagu mulai dari indeks [mulai] (indeks di [daftar]).
  Future<void> putar(List<Track> daftar, int mulai) async {
    if (daftar.isEmpty) return;
    _antrean
      ..clear()
      ..addAll(daftar);
    queue.add(daftar.map(_item).toList());
    _susunUrutan(mulaiDari: mulai.clamp(0, daftar.length - 1));
    await _putarPosisi(_pos);
  }

  /// Sisipkan lagu tepat setelah yang sedang diputar.
  Future<void> putarBerikutnya(Track t) async {
    if (_index < 0 || _antrean.isEmpty) {
      await putar([t], 0);
      return;
    }
    _antrean.add(t);
    _urut.insert(_pos + 1, _antrean.length - 1);
    queue.add(_antrean.map(_item).toList());
    _siarkan();
    if (t.localPath == null) _yt.prefetch(t);
  }

  /// Tambah ke akhir antrean.
  Future<void> tambahKeAntrean(Track t) async {
    if (_index < 0 || _antrean.isEmpty) {
      await putar([t], 0);
      return;
    }
    _antrean.add(t);
    _urut.add(_antrean.length - 1);
    queue.add(_antrean.map(_item).toList());
    _siarkan();
  }

  /// Timer tidur. [durasi] null mematikan. [akhirLagu]: jeda waktu lagu
  /// yang sekarang selesai.
  void aturTimer(Duration? durasi, {bool akhirLagu = false}) {
    _timer?.cancel();
    _timer = null;
    timerSampai.value = null;
    jedaAkhirLagu.value = akhirLagu;
    if (durasi == null) return;
    timerSampai.value = DateTime.now().add(durasi);
    _timer = Timer(durasi, () {
      timerSampai.value = null;
      pause();
    });
  }

  Future<void> aturKecepatan(double v) async {
    kecepatan.value = v;
    await _player.setSpeed(v);
    _siarkan();
  }

  @override
  Future<void> setSpeed(double speed) => aturKecepatan(speed);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final nyala = shuffleMode != AudioServiceShuffleMode.none;
    if (nyala == _acakNyala) return;
    _acakNyala = nyala;
    final sekarang = _index;
    if (sekarang >= 0) _susunUrutan(mulaiDari: sekarang);
    _siarkan();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _ulang = repeatMode;
    _siarkan();
  }

  /// 4 detik setelah lagu mulai, tanya sistem apakah layanan pemutar jalan dan
  /// notifikasinya terpasang, lalu tulis ke log. Cuma 3 kali per sesi.
  void _periksaNotifikasi(int aku) {
    if (_probeKali >= 3) return;
    _probeKali++;
    Future<void>.delayed(const Duration(seconds: 4), () async {
      if (aku != _token) return;
      try {
        final d = await YtDlp.diagNotifikasi();
        LogService.instance.catat(
          'notif',
          'playing=${_p?.playing} layananJalan=${d['layananJalan']} notifAktif=${d['notifAktif']} '
              'notifikasi=${d['notifikasi']} saluran=${d['saluran']}',
        );
        // Log sistem pada saat ini (buffer Android pendek, nanti keburu terhapus).
        final lc = (await YtDlp.getLogcat()).split('\n');
        final ekor = lc.length > 40 ? lc.sublist(lc.length - 40) : lc;
        LogService.instance.catat('logcat', ekor.join('\n'));
      } catch (e) {
        LogService.instance.catat('notif', 'diagnostik gagal: $e');
      }
    });
  }

  /// Pindah ke posisi tertentu di [_urut].
  Future<void> _putarPosisi(int pos) async {
    if (pos < 0 || pos >= _urut.length) return;
    _pos = pos;
    await _muatLagu(_urut[pos]);
  }

  Future<void> _muatLagu(int i) async {
    if (i < 0 || i >= _antrean.length) return;

    final aku = ++_token;
    final t = _antrean[i];

    mediaItem.add(_item(t));
    _pasangSampulLokal(t, aku);
    galat.value = null;
    _siarkan(memuat: true);

    try {
      // Berkas yang sudah diunduh diputar langsung dari MediaStore:
      // nggak perlu internet, nggak perlu QuickJS.
      final lokal = t.localPath;
      if (lokal != null) {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(lokal)));
      } else {
        final url = await _yt.streamUrl(t);
        // Pengguna keburu ganti lagu: buang hasil ini.
        if (aku != _token) return;
        await _player.setUrl(url, headers: _yt.headerUntuk(url));
      }
      if (aku != _token) return;

      // Durasi dari yt-dlp kadang kosong; pakai yang dibaca pemutar.
      final durasi = _player.duration;
      if (durasi != null && t.duration == null) {
        mediaItem.add(_item(t).copyWith(duration: durasi));
      }

      // JANGAN di-await: Future play() baru selesai saat lagunya habis atau
      // dijeda. Dulu baris di bawahnya (prefetch lagu berikutnya, catat
      // "Baru diputar") baru jalan setelah lagu kelar, jadi tiap lagu
      // berikutnya selalu mulai dari nol.
      unawaited(_player.play().catchError((Object e) {
        if (aku != _token) return;
        galat.value = e.toString().replaceFirst('Exception: ', '');
        LogService.instance.catat('play', 'play() gagal: $e');
        _siarkan(mati: true);
      }));
      _periksaNotifikasi(aku);
      // Dicatat setelah sumbernya berhasil dimuat, supaya lagu yang gagal
      // diputar nggak ikut masuk "Baru diputar".
      RecentService.instance.catat(t).ignore();
      _siapkanBerikutnya();
    } catch (e) {
      if (aku != _token) return;
      galat.value = e.toString().replaceFirst('Exception: ', '');
      _siarkan(mati: true);
    }
  }

  /// Ambil URL lagu berikutnya duluan, karena yt-dlp butuh waktu.
  /// Ikut urutan putar (jadi waktu acak nyala, yang disiapkan ya yang acak).
  /// Berkas lokal nggak perlu disiapkan.
  void _siapkanBerikutnya() {
    for (var k = 1; k <= 2; k++) {
      final j = _pos + k;
      if (j >= _urut.length) return;
      final t = _antrean[_urut[j]];
      if (t.localPath == null) _yt.prefetch(t);
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Lagu habis sendiri: ulang-satu memutar lagu yang sama lagi.
  Future<void> _lanjutOtomatis() async {
    if (_ulang == AudioServiceRepeatMode.one) {
      await seek(Duration.zero);
      await play();
      return;
    }
    await _keBerikutnya();
  }

  /// Tombol Berikutnya (app maupun notifikasi) selalu pindah lagu, juga saat
  /// mode ulang-satu menyala (dulu malah memutar lagu yang sama).
  @override
  Future<void> skipToNext() => _keBerikutnya();

  Future<void> _keBerikutnya() async {
    final ulangSemua =
        _ulang == AudioServiceRepeatMode.all || _ulang == AudioServiceRepeatMode.one;
    if (_pos + 1 < _urut.length) {
      await _putarPosisi(_pos + 1);
    } else if (ulangSemua && _urut.isNotEmpty) {
      await _putarPosisi(0);
    } else {
      await stop();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // Kebiasaan umum: kalau sudah lewat 5 detik, balik ke awal lagu dulu.
    if (_p != null && _p!.position > const Duration(seconds: 5)) {
      await seek(Duration.zero);
      return;
    }
    if (_pos > 0) {
      await _putarPosisi(_pos - 1);
    } else if (_ulang == AudioServiceRepeatMode.all && _urut.isNotEmpty) {
      await _putarPosisi(_urut.length - 1);
    } else {
      await seek(Duration.zero);
    }
  }

  /// [index] di sini indeks antrean yang dilihat pengguna, bukan urutan putar.
  @override
  Future<void> skipToQueueItem(int index) async {
    final pos = _urut.indexOf(index);
    if (pos >= 0) await _putarPosisi(pos);
  }

  @override
  Future<void> stop() async {
    _token++;
    await _p?.stop();
    _pos = -1;
    mediaItem.add(null);
    _siarkan();
    await super.stop();
  }

  /// Ulangi lagu yang gagal.
  Future<void> cobaLagi() async {
    if (_pos >= 0) await _putarPosisi(_pos);
  }
}

/// Dipanggil sekali dari `main()`.
Future<void> initAudio() async {
  // audio_service menelan semua error dari sisi Android (mis. gagal membuat
  // notifikasi) dan cuma menaruhnya di stream ini. Tanpa pendengar, error itu
  // nggak pernah kelihatan. Sekarang dicatat ke log.
  AudioService.asyncError.listen(
    (e) => LogService.instance.catat('audio_service', 'ERROR dari sisi Android: $e'),
  );
  await AudioService.init(
    builder: () => MullAudioHandler.instance,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mulya.mullmusic.audio',
      androidNotificationChannelName: 'Pemutar Mull',
      androidNotificationIcon: 'drawable/ic_notif_logo',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
