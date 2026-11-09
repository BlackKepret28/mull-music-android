import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';
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
    final baru = AudioPlayer();
    _p = baru;
    _pasangPendengar(baru);
    return baru;
  }

  final List<Track> _antrean = [];
  int _index = -1;

  /// Nomor urut permintaan, biar hasil yt-dlp yang telat datang nggak
  /// menimpa lagu yang sudah diganti pengguna.
  int _token = 0;

  /// Galat terakhir yang perlu ditunjukkan ke pengguna.
  final galat = ValueNotifier<String?>(null);

  List<Track> get antrean => List.unmodifiable(_antrean);
  Track? get current => _index >= 0 && _index < _antrean.length ? _antrean[_index] : null;

  Stream<Duration> get positionStream => _player.positionStream;
  Duration get position => _p?.position ?? Duration.zero;

  void _pasangPendengar(AudioPlayer p) {
    p.playbackEventStream.listen(
      (_) => _siarkan(),
      onError: (Object e, StackTrace _) {
        galat.value = 'Gagal memutar. Coba lagi atau pilih lagu lain.';
        _siarkan(mati: true);
      },
    );

    // Lagu habis: lanjut ke berikutnya kalau ada.
    p.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) skipToNext();
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

  /// Putar daftar lagu mulai dari indeks [mulai].
  Future<void> putar(List<Track> daftar, int mulai) async {
    if (daftar.isEmpty) return;
    _antrean
      ..clear()
      ..addAll(daftar);
    queue.add(daftar.map(_item).toList());
    await _pindahKe(mulai.clamp(0, daftar.length - 1));
  }

  Future<void> _pindahKe(int i) async {
    if (i < 0 || i >= _antrean.length) return;

    final aku = ++_token;
    _index = i;
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
      _siapkanBerikutnya();
    } catch (e) {
      if (aku != _token) return;
      galat.value = e.toString().replaceFirst('Exception: ', '');
      _siarkan(mati: true);
    }
  }

  /// Ambil URL lagu berikutnya duluan, karena yt-dlp butuh waktu.
  /// Berkas lokal nggak perlu disiapkan.
  void _siapkanBerikutnya() {
    final j = _index + 1;
    if (j >= _antrean.length) return;
    final t = _antrean[j];
    if (t.localPath == null) _yt.prefetch(t);
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
    if (_index + 1 < _antrean.length) {
      await _pindahKe(_index + 1);
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
    if (_index > 0) await _pindahKe(_index - 1);
  }

  @override
  Future<void> skipToQueueItem(int index) => _pindahKe(index);

  @override
  Future<void> stop() async {
    _token++;
    await _p?.stop();
    _index = -1;
    mediaItem.add(null);
    _siarkan();
    await super.stop();
  }

  /// Ulangi lagu yang gagal.
  Future<void> cobaLagi() async {
    if (_index >= 0) await _pindahKe(_index);
  }
}

/// Dipanggil sekali dari `main()`.
Future<void> initAudio() async {
  await AudioService.init(
    builder: () => MullAudioHandler.instance,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mulya.mullmusic.audio',
      androidNotificationChannelName: 'Pemutar Mull',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
