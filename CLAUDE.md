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
- Lisensi: GPL-3.0 (ikut youtubedl-android), repo publik `BlackKepret28/mull-music-android` (dibuat Mulya 9 Nov, sudah di-push). Jangan salin kode project GPL lain tanpa cantumkan sumber.
- Distribusi: APK lewat GitHub Releases (Play Store menolak app pengunduh YouTube).
- **Versi Android ini buat PRIBADI Mulya** (diputuskan 9 Nov). Jangan dipajang di situs: nggak ada tombol unduh Android, nggak ada halaman Android, nggak disebut di `mull-git/web/`. Dicek 9 Nov: situsnya memang belum nyebut Android sama sekali, jadi nggak ada yang perlu dicopot, cukup jangan ditambah. Catatan GPL: selama APK-nya nggak dibagikan ke orang lain, nggak ada kewajiban menyediakan sumber; begitu dibagikan, sumbernya harus ikut tersedia.
- Perangkat uji: Infinix Note 30 (X6833B, Android 14, arm64-v8a). Build arm64-v8a saja dulu.
- Package id: `com.mulya.mullmusic` (boleh diganti Mulya sebelum rilis pertama).
- Kelola keadaan: TANPA provider/riverpod/bloc. Cukup `ChangeNotifier` + `InheritedNotifier` (`SettingsScope`) dan singleton service. Alasan: dependensi sedikit, nggak ada codegen, gampang dibaca sendiri nanti.
- Pencarian pakai `ytsearch<N>:` + `--flat-playlist` (metadata saja, TANPA JavaScript) supaya cepat. Yang kena QuickJS cuma waktu butuh URL stream atau info satu tautan.
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
- `android/app/src/main/kotlin/com/mulya/mullmusic/MainActivity.kt`: turunan `AudioServiceActivity`. MethodChannel `mull/ytdlp`: init, version, updateYtDlp, getInfo, download, downloadMedia, listLibrary, deleteMedia, cancel, exec, ensureNotificationPermission, launchArgs, writeReport. EventChannel `mull/ytdlp/progress` ({id, progress, eta, line}). Semua kerja di thread pool, hasil dikirim balik di main thread; kecuali izin notifikasi yang wajib di main thread.
- `lib/ytdlp.dart`: pembungkus channel mentah (1 banding 1 dengan MethodChannel).
- `lib/services/ytdlp_service.dart`: `ensureReady()` (init sekali per hidup app, update yt-dlp kalau versinya null atau sudah lewat seminggu), `search()` + cache, `streamUrl()` + cache 3 jam, `prefetch()`, `perbaruiYtDlp()`, `pesanRamah()`. Buat tes pakai `YtDlpService.baru()`.
- `lib/services/player_service.dart`: `MullAudioHandler` (just_audio + audio_service). Antrean diurus sendiri, bukan ConcatenatingAudioSource. Ada token urutan supaya hasil yt-dlp yang telat nggak menimpa lagu yang sudah diganti.
- `lib/services/download_service.dart`: antrean unduhan satu per satu, progres dari EventChannel.
- `lib/services/library_service.dart`: baca Music/Mull dan Movies/Mull dari MediaStore. MediaStore yang jadi sumber kebenaran, bukan daftar sendiri.
- `lib/services/playlist_service.dart`: `playlists.json` di folder app.
- `lib/services/lyrics_service.dart`: LRCLIB + parser/penulis LRC + pembersih judul.
- `lib/main.dart` tipis -> `lib/app.dart` (MaterialApp + tema) -> `lib/shell.dart` (IndexedStack 4 tab + panel kaca bawah).
- `lib/theme.dart`: tema terang/gelap, aksen violet #6344FB / #8B7CFF, sama dengan `--accent` versi Windows.
- `lib/settings.dart`: `AppSettings` (shared_preferences) + `SettingsScope`. Isinya tema, efek kaca, format audio, tanggal update yt-dlp terakhir.
- `lib/models/track.dart`: `Track` + `formatDuration`.
- `lib/screens/`: `home_screen`, `search_screen`, `library_screen` (Lagu/Video/Playlist), `playlist_screen` (tab + detail + lembar tambah), `downloads_screen`, `now_playing_screen`, `video_screen`, `settings_screen`.
- `lib/widgets/`: `artwork`, `empty_state`, `mini_player`, `shelf`, `track_tile`, `glass_surface`, `bottom_nav` (+ `RuangBawah`), `lyrics_view`.
- `lib/dev/spike_page.dart`: layar diagnosa, dibuka dari Pengaturan > Diagnosa yt-dlp.
- Konten uji (semua Creative Commons): lagu Kevin MacLeod "Carefree" (`music.youtube.com/watch?v=owrhKIN3Y90`), Big Buck Bunny dari Blender (`youtube.com/watch?v=aqz-KE-bpKQ`), Big Buck Bunny di Wikimedia Commons (format terkecil).

