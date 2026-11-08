# Mull Music App untuk Android

Versi Android dari Mull Music App (versi Windows: repo privat `BlackKepret28/mull-downloader`, folder `E:\Mull Downloader\mull-git`, punya CLAUDE.md sendiri). Dikerjakan Mulya (kelas 11 SMA, OSIS bidang IT, Banda Aceh). Versi Windows nggak diubah oleh batch Android.

## Cara ngobrol dengan Mulya
- Ke Mulya: Bahasa Indonesia gaul (gue/lo), to the point, jelasin istilah baru singkat. Jujur soal apa yang sudah dan belum dites di HP asli.
- Teks di dalam app: Bahasa Indonesia santai tapi sopan (kamu/aku). Minimalis, modern, bukan "AI slop" (tanpa gradient norak, emoji, efek berlebihan).
- Perintah terminal: PowerShell, satu perintah per blok, tanpa teks prompt `PS E:\...>`.
- Langsung kerjain, jangan banyak nanya. Kalau ambigu, ambil tebakan paling masuk akal dan sebut asumsinya.
- Catat setiap perubahan, to-do, dan ide penting ke file ini begitu terjadi.

## Keputusan yang sudah diambil
- Stack: Flutter (UI) + youtubedl-android (yt-dlp + Python + QuickJS + ffmpeg) lewat platform channel Kotlin. Artefak tim Seal: `io.github.junkfood02.youtubedl-android:library` dan `:ffmpeg`, versi **0.18.1** (terbaru di Maven Central per 8 Nov 2026, rilis 16 Nov 2025). Cek ulang Maven Central sebelum naik versi, jangan tebak.
- Lisensi: GPL-3.0 (ikut youtubedl-android), repo publik terpisah `mull-music-android` (belum dibuat). Jangan salin kode project GPL lain tanpa cantumkan sumber.
- Distribusi: APK lewat GitHub Releases (Play Store menolak app pengunduh YouTube).
- Perangkat uji: Infinix Note 30 (X6833B, Android 14, arm64-v8a). Build arm64-v8a saja dulu.
- Package id: `com.mulya.mullmusic` (boleh diganti Mulya sebelum rilis pertama).
- GUI: pola tata letak mirip Spotify / YouTube Music (navigasi bawah, bar pemutar mini di atas navigasi, layar Sedang diputar penuh, rak kartu horizontal di Beranda). Pola saja, jangan tiru logo, nama, atau warna merek mereka. Aksen ikut versi Windows (violet).

## Lingkungan (8 Nov 2026)
- Flutter 3.47.9 stable (Dart 3.13.7) di `D:\flutter` (tambahkan `D:\flutter\bin` ke PATH kalau `flutter` nggak dikenal). Android SDK 36.1 di `D:\Android\Sdk`, JDK 21 bawaan Android Studio (`D:\APP FILE\Program Files\Android Studio\jbr`). Template: AGP 9.1.0, Kotlin 2.4.0, Gradle Kotlin DSL.
- HP: serial `102752535J000330`. Kalau `flutter devices` bilang "not authorized", buka HP lalu izinkan USB debugging.

## Temuan teknis
- youtubedl-android 0.18.1 SUDAH membundel QuickJS (`libqjs.so`) dan otomatis menambah `--js-runtimes quickjs:<nativeLibDir>/libqjs.so` ke tiap perintah (dicek dari isi AAR, 8 Nov). Jadi nggak perlu bundel QuickJS-ng sendiri, kecuali tes di HP membuktikan sebaliknya.
- yt-dlp bawaan AAR umurnya setahun (res/raw/ytdlp). Panggil `updateYtDlp` (stable) dulu sebelum dipakai ke YouTube.
- `.so` harus diekstrak ke disk: `android:extractNativeLibs="true"` + `packaging.jniLibs.useLegacyPackaging = true`.
- `abiFilters arm64-v8a` dimatikan otomatis kalau Gradle dapat properti `split-per-abi` (dari `flutter build apk --split-per-abi`), biar nggak bentrok.
- AAR ukurannya besar (library 56 MB, ffmpeg 133 MB untuk semua ABI), makanya wajib filter ABI.

