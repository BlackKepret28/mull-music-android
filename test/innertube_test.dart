import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/services/innertube.dart';

Map<String, dynamic> _format(String mime, int bitrate, {String? url, Map<String, dynamic>? trek}) => {
      'mimeType': mime,
      'bitrate': bitrate,
      'url': url ?? 'https://x/$bitrate',
      'audioTrack': ?trek,
    };

void main() {
  group('Innertube', () {
    test('id video harus 11 karakter YouTube', () {
      expect(Innertube.bisaDipakai('dQw4w9WgXcQ'), isTrue);
      expect(Innertube.bisaDipakai('abc'), isFalse);
      expect(Innertube.bisaDipakai('https://youtu.be/dQw4w9WgXcQ'), isFalse);
    });

    test('pilihAudio ambil m4a bitrate tertinggi, abaikan video dan webm', () {
      final json = {
        'playabilityStatus': {'status': 'OK'},
        'streamingData': {
          'adaptiveFormats': [
            _format('video/mp4; codecs="avc1"', 900000),
            _format('audio/webm; codecs="opus"', 160000),
            _format('audio/mp4; codecs="mp4a.40.2"', 48000),
            _format('audio/mp4; codecs="mp4a.40.2"', 128000),
          ],
        },
      };
      expect(Innertube.pilihAudio(json), 'https://x/128000');
    });

    test('pilihAudio melewati trek dubbing non-bawaan', () {
      final json = {
        'playabilityStatus': {'status': 'OK'},
        'streamingData': {
          'adaptiveFormats': [
            _format('audio/mp4', 130000, trek: {'audioIsDefault': false}),
            _format('audio/mp4', 128000, trek: {'audioIsDefault': true}),
          ],
        },
      };
      expect(Innertube.pilihAudio(json), 'https://x/128000');
    });

    test('pilihAudio null kalau tidak OK atau tanpa URL', () {
      expect(Innertube.pilihAudio({'playabilityStatus': {'status': 'LOGIN_REQUIRED'}}), isNull);
      expect(
        Innertube.pilihAudio({
          'playabilityStatus': {'status': 'OK'},
          'streamingData': {
            'adaptiveFormats': [
              {'mimeType': 'audio/mp4', 'bitrate': 128000},
            ],
          },
        }),
        isNull,
      );
    });
  });
}
