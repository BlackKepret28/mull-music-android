# Mull Music App untuk Android

Aplikasi Android buat cari, putar, dan unduh musik serta video, dibangun di
atas [yt-dlp](https://github.com/yt-dlp/yt-dlp). Ini versi Android dari Mull
Music App yang sebelumnya cuma ada di Windows.

Statusnya masih dalam pengembangan dan belum pernah dirilis.

## Yang sudah bisa

- **Cari** lagu atau video lewat YouTube, atau tempel tautannya langsung.
- **Putar** tanpa harus diunduh dulu, lengkap dengan notifikasi dan kontrol
  di layar kunci. Musiknya tetap jalan waktu aplikasi ditinggal.
- **Lirik** dari [LRCLIB](https://lrclib.net), ikut bergulir kalau liriknya
  bertanda waktu. Ketuk satu baris buat lompat ke bagian itu.
- **Unduh** jadi berkas audio (m4a atau opus) atau video 720p. Hasilnya masuk
  ke `Music/Mull` dan `Movies/Mull`, jadi kebaca aplikasi musik dan galeri
  lain, dan nggak ikut terhapus waktu Mull dicopot.
- **Pustaka** berisi berkas yang sudah ada di HP, bisa diputar tanpa internet.
- **Playlist** buatan sendiri, disimpan lokal.
- **Tema terang dan gelap**, plus efek kaca yang bisa dimatikan.

Belum ada: Kenali lagu, impor dari Spotify, akun, dan sinkron dengan versi
Windows.

## Pasang

Belum ada rilis resmi. Buat sekarang APK-nya harus dibangun sendiri (lihat
bagian berikutnya).

Butuh Android 10 (API 29) atau lebih baru. Kalau mau notifikasi pemutarnya
muncul, izinkan notifikasi waktu aplikasi memintanya.

## Membangun sendiri

Butuh Flutter 3.47 atau lebih baru dan Android SDK.

```bash
flutter pub get
```

```bash
flutter build apk --release
```

Hasilnya ada di `build/app/outputs/flutter-apk/app-release.apk`.

Untuk menjalankan langsung ke HP yang tersambung:

```bash
flutter run --release
```

APK debug ukurannya jauh lebih besar (sekitar 200 MB) karena cara AGP
mengemas berkas. Kalau ruang HP pas-pasan, pakai yang release.

### Menjalankan pemeriksaan

```bash
flutter analyze
```

```bash
flutter test
```

## Tempat berkas

| Isi | Tempat |
| --- | --- |
| Lagu hasil unduhan | `Music/Mull` (lewat MediaStore) |
| Video hasil unduhan | `Movies/Mull` (lewat MediaStore) |
| Lirik tersimpan | folder data aplikasi, `lirik/<id>.lrc` |
| Playlist | folder data aplikasi, `playlists.json` |
| Pengaturan | penyimpanan pengaturan Android |

Berkas lagu dan video sengaja ditaruh di penyimpanan bersama supaya tetap ada
setelah aplikasi dicopot. Lirik, playlist, dan pengaturan ikut terhapus kalau
aplikasinya dicopot.

## Catatan soal kecepatan

Sebagian pekerjaan yt-dlp dijalankan di HP memakai mesin JavaScript QuickJS.
Pekerjaan itu berat:

- **Cari** cepat (hitungan detik) karena cuma mengambil keterangan lagu dan
  nggak perlu JavaScript.
- **Memutar atau mengunduh dari YouTube** butuh sekitar 25 sampai 35 detik di
  awal, karena tautan aslinya harus dipecahkan dulu di HP. Mull menyiapkan
  tautan lagu berikutnya di latar belakang supaya jeda ini cuma kerasa sekali.
- **Berkas yang sudah diunduh** langsung jalan, tanpa internet.

## Rilis

APK rilis dibangun GitHub Actions (`.github/workflows/release.yml`) waktu tag
`v*` di-push. Tag harus sama dengan `version:` di `pubspec.yaml`, tanpa huruf
`v` dan tanpa bagian `+build`; kalau beda, workflow-nya berhenti.

```bash
git tag v0.1.0
```

```bash
git push origin v0.1.0
```

Sebelum rilis pertama, kunci tanda tangan harus dibuat sekali:

```bash
keytool -genkey -v -keystore mull.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mull
```

Simpan `mull.jks` di tempat aman dan **jangan pernah di-commit**. Lalu isi
empat secret di Settings > Secrets and variables > Actions pada repo ini:

| Secret | Isi |
| --- | --- |
| `KEYSTORE_BASE64` | isi `mull.jks` dalam base64 |
| `KEYSTORE_PASSWORD` | kata sandi keystore |
| `KEY_ALIAS` | `mull` |
| `KEY_PASSWORD` | kata sandi kunci |

Untuk mengubah `mull.jks` jadi base64 di PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("mull.jks")) | Set-Clipboard
```

Kalau mau menandatangani dari laptop sendiri, bikin `android/key.properties`
(sudah masuk `.gitignore`) berisi `storeFile`, `storePassword`, `keyAlias`,
dan `keyPassword`. Tanpa berkas itu, build rilis memakai kunci debug supaya
tetap bisa dijalankan, tapi APK seperti itu jangan dibagikan.

## Lisensi

GPL-3.0. Lihat berkas `LICENSE`.

Aplikasi ini memakai komponen pihak ketiga berikut:

| Komponen | Lisensi |
| --- | --- |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | Unlicense |
| [youtubedl-android](https://github.com/JunkFood02/youtubedl-android) | GPL-3.0 |
| [FFmpeg](https://ffmpeg.org) | sesuai build yang dipakai youtubedl-android |
| [QuickJS](https://bellard.org/quickjs/) | MIT |
| [Flutter](https://flutter.dev) dan paket pub.dev | lihat `pubspec.lock` |

Lirik berasal dari [LRCLIB](https://lrclib.net), basis data lirik terbuka.

Mull cuma alat. Unduh dan simpan konten yang memang boleh kamu simpan, dan
hormati hak cipta serta ketentuan layanan sumbernya.