## Struktur
- `android/app/src/main/kotlin/com/mulya/mullmusic/MainActivity.kt`: MethodChannel `mull/ytdlp` (init, version, updateYtDlp, getInfo, download, cancel, exec, launchArgs, writeReport) + EventChannel `mull/ytdlp/progress` ({id, progress, eta, line}). Semua kerja di thread pool, hasil dikirim balik di main thread.
- `lib/ytdlp.dart`: pembungkus channel. `lib/main.dart`: layar SPIKE (tombol "Jalankan semua tes").
- Hasil unduhan spike: `getExternalFilesDir("spike")/<id>/`. Laporan: `files/spike-report.txt` (ambil pakai `adb pull /sdcard/Android/data/com.mulya.mullmusic/files/spike-report.txt`). Bisa jalan otomatis: `adb shell am start -n com.mulya.mullmusic/.MainActivity --es autorun true`.
- Konten uji (semua Creative Commons): lagu Kevin MacLeod "Carefree" (`music.youtube.com/watch?v=owrhKIN3Y90`), Big Buck Bunny dari Blender (`youtube.com/watch?v=aqz-KE-bpKQ`), Big Buck Bunny di Wikimedia Commons (format terkecil).

## Rencana
1. SPIKE (lagi dikerjakan): buktiin di HP: init + update yt-dlp, runtime JS jalan (cek `yt-dlp -v`), lagu YT Music jadi m4a/opus, video 720p jadi mp4 (merge ffmpeg), 1 situs non-YouTube. Catat hasil, ukuran APK, waktu init pertama. Kalau runtime JS gagal: STOP, laporkan pilihan ke Mulya, jangan lanjut UI.
2. Kerangka app (setelah spike lulus): navigasi bawah Beranda/Cari/Pustaka/Unduhan; bar pemutar mini + layar Sedang diputar; just_audio + audio_service (latar belakang, notifikasi, layar kunci); video pakai video_player atau media_kit; Cari lewat ytsearch / YT Music via yt-dlp; antrean unduhan + simpan ke Music/Mull dan Movies/Mull lewat MediaStore (tanpa izin penyimpanan lama); Pustaka + playlist lokal (format JSON mirip `playlists.json` Windows); lirik LRCLIB (`.lrc` di sebelah file); kaca pakai liquid_glass_widgets di bar pemutar dan navigasi (dengan sakelar mati); tema gelap dan terang.
   Sengaja BELUM: Kenali lagu, impor Spotify, akun Firebase, sinkron dengan Windows.
3. Rilis: GitHub Actions (tag `v*` -> `flutter build apk --release --split-per-abi` -> APK + `.sha256` ke Releases); keystore dibuat Mulya, disimpan sebagai secret base64 (jangan pernah commit atau minta ditempel ke chat); cek update di app (GitHub Releases -> unduh APK -> buka penginstal); README (cara pasang, GPL-3.0, daftar komponen pihak ketiga: yt-dlp Unlicense, youtubedl-android GPL-3.0, ffmpeg sesuai build-nya, QuickJS MIT).

## Aturan kerja
- Satu branch per batch, commit per fitur. Jangan merge ke main; Mulya yang merge.
- Jangan commit `build/`, `.dart_tool/`, `*.apk`, `*.jks`, `key.properties`, `local.properties`.
- Tiap selesai: `flutter analyze`, `flutter test`, build APK debug, uji di Infinix, screenshot gelap + terang.
- Hanya dukung unduh dan putar konten yang memang boleh disimpan pengguna.
- Penutup tiap batch: ringkasan perubahan, cara jalanin, yang belum dites di HP asli.

## Status
- 8 Nov 2026: project dibuat, kode spike selesai. `flutter analyze` bersih, `flutter test` lulus. Build APK debug: lihat catatan di bawah. Spike BELUM dijalankan di HP (HP belum mengizinkan USB debugging).