## Rencana
1. SPIKE (LULUS 9 Nov, jangan diulang): buktiin di HP: init + update yt-dlp, runtime JS jalan (cek `yt-dlp -v`), lagu YT Music jadi m4a/opus, video 720p jadi mp4 (merge ffmpeg), 1 situs non-YouTube. Catat hasil, ukuran APK, waktu init pertama. Kalau runtime JS gagal: STOP, laporkan pilihan ke Mulya, jangan lanjut UI.
2. Kerangka app (SELESAI di kode, branch `batch-2-kerangka`):
   - [x] tema gelap dan terang, aksen violet
   - [x] navigasi bawah Beranda/Cari/Pustaka/Unduhan
   - [x] bar pemutar mini + layar Sedang diputar penuh
   - [x] Cari lewat `ytsearch` + tempel tautan
   - [x] just_audio + audio_service (latar belakang, notifikasi, layar kunci)
   - [x] antrean unduhan + simpan ke Music/Mull dan Movies/Mull lewat MediaStore
   - [x] Pustaka + playlist lokal (`playlists.json`)
   - [x] simpan pengaturan ke disk + perbarui yt-dlp mingguan
   - [x] lirik LRCLIB (disimpan di folder app, BUKAN di sebelah berkas)
   - [x] video pakai video_player
   - [x] kaca pakai liquid_glass_widgets (dengan sakelar mati)
   Sengaja BELUM: Kenali lagu, impor Spotify, akun Firebase, sinkron dengan Windows.
3. Rilis: GitHub Actions (tag `v*` -> `flutter build apk --release --split-per-abi` -> APK + `.sha256` ke Releases); keystore dibuat Mulya, disimpan sebagai secret base64 (jangan pernah commit atau minta ditempel ke chat); cek update di app (GitHub Releases -> unduh APK -> buka penginstal); README (cara pasang, GPL-3.0, daftar komponen pihak ketiga: yt-dlp Unlicense, youtubedl-android GPL-3.0, ffmpeg sesuai build-nya, QuickJS MIT).

## Aturan kerja
- Satu branch per batch, commit per fitur. **9 Nov: Mulya ngasih izin Claude yang merge sendiri** ("utk merge lo boleh"), beda dengan repo Windows yang tetap Mulya yang merge.
- Jangan commit `build/`, `.dart_tool/`, `*.apk`, `*.jks`, `key.properties`, `local.properties`.
- Tiap selesai: `flutter analyze`, `flutter test`, build APK debug, uji di Infinix, screenshot gelap + terang.
- Hanya dukung unduh dan putar konten yang memang boleh disimpan pengguna.
- Penutup tiap batch: ringkasan perubahan, cara jalanin, yang belum dites di HP asli.

## Status
- 8 Nov 2026: project dibuat, kode spike selesai. `flutter analyze` bersih, `flutter test` lulus.
- **9 Nov 2026: SPIKE LULUS di Infinix X6833B (Android 14), build release.** Laporan: `adb pull /sdcard/Android/data/com.mulya.mullmusic/files/spike-report.txt`.
  - Init pertama 5,0 dtk (ekstrak Python + ffmpeg), init berikutnya 0,14 dtk.
  - Update yt-dlp stable: bawaan AAR -> 2026.10.26 dalam 2,2 dtk.
  - Runtime JS: `JS runtimes: quickjs-2025-04-26`, `yt_dlp_ejs-0.8.0` ikut di yt-dlp hasil update, challenge YouTube terpecahkan (`jsc:quickjs`), tanpa peringatan "No supported JavaScript runtime". QuickJS LAMBAT: `-v --simulate` 33,5 dtk, getInfo 26,9 dtk.
  - getInfo Big Buck Bunny: 61 format, ada 720p.
  - Lagu YT Music (Kevin MacLeod "Carefree"): m4a 3,2 MB, 32 dtk.
  - Video 720p: mp4 97,5 MB, 111 dtk; ffprobe di PC: AV1 1280x720 60 fps + AAC, durasi 10:34 (merge ffmpeg jalan).
  - Wikimedia Commons: webm 29 MB, 28 dtk.
  - Ukuran APK release arm64: 58,8 MB. APK debug tercatat 215 MB tapi isinya cuma 94 MB (sisanya ruang kosong incremental packaging AGP), jangan dipakai buat ngukur.
