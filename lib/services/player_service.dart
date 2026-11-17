import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';
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
      skipToNext();
    });
  }

  void _siarkan({bool memuat = false, bool mati = false}) {
    final p = _p;
    final main = p?.playing ?? false;

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (main) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
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

  MediaItem _item(Track t) => MediaItem(
        id: t.id,
        title: t.title,
        artist: t.artist,
        duration: t.duration,
        artUri: t.thumbUrl == null ? null : Uri.tryParse(t.thumbUrl!),
        extras: {'url': t.resolvableUrl},
      );

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
        await _player.setUrl(url);
      }
      if (aku != _token) return;

      // Durasi dari yt-dlp kadang kosong; pakai yang dibaca pemutar.
      final durasi = _player.duration;
      if (durasi != null && t.duration == null) {
        mediaItem.add(_item(t).copyWith(duration: durasi));
      }

      await _player.play();
      // Dicatat setelah benar-benar jalan, supaya lagu yang gagal diputar
      // nggak ikut masuk "Baru diputar".
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

  @override
  Future<void> skipToNext() async {
    if (_ulang == AudioServiceRepeatMode.one) {
      await seek(Duration.zero);
      await play();
      return;
    }
    if (_pos + 1 < _urut.length) {
      await _putarPosisi(_pos + 1);
    } else if (_ulang == AudioServiceRepeatMode.all && _urut.isNotEmpty) {
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
  await AudioService.init(
    builder: () => MullAudioHandler.instance,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mulya.mullmusic.audio',
      androidNotificationChannelName: 'Pemutar Mull',
      androidNotificationIcon: 'drawable/ic_stat_mull',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
