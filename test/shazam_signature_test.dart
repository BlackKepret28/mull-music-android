import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/services/shazam_signature.dart';

/// Pembanding: `test/fixtures/signatures.json` dibuat shazamio-core 2.0.0
/// (yang dipakai versi Windows) dari dua WAV sintetis di folder yang sama.
void main() {
  final ref = jsonDecode(File('test/fixtures/signatures.json').readAsStringSync()) as Map;

  Int16List bacaWav(String nama) {
    final b = File('test/fixtures/$nama.wav').readAsBytesSync();
    return Int16List.sublistView(Uint8List.fromList(b.sublist(44)));
  }

  for (final nama in ['sig_a', 'sig_b']) {
    test('sidik jari $nama sama dengan shazamio-core', () {
      final r = ref[nama] as Map;
      final s = ShazamSignature.dariPcm(bacaWav(nama));
      expect(s.sampleMs, r['samplems']);
      expect(s.jumlahPuncak, greaterThan(50));

      final kita = ShazamSignature.uraikan(s.uri);
      final mereka = ShazamSignature.uraikan(r['uri'] as String);
      expect(kita.keys.toSet(), mereka.keys.toSet());

      // Header harus identik (kecuali crc dan ukuran, yang ikut jumlah puncak).
      final hb = base64.decode((r['uri'] as String).split(',')[1]);
      final kb = base64.decode(s.uri.split(',')[1]);
      expect(kb.sublist(12, 48), hb.sublist(12, 48));
      expect(kb.sublist(48, 52), hb.sublist(48, 52));

      // Posisi puncak (nomor FFT + bin frekuensi) itu yang dipakai buat
      // mencocokkan lagu, dan harus hampir semuanya sama. Magnitudonya
      // boleh beda sedikit: shazamio-core menyaring ulang WAV sebelum
      // dihitung, kita pakai sampelnya apa adanya (seperti SongRec).
      var sama = 0;
      var total = 0;
      for (final pita in mereka.keys) {
        final a = {for (final p in mereka[pita]!) (p.$1, p.$3): p.$2};
        final b = {for (final p in kita[pita]!) (p.$1, p.$3): p.$2};
        for (final k in a.keys) {
          final m = b[k];
          if (m != null && (m - a[k]!).abs() < 400) sama++;
        }
        total += a.length > b.length ? a.length : b.length;
      }
      expect(sama / total, greaterThan(0.85), reason: '$sama dari $total puncak sama');
    });
  }

  test('derau mikrofon (pelan, keras, hening berselang) nggak bikin galat', () {
    final acak = Random(3);
    final pcm = Int16List(16000 * 12);
    for (var i = 0; i < pcm.length; i++) {
      final bagian = (i ~/ 8000) % 4;
      pcm[i] = switch (bagian) {
        0 => 0,
        1 => acak.nextInt(3) - 1,
        2 => acak.nextInt(65535) - 32768,
        _ => acak.nextInt(200) - 100,
      };
    }
    final s = ShazamSignature.dariPcm(pcm);
    expect(s.uri, startsWith('data:audio/vnd.shazam.sig;base64,'));
  });

  test('hening nggak ngasih puncak', () {
    final s = ShazamSignature.dariPcm(Int16List(16000 * 5));
    expect(s.jumlahPuncak, 0);
    expect(s.uri, startsWith('data:audio/vnd.shazam.sig;base64,'));
  });
}
