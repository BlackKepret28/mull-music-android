import 'package:flutter_test/flutter_test.dart';
import 'package:mullmusic/services/riwayat_cari.dart';
import 'package:mullmusic/services/saran_cari.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SaranCari.urai', () {
    test('mengambil daftar saran dari bentuk jawaban YouTube', () {
      expect(
        SaranCari.urai('["hindia",["hindia evaluasi","hindia membasuh","  "]]'),
        ['hindia evaluasi', 'hindia membasuh'],
      );
    });

    test('maksimal 8 saran', () {
      final banyak = List.generate(12, (i) => '"s$i"').join(',');
      expect(SaranCari.urai('["x",[$banyak]]'), hasLength(8));
    });

    test('jawaban rusak = daftar kosong', () {
      expect(SaranCari.urai('bukan json'), isEmpty);
      expect(SaranCari.urai('["x"]'), isEmpty);
    });
  });

  group('RiwayatCari', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await RiwayatCari.instance.kosongkan();
    });

    test('yang terbaru di atas, tanpa dobel (huruf besar kecil sama)', () async {
      final r = RiwayatCari.instance;
      await r.catat('hindia');
      await r.catat('pamungkas');
      await r.catat('HINDIA');
      expect(r.daftar, ['HINDIA', 'pamungkas']);
    });

    test('maksimal 20 dan bisa dihapus satu per satu', () async {
      final r = RiwayatCari.instance;
      for (var i = 0; i < 25; i++) {
        await r.catat('lagu $i');
      }
      expect(r.daftar, hasLength(20));
      expect(r.daftar.first, 'lagu 24');
      await r.hapus('lagu 24');
      expect(r.daftar.first, 'lagu 23');
    });
  });
}