- **9 Nov 2026: Langkah 2 bagian 1-2 jalan di Infinix (branch `batch-2-kerangka`).**
  - Kerangka + Cari sungguhan DITES DI HP ASLI pakai APK release. Pencarian `kevin macleod carefree` keluar ~10 entri lengkap dengan sampul, kanal, dan durasi. Gelap dan terang dua-duanya rapi; hasil cari nggak hilang waktu tema diganti (kena cache).
  - APK release arm64 sekarang 59,5 MB (spike 58,8 MB), build 50,8 dtk.
  - Dugaan soal `--flat-playlist` TERBUKTI: pencarian nggak kena QuickJS, jadi hitungan detik, bukan 30 detik.
  - Ruang HP waktu tes tinggal 861 MB dari 228 GB. Install APK release tetap muat.
  - BELUM dites di HP: tempel tautan (jalur QuickJS ~30 dtk), tombol Perbarui yt-dlp, layar Diagnosa dari menu Pengaturan yang baru.
- **9 Nov 2026 (lanjutan): Langkah 2 selesai di kode.** Commit: kerangka, Cari, lalu pemutar+kaca+unduhan+pustaka, lalu lirik+playlist+video.
  - DITES DI HP ASLI: muter lagu dari YouTube jalan (Carefree, 0:31/3:26, seekbar jalan, sampul penuh). Panel kaca mengambang kelihatan jelas, sampul di belakangnya kebias dan ngeblur.
  - BELUM DITES DI HP (HP lepas dari USB sekitar jam 02:15): unduhan + MediaStore, Pustaka, playlist, lirik, pemutar video, notifikasi pemutar, kontrol layar kunci, perbarui yt-dlp mingguan, tempel tautan.
  - Ukuran APK release arm64 naik bertahap: 58,8 (spike) -> 59,5 (kerangka) -> 60,9 (pemutar+kaca) -> 62,8 MB (unduhan+pustaka).
  - `flutter analyze` bersih, `flutter test` 52 lulus.
  - README ditulis ulang (bukan template Flutter lagi) + `LICENSE` GPL-3.0 resmi ditambahkan.
- Pelajaran build:
  - **`kotlin.incremental=false` di `android/gradle.properties` WAJIB.** Tanpa itu build release gagal acak: "Could not close incremental caches ... class-fq-name-to-source.tab" di modul plugin mana pun (kejadian di `shared_preferences_android` dan `audio_session`). Drive C: laptop Mulya cuma sisa 0,45 GB dan `~/.gradle` makan 10,2 GB, itu tersangka utamanya.
  - **POST_NOTIFICATIONS harus diminta sendiri** (Android 13+). Tanpa itu `dumpsys media_session` nunjukin `state=NONE` dan `active=false`, metadata masuk tapi notifikasi pemutar nggak muncul. Diminta sekali, pas pertama memutar atau mengunduh.
  - MediaStore `RELATIVE_PATH` butuh API 29, makanya `minSdk = maxOf(flutter.minSdkVersion, 29)`.
  - NavigationBar bawaan Material selalu ngecat latarnya sendiri, jadi nutupin panel kaca. Dipakai `BottomNav` bikinan sendiri.
  - `ChangeNotifier.notifyListeners()` jangan dipanggil dari `initState` kalau ada widget lain di `IndexedStack` yang ikut mendengarkan: kena "setState() called during build". Pakai `addPostFrameCallback`.
  - `abiFilters` nggak ngefek (plugin Flutter + AAR tetap menyelipkan semua ABI). Yang jalan: `packaging.jniLibs.excludes` buat armeabi-v7a/x86/x86_64 (kecuali `-Psplit-per-abi=true`).
  - Build release WAJIB `proguard-rules.pro` (keep `com.yausername.**`, `com.fasterxml.jackson.**`, commons-compress). Tanpa itu R8 merusak Jackson: init gagal "class w2 is not a concrete class".
  - `YoutubeDL.version()` null sebelum pernah di-update; Dart harus terima `String?`.
- Catatan buat Langkah 2:
  - Memori HP Mulya tinggal ~1 GB dari 228 GB. APK debug (215 MB) ditolak `INSUFFICIENT_STORAGE`, jadi uji pakai APK release. App harus kasih pesan jelas kalau ruang penyimpanan habis.
  - Karena QuickJS lambat (~25-35 dtk per video YouTube), Cari/putar langsung butuh cache hasil (URL stream + info), prefetch lagu berikutnya, dan indikator loading yang jujur. Pertimbangkan `--extractor-args youtube:player_client=...` yang nggak butuh JS buat audio.
  - Pilihan format video bawaan: utamakan H.264 (`vcodec^=avc1`) daripada AV1 supaya aman di HP lama; AV1 kepilih otomatis di spike.
  - Folder spike di HP dihapus setelah tes (130 MB); laporannya disimpan.
  - **Ruang HP Mulya cuma sisa ~600-800 MB dari 228 GB.** `adb install -r` sering ditolak `INSUFFICIENT_STORAGE` karena butuh ruang buat dua salinan sekaligus. Cara yang jalan: `adb uninstall com.mulya.mullmusic` dulu baru `adb install`. Data app cuma belasan KB jadi nggak ada yang hilang berarti, tapi pengaturan/playlist/riwayat ikut kehapus.

