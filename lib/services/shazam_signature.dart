import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Sidik jari audio format Shazam, dibuat di HP dari PCM mono 16 kHz.
///
/// Port Dart dari `signature_generator.rs` + `signature_format.rs` milik
/// SongRec (github.com/marin-m/SongRec, GPL-3.0, Marin M.), algoritma yang
/// sama dengan shazamio-core yang dipakai versi Windows. Hasilnya dicek
/// sama dengan shazamio-core di `test/shazam_signature_test.dart`.
///
/// Yang dikirim ke server cuma sidik jari ini, bukan rekaman suaranya.
class ShazamSignature {
  ShazamSignature._(this.uri, this.sampleMs, this.jumlahPuncak);

  /// `data:audio/vnd.shazam.sig;base64,...`
  final String uri;

  /// Panjang audio yang dipakai, dalam milidetik.
  final int sampleMs;

  /// Banyaknya puncak frekuensi yang ketemu. Nol berarti nyaris hening.
  final int jumlahPuncak;

  static const sampleRate = 16000;

  /// Bikin sidik jari dari PCM 16-bit mono 16 kHz.
  static ShazamSignature dariPcm(Int16List pcm) {
    final g = _Generator();
    final pita = g.jalankan(pcm);
    final biner = _encode(pita, pcm.length);
    final ms = (pcm.length / sampleRate * 1000).toInt();
    final jumlah = pita.values.fold<int>(0, (n, l) => n + l.length);
    return ShazamSignature._(
      'data:audio/vnd.shazam.sig;base64,${base64.encode(biner)}',
      ms,
      jumlah,
    );
  }

  /// Sama dengan [dariPcm], dari bytes little-endian.
  static ShazamSignature dariBytes(Uint8List bytes) {
    final n = bytes.lengthInBytes ~/ 2;
    final data = ByteData.sublistView(bytes);
    final pcm = Int16List(n);
    for (var i = 0; i < n; i++) {
      pcm[i] = data.getInt16(i * 2, Endian.little);
    }
    return dariPcm(pcm);
  }

  /// Isi sidik jari, buat tes: pita -> daftar puncak (fft, magnitudo, bin).
  static Map<int, List<(int, int, int)>> uraikan(String uri) {
    final b = base64.decode(uri.substring(uri.indexOf(',') + 1));
    final d = ByteData.sublistView(b);
    final hasil = <int, List<(int, int, int)>>{};
    var o = 56;
    while (o + 8 <= b.length) {
      final pita = d.getUint32(o, Endian.little) - 0x60030040;
      final panjang = d.getUint32(o + 4, Endian.little);
      o += 8;
      final akhir = o + panjang;
      final daftar = <(int, int, int)>[];
      var fft = 0;
      while (o < akhir) {
        var lompat = b[o];
        if (lompat == 0xff) {
          fft = d.getUint32(o + 1, Endian.little);
          o += 5;
          lompat = b[o];
        }
        o += 1;
        fft += lompat;
        daftar.add((fft, d.getUint16(o, Endian.little), d.getUint16(o + 2, Endian.little)));
        o += 4;
      }
      hasil[pita] = daftar;
      o = akhir + ((4 - panjang % 4) % 4);
    }
    return hasil;
  }
}

class _Puncak {
  const _Puncak(this.fft, this.magnitudo, this.bin);
  final int fft;
  final int magnitudo;
  final int bin;
}

/// Inti algoritmanya. Nama variabel sengaja mirip SongRec supaya gampang
/// dicocokkan dengan sumber aslinya.
class _Generator {
  static const _n = 2048;
  static const _bins = 1025;

  /// Jendela Hanning 2048 titik (sama dengan `np.hanning(2050)[1:-1]`).
  static final Float32List _hanning = () {
    final w = Float32List(_n);
    for (var i = 0; i < _n; i++) {
      w[i] = 0.5 - 0.5 * math.cos(2 * math.pi * (i + 1) / (_n + 1));
    }
    return w;
  }();

  // Tabel FFT radix-2 (cos/sin dan urutan bit terbalik).
  static final Float64List _cos = Float64List(_n ~/ 2);
  static final Float64List _sin = Float64List(_n ~/ 2);
  static final Int32List _balik = () {
    for (var i = 0; i < _n ~/ 2; i++) {
      _cos[i] = math.cos(2 * math.pi * i / _n);
      _sin[i] = math.sin(2 * math.pi * i / _n);
    }
    final r = Int32List(_n);
    for (var i = 0, j = 0; i < _n; i++) {
      r[i] = j;
      var bit = _n >> 1;
      while (j & bit != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j |= bit;
    }
    return r;
  }();

  final _sampel = Int16List(_n);
  var _posSampel = 0;

  final _fft = List.generate(256, (_) => Float32List(_bins));
  var _posFft = 0;

  final _sebar = List.generate(256, (_) => Float32List(_bins));
  var _posSebar = 0;
  var _jumlahSebar = 0;

  final _re = Float64List(_n);
  final _im = Float64List(_n);

  final _pita = <int, List<_Puncak>>{};

  Map<int, List<_Puncak>> jalankan(Int16List pcm) {
    for (var i = 0; i + 128 <= pcm.length; i += 128) {
      _lakukanFft(pcm, i);
      _sebarkanPuncak();
      _jumlahSebar++;
      if (_jumlahSebar >= 46) _kenaliPuncak();
    }
    return _pita;
  }

  void _lakukanFft(Int16List pcm, int mulai) {
    _sampel.setRange(_posSampel, _posSampel + 128, pcm, mulai);
    _posSampel = (_posSampel + 128) & 2047;

    // Susun ulang (yang terbaru di belakang) + jendela Hanning. Disimpan
    // lewat bit-reversal supaya FFT di bawah bisa langsung jalan.
    for (var i = 0; i < _n; i++) {
      final v = _f32(_sampel[(i + _posSampel) & 2047] * _hanning[i]);
      final j = _balik[i];
      _re[j] = v;
      _im[j] = 0;
    }

    // FFT kompleks radix-2 di tempat.
    for (var ukuran = 2; ukuran <= _n; ukuran <<= 1) {
      final separuh = ukuran >> 1;
      final langkah = _n ~/ ukuran;
      for (var i = 0; i < _n; i += ukuran) {
        for (var k = 0; k < separuh; k++) {
          final c = _cos[k * langkah];
          final s = -_sin[k * langkah];
          final a = i + k;
          final b = a + separuh;
          final tr = _re[b] * c - _im[b] * s;
          final ti = _re[b] * s + _im[b] * c;
          _re[b] = _re[a] - tr;
          _im[b] = _im[a] - ti;
          _re[a] += tr;
          _im[a] += ti;
        }
      }
    }

    final hasil = _fft[_posFft];
    for (var i = 0; i < _bins; i++) {
      final v = (_re[i] * _re[i] + _im[i] * _im[i]) / (1 << 17);
      hasil[i] = v < 1e-10 ? 1e-10 : v;
    }
    _posFft = (_posFft + 1) & 255;
  }

  void _sebarkanPuncak() {
    final asal = _fft[(_posFft - 1) & 255];
    final sebar = _sebar[_posSebar];
    sebar.setAll(0, asal);

    // Sebar ke frekuensi tetangga.
    for (var p = 0; p <= 1022; p++) {
      sebar[p] = math.max(sebar[p], math.max(sebar[p + 1], sebar[p + 2]));
    }

    // Sebar ke FFT sebelumnya.
    for (var p = 0; p < _bins; p++) {
      final v = sebar[p];
      for (final mundur in const [1, 3, 6]) {
        final lama = _sebar[(_posSebar - mundur) & 255];
        if (v > lama[p]) lama[p] = v;
      }
    }
    _posSebar = (_posSebar + 1) & 255;
  }

  static double _mag(double v) => math.max(math.log(v), 1 / 64) * 1477.3 + 6144.0;

  void _kenaliPuncak() {
    final f46 = _fft[(_posFft - 46) & 255];
    final f49 = _sebar[(_posSebar - 49) & 255];

    for (var bin = 10; bin <= 1014; bin++) {
      final v = f46[bin];
      if (v < 1 / 64 || v < f49[bin - 1]) continue;

      var maksTetangga = 0.0;
      for (final o in const [-10, -7, -4, -3, 1, 2, 5, 8]) {
        maksTetangga = math.max(maksTetangga, f49[bin + o]);
      }
      if (v <= maksTetangga) continue;

      var maksLain = maksTetangga;
      for (final o in const [-53, -45, 165, 172, 179, 186, 193, 200, 214, 221, 228, 235, 242, 249]) {
        maksLain = math.max(maksLain, _sebar[(_posSebar + o) & 255][bin - 1]);
      }
      if (v <= maksLain) continue;

      // Puncak. Hitungannya pakai presisi f32 seperti aslinya.
      final mag = _f32(_mag(v));
      final sebelum = _f32(_mag(f46[bin - 1]));
      final sesudah = _f32(_mag(f46[bin + 1]));
      final variasi1 = _f32(mag * 2 - sebelum - sesudah);
      final variasi2 = _f32((sesudah - sebelum) * 32 / variasi1);
      final binKoreksi = bin * 64 + _keI32(variasi2);
      final hz = _keI32(_f32(binKoreksi * (16000 / 2 / 1024 / 64)));

      final int pita;
      if (hz >= 250 && hz <= 519) {
        pita = 0;
      } else if (hz >= 520 && hz <= 1449) {
        pita = 1;
      } else if (hz >= 1450 && hz <= 3499) {
        pita = 2;
      } else if (hz >= 3500 && hz <= 5500) {
        pita = 3;
      } else {
        continue;
      }

      (_pita[pita] ??= []).add(_Puncak(
        _jumlahSebar - 46,
        mag.clamp(0, 65535).truncate(),
        binKoreksi.clamp(0, 65535),
      ));
    }
  }

  /// `as i32` ala Rust: NaN jadi 0, tak hingga dan angka kelewat besar
  /// mentok di batas i32. `truncate()` Dart malah melempar galat. Kejadian
  /// di HP (12 Nov) waktu suara mikrofon bikin pembaginya nol.
  static int _keI32(double v) {
    if (v.isNaN) return 0;
    if (v >= 2147483647) return 2147483647;
    if (v <= -2147483648) return -2147483648;
    return v.truncate();
  }

  static final _wadah = Float32List(1);
  static double _f32(double v) {
    _wadah[0] = v;
    return _wadah[0];
  }
}

/// Bentuk biner sidik jari (header 48 byte + satu blok per pita frekuensi),
/// sama persis dengan `encode_to_binary` di SongRec.
Uint8List _encode(Map<int, List<_Puncak>> pita, int jumlahSampel) {
  final b = BytesBuilder();
  void u32(int v) {
    final d = ByteData(4)..setUint32(0, v & 0xffffffff, Endian.little);
    b.add(d.buffer.asUint8List());
  }

  u32(0xcafe2580); // magic1
  u32(0); // crc32, diisi belakangan
  u32(0); // ukuran tanpa header, diisi belakangan
  u32(0x94119c00); // magic2
  u32(0);
  u32(0);
  u32(0);
  u32(3 << 27); // id sample rate 16000
  u32(0);
  u32(0);
  u32(jumlahSampel + (16000 * 0.24).toInt());
  u32((15 << 19) + 0x40000);
  u32(0x40000000);
  u32(0); // ukuran lagi

  for (final kunci in pita.keys.toList()..sort()) {
    final isi = BytesBuilder();
    var fft = 0;
    for (final p in pita[kunci]!) {
      if (p.fft - fft >= 255) {
        isi.addByte(0xff);
        isi.add((ByteData(4)..setUint32(0, p.fft, Endian.little)).buffer.asUint8List());
        fft = p.fft;
      }
      isi.addByte(p.fft - fft);
      isi.add((ByteData(4)
            ..setUint16(0, p.magnitudo, Endian.little)
            ..setUint16(2, p.bin, Endian.little))
          .buffer
          .asUint8List());
      fft = p.fft;
    }
    final bytes = isi.takeBytes();
    u32(0x60030040 + kunci);
    u32(bytes.length);
    b.add(bytes);
    for (var i = 0; i < (4 - bytes.length % 4) % 4; i++) {
      b.addByte(0);
    }
  }

  final hasil = b.takeBytes();
  final d = ByteData.sublistView(hasil);
  d.setUint32(8, hasil.length - 48, Endian.little);
  d.setUint32(52, hasil.length - 48, Endian.little);
  d.setUint32(4, _crc32(hasil, 8), Endian.little);
  return hasil;
}

final Uint32List _tabelCrc = () {
  final t = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
    }
    t[n] = c;
  }
  return t;
}();

int _crc32(Uint8List data, int mulai) {
  var c = 0xffffffff;
  for (var i = mulai; i < data.length; i++) {
    c = _tabelCrc[(c ^ data[i]) & 0xff] ^ (c >> 8);
  }
  return (c ^ 0xffffffff) & 0xffffffff;
}