- **9 Nov sore: rombakan UI atas permintaan Mulya.**
  - Ikon navbar ganti ke keluarga rounded + pil aksen di tab aktif (yang outlined dibilang "kuno dan jelek").
  - Pustaka dirombak: judul besar + ringkasan, SegmentedPill ganti TabBar, Lagu dapat Putar/Acak/urutkan, Video jadi grid kartu 16:9 dengan badge durasi, Playlist jadi grid kartu mozaik.
  - Beranda ditulis ulang mengikuti `renderHome()` versi Windows: salam menurut jam (aturan jamnya disalin persis), petak akses cepat (playlist dulu lalu pintasan tetap, dua kolom buat HP), kartu "Putar dari tautan" yang baca papan klip, rak Baru diputar / Baru diunduh / Playlist kamu, sambutan waktu kosong.
  - `RecentService` baru (`recent.json`, maks 50) supaya rak "Baru diputar" ada isinya. Dicatat cuma kalau lagunya benar-benar jalan.
  - Ikon app pakai logo Mull dari `mull-git/assets/mull.png` (violet #6242FB): legacy 5 kepadatan + ikon adaptif (latar violet, foreground 62%, monochrome diisi).
  - Penandatanganan rilis: `android/key.properties` (opsional, di-ignore) -> signingConfig rilis; tanpa itu jatuh ke kunci debug. Workflow `.github/workflows/release.yml` + bagian Rilis di README.
  - Jebakan yang ketemu: `childAspectRatio` di GridView bikin tinggi petak ikut lebar layar sampai isinya meluber; pakai `mainAxisExtent` kalau tingginya memang harus tetap.
  - APK release arm64 sekarang 63,4 MB. `flutter analyze` bersih, `flutter test` 62 lulus.
  - BELUM DITES DI HP: seluruh rombakan UI ini. HP lepas dari USB lagi sebelum sempat dipasang.

- **9 Nov malam: didorong ke GitHub.** Remote `origin` = `https://github.com/BlackKepret28/mull-music-android.git` (publik). Commit awal GitHub (README otomatis) digabung pakai `--allow-unrelated-histories`, README-nya diambil punya kita. `main`, `batch-2-kerangka`, dan `spike-ytdlp` semuanya sudah di-push.
  - Beranda baru DITES DI HP dan jalan: salam "Selamat malam", petak akses cepat dua kolom, kartu Putar dari tautan, sambutan, navbar ikon rounded dengan pil aksen.
  - Bug ketemu dan BERES (belum dites ulang di HP): celah kosong besar di Beranda. **GridView/ListView bersarang yang `padding`-nya null otomatis memakai `MediaQuery.padding`**, jadi ikut kena inset navigasi bawah HP. Semua grid bersarang sekarang dipaksa `padding: EdgeInsets.zero`. Ingat ini tiap bikin scroll view di dalam scroll view.
  - HP Mulya sering lepas sendiri dari USB waktu sesi panjang. Kalau `adb devices` kosong, cek kabelnya; `adb kill-server && adb start-server` nggak nolong kalau fisik.

## Yang harus dites duluan waktu HP nyambung lagi
Urut dari yang paling mungkin bermasalah:
1. **Unduh satu lagu** (Carefree) -> cek berkasnya muncul di `Music/Mull` lewat app file manager, dan muncul di tab Pustaka > Lagu.
2. **Notifikasi pemutar**: harus ada dialog izin pas pertama muter, terus notifikasinya muncul dan tombolnya jalan. Cek ulang pakai `adb shell dumpsys media_session | grep -i state=` (harus PLAYING, bukan NONE).
3. **Lirik**: buka Sedang diputar > ikon lirik. Carefree itu instrumental jadi kemungkinan "Lirik belum ketemu"; pakai lagu berlirik buat uji sungguhan.
4. **Unduh video 720p** lalu buka dari Pustaka > Video.
5. **Playlist**: bikin, tambah lagu, geser urutan, tutup app, buka lagi (harus masih ada).
6. **Tempel tautan** di Cari (jalur QuickJS ~30 dtk).
7. **Beranda baru**: salam, petak akses cepat, kartu Putar dari tautan (salin tautan YouTube dulu, lalu ketuk).
8. **Pustaka baru**: pemilih pil, Putar/Acak, urutkan, grid video, grid playlist.
9. **Ikon app** di laci aplikasi: harus logo M violet, bukan ikon Flutter.
10. **FPS kaca** waktu menggulir daftar panjang. Kalau berat, matikan di Pengaturan > Efek kaca, atau turunkan `blur`/`frost` di `lib/widgets/glass_surface.dart`.
