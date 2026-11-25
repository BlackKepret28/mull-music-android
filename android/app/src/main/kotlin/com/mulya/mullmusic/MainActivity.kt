package com.mulya.mullmusic

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.app.RecoverableSecurityException
import android.provider.Settings
import androidx.core.content.FileProvider
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.graphics.Bitmap
import android.util.Size
import java.io.ByteArrayOutputStream
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Jembatan Flutter <-> youtubedl-android (yt-dlp + Python + QuickJS + ffmpeg).
 *
 * MethodChannel "mull/ytdlp":
 *   init, version, updateYtDlp, getInfo(url, args?), download(id, url, args?), cancel(id),
 *   exec(args)  -> jalankan yt-dlp mentah (buat diagnosa spike, mis. -v)
 *   downloadMedia(id, url, args?, video) -> unduh ke cache lalu pindahkan ke
 *       MediaStore (Music/Mull atau Movies/Mull). Balikin daftar file + uri.
 *   listLibrary() -> isi Music/Mull dan Movies/Mull dari MediaStore, plus semua lagu
 *                    di HP kalau izin baca audio sudah diberikan
 *   hasAudioPermission / ensureAudioPermission -> izin baca lagu (READ_MEDIA_AUDIO)
 *   thumbnail(uri, size) -> sampul bawaan berkas (JPEG), buat Pustaka
 *   deleteMedia(uri) -> hapus satu berkas pustaka. Berkas yang bukan milik app
 *       (lagu lain di HP, atau unduhan Mull sebelum app dipasang ulang) minta
 *       konfirmasi lewat dialog sistem Android.
 *   decodePcm(source, headers?, startMs, lengthMs) -> PCM 16 kHz mono buat Kenali lagu
 *   ensureMicPermission, micStart, micStatus, micSnapshot(seconds), micStop -> rekam mikrofon
 *   appInfo -> versi app + ABI HP, buat cek update
 *   canInstall, openInstallPermission, installApk(path) -> pasang APK update
 *   shareText(text, title) -> lembar Bagikan Android
 *   openUrl(url) -> buka di browser (login Google)
 *   ensureNotificationPermission -> minta POST_NOTIFICATIONS (Android 13+)
 *   launchArgs  -> extra dari intent (mis. autorun=true dari adb)
 *   writeReport(text) -> simpan laporan spike ke files/spike-report.txt
 * EventChannel "mull/ytdlp/progress": {id, progress, eta, line}
 *
 * Turunan AudioServiceActivity (bukan FlutterActivity) karena audio_service
 * butuh activity-nya nyambung ke MediaBrowserService buat notifikasi dan
 * kontrol di layar kunci.
 */
class MainActivity : AudioServiceActivity() {
    private val pool = Executors.newCachedThreadPool()
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    @Volatile private var initialized = false

    /** Hasil MethodChannel yang lagi nunggu jawaban dialog izin. */
    private var pendingPermission: MethodChannel.Result? = null

    /** Hapus berkas yang lagi nunggu jawaban dialog hapus dari sistem. */
    private var pendingDelete: MethodChannel.Result? = null
    private var pendingDeleteUri: Uri? = null

    private val mic = MicRecorder()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "mull/ytdlp/progress").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
                override fun onCancel(arguments: Any?) { sink = null }
            }
        )

        MethodChannel(messenger, "mull/ytdlp").setMethodCallHandler { call, result ->
            if (call.method == "ensureNotificationPermission") {
                // Dialog izin harus dari main thread, dan jawabannya datang
                // belakangan lewat onRequestPermissionsResult.
                requestNotificationPermission(result)
                return@setMethodCallHandler
            }
            if (call.method == "ensureAudioPermission") {
                requestPermission(audioPermission(), result)
                return@setMethodCallHandler
            }
            if (call.method == "hasNotificationPermission") {
                val ok = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                result.success(mapOf("granted" to ok))
                return@setMethodCallHandler
            }
            if (call.method == "hasAudioPermission") {
                result.success(mapOf("granted" to hasAudioPermission()))
                return@setMethodCallHandler
            }
            if (call.method == "ensureMicPermission") {
                requestPermission(Manifest.permission.RECORD_AUDIO, result)
                return@setMethodCallHandler
            }
            if (call.method == "deleteMedia") {
                deleteMedia(Uri.parse(call.argument<String>("uri")!!), result)
                return@setMethodCallHandler
            }
            if (call.method in setOf("openInstallPermission", "installApk", "shareText", "openUrl", "openNotificationSettings", "openBatterySettings")) {
                // Membuka activity lain: harus dari main thread.
                try {
                    result.success(handleUi(call))
                } catch (e: Throwable) {
                    result.error("failed", e.message ?: e.toString(), null)
                }
                return@setMethodCallHandler
            }
            if (call.method == "launchArgs") {
                val extras = intent?.extras
                result.success(mapOf("autorun" to (extras?.getString("autorun") == "true")))
                return@setMethodCallHandler
            }
            pool.execute {
                try {
                    val value = handle(call)
                    main.post { result.success(value) }
                } catch (e: YoutubeDL.CanceledException) {
                    main.post { result.error("canceled", "Dibatalkan", null) }
                } catch (e: Throwable) {
                    main.post { result.error("failed", e.message ?: e.toString(), e.stackTraceToString().take(4000)) }
                }
            }
        }
    }

    /**
     * Folder cache yt-dlp (player YouTube yang sudah diproses, fungsi tanda
     * tangan, dst.). youtubedl-android menambahkan --no-cache-dir sendiri kalau
     * opsi --cache-dir nggak didaftarkan lewat addOption, dan itu bikin tiap
     * lagu mengulang kerja JavaScript yang berat (50-85 detik di HP).
     */
    private fun cacheYtdlp(): String = File(filesDir, "ytdlp-cache").apply { mkdirs() }.absolutePath

    private fun ensureInit() {
        if (initialized) return
        synchronized(this) {
            if (initialized) return
            YoutubeDL.getInstance().init(applicationContext)
            FFmpeg.getInstance().init(applicationContext)
            initialized = true
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun handle(call: MethodCall): Any? {
        val ytdl = YoutubeDL.getInstance()
        return when (call.method) {
            "init" -> {
                val t0 = System.currentTimeMillis()
                ensureInit()
                mapOf("ms" to (System.currentTimeMillis() - t0))
            }
            "version" -> {
                ensureInit()
                mapOf("version" to ytdl.version(applicationContext), "name" to ytdl.versionName(applicationContext))
            }
            "updateYtDlp" -> {
                ensureInit()
                val ch = when (call.argument<String>("channel")) {
                    "nightly" -> YoutubeDL.UpdateChannel.NIGHTLY
                    "master" -> YoutubeDL.UpdateChannel.MASTER
                    else -> YoutubeDL.UpdateChannel.STABLE
                }
                val t0 = System.currentTimeMillis()
                val status = ytdl.updateYoutubeDL(applicationContext, ch)
                mapOf(
                    "status" to (status?.name ?: "UNKNOWN"),
                    "version" to ytdl.version(applicationContext),
                    "ms" to (System.currentTimeMillis() - t0),
                )
            }
            "getInfo" -> {
                ensureInit()
                val url = call.argument<String>("url")!!
                val req = YoutubeDLRequest(url)
                req.addOption("--cache-dir", cacheYtdlp())
                req.addOption("-J")
                req.addOption("--no-playlist")
                (call.argument<List<String>>("args") ?: emptyList()).let { if (it.isNotEmpty()) req.addCommands(it) }
                val t0 = System.currentTimeMillis()
                val res = ytdl.execute(req, null, null)
                mapOf("json" to res.out, "ms" to (System.currentTimeMillis() - t0), "err" to res.err.takeLast(4000))
            }
            "download" -> {
                ensureInit()
                val id = call.argument<String>("id")!!
                val url = call.argument<String>("url")!!
                val dir = File(getExternalFilesDir("spike"), id).apply { deleteRecursively(); mkdirs() }
                val req = YoutubeDLRequest(url)
                req.addOption("--cache-dir", cacheYtdlp())
                req.addOption("--no-playlist")
                req.addOption("--newline")
                req.addOption("-P", dir.absolutePath)
                req.addOption("-o", "%(title).80B [%(id)s].%(ext)s")
                (call.argument<List<String>>("args") ?: emptyList()).let { if (it.isNotEmpty()) req.addCommands(it) }
                val t0 = System.currentTimeMillis()
                val res = ytdl.execute(req, id) { progress, eta, line ->
                    main.post { sink?.success(mapOf("id" to id, "progress" to progress.toDouble(), "eta" to eta, "line" to line)) }
                }
                val files = dir.walkTopDown().filter { it.isFile }.map {
                    mapOf("name" to it.name, "size" to it.length(), "path" to it.absolutePath)
                }.toList()
                mapOf(
                    "exitCode" to res.exitCode,
                    "ms" to (System.currentTimeMillis() - t0),
                    "files" to files,
                    "err" to res.err.takeLast(4000),
                    "out" to res.out.takeLast(2000),
                )
            }
            "cancel" -> ytdl.destroyProcessById(call.argument<String>("id")!!)
            "exec" -> {
                ensureInit()
                val args = call.argument<List<String>>("args") ?: emptyList()
                val req = YoutubeDLRequest(emptyList<String>())
                req.addOption("--cache-dir", cacheYtdlp())
                req.addCommands(args)
                val t0 = System.currentTimeMillis()
                val res = ytdl.execute(req, null, null)
                mapOf("exitCode" to res.exitCode, "ms" to (System.currentTimeMillis() - t0),
                    "out" to res.out.takeLast(8000), "err" to res.err.takeLast(8000))
            }
            "downloadMedia" -> {
                ensureInit()
                val id = call.argument<String>("id")!!
                val url = call.argument<String>("url")!!
                val video = call.argument<Boolean>("video") ?: false

                // yt-dlp nggak bisa nulis langsung ke content:// URI, jadi
                // unduh dulu ke cache app baru dipindahkan ke MediaStore.
                val tmp = File(cacheDir, "dl/$id").apply { deleteRecursively(); mkdirs() }
                try {
                    val req = YoutubeDLRequest(url)
                    req.addOption("--cache-dir", cacheYtdlp())
                    req.addOption("--no-playlist")
                    req.addOption("--newline")
                    req.addOption("-P", tmp.absolutePath)
                    req.addOption("-o", "%(title).80B [%(id)s].%(ext)s")
                    (call.argument<List<String>>("args") ?: emptyList()).let {
                        if (it.isNotEmpty()) req.addCommands(it)
                    }

                    val t0 = System.currentTimeMillis()
                    val res = ytdl.execute(req, id) { progress, eta, line ->
                        main.post {
                            sink?.success(
                                mapOf("id" to id, "progress" to progress.toDouble(), "eta" to eta, "line" to line)
                            )
                        }
                    }

                    val files = tmp.walkTopDown().filter { it.isFile }.map { publish(it, video) }.toList()
                    mapOf(
                        "exitCode" to res.exitCode,
                        "ms" to (System.currentTimeMillis() - t0),
                        "files" to files,
                        "err" to res.err.takeLast(4000),
                    )
                } finally {
                    tmp.deleteRecursively()
                }
            }
            "listLibrary" -> mapOf("items" to listLibrary(), "all" to hasAudioPermission())
            "thumbnail" -> mapOf(
                "bytes" to thumbnail(
                    Uri.parse(call.argument<String>("uri")!!),
                    call.argument<Int>("size") ?: 256,
                ),
            )
            "decodePcm" -> PcmDecoder.decode(
                applicationContext,
                call.argument<String>("source")!!,
                call.argument<Map<String, String>>("headers"),
                (call.argument<Number>("startMs") ?: 0).toLong(),
                (call.argument<Number>("lengthMs") ?: 12000).toLong(),
            )
            "micStart" -> {
                if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                    throw SecurityException("Izin mikrofon belum diberikan.")
                }
                mic.start(applicationContext)
                mapOf("ok" to true)
            }
            "micStatus" -> mapOf("level" to mic.level, "seconds" to mic.seconds)
            "micSnapshot" -> mapOf("pcm" to mic.snapshot(call.argument<Number>("seconds")?.toDouble() ?: 12.0))
            "micStop" -> {
                mic.stop()
                mapOf("ok" to true)
            }
            "diagNotifikasi" -> {
            val nm = getSystemService(android.app.NotificationManager::class.java)
            val saluran = nm.notificationChannels.map { "${it.id} | ${it.name} | penting=${it.importance}" }
            val aktif = nm.activeNotifications.map {
                val judul = it.notification.extras.getCharSequence(android.app.Notification.EXTRA_TITLE)
                val ongoing = (it.notification.flags and android.app.Notification.FLAG_ONGOING_EVENT) != 0
                "id=${it.id} kanal=${it.notification.channelId} judul=$judul ongoing=$ongoing"
            }
            @Suppress("DEPRECATION")
            val am = getSystemService(android.app.ActivityManager::class.java)
            @Suppress("DEPRECATION")
            val layanan = am.getRunningServices(200)
                .any { it.service.className == "com.ryanheise.audioservice.AudioService" }
            val pm = getSystemService(android.os.PowerManager::class.java)
            mapOf(
                "notifAktif" to nm.areNotificationsEnabled(),
                "saluran" to saluran,
                "notifikasi" to aktif,
                "layananJalan" to layanan,
                "bebasBaterai" to pm.isIgnoringBatteryOptimizations(packageName),
                "sdk" to Build.VERSION.SDK_INT,
                "perangkat" to "${Build.MANUFACTURER} ${Build.MODEL}",
            )
        }
        "testNotification" -> {
            val nm = getSystemService(android.app.NotificationManager::class.java)
            nm.createNotificationChannel(
                android.app.NotificationChannel(
                    "mull_tes",
                    "Tes notifikasi",
                    android.app.NotificationManager.IMPORTANCE_DEFAULT,
                )
            )
            val n = androidx.core.app.NotificationCompat.Builder(this, "mull_tes")
                .setSmallIcon(R.drawable.ic_notif_logo)
                .setContentTitle("Tes notifikasi Mull")
                .setContentText("Kalau ini muncul, izin dan kanal notifikasi aman.")
                .setAutoCancel(true)
                .build()
            nm.notify(4242, n)
            mapOf("ok" to true)
        }
        "getLogcat" -> {
            // Log milik app ini sendiri (Android nggak ngasih log app lain).
            val proses = Runtime.getRuntime().exec(arrayOf("logcat", "-d", "-v", "time", "-t", "3000"))
            val semua = proses.inputStream.bufferedReader().readLines()
            proses.destroy()
            val kunci = Regex(
                "audioservice|MediaSession|Notification|Foreground|AndroidRuntime|FATAL|mullmusic|ActivityManager|ExoPlayer|just_audio|flutter",
                RegexOption.IGNORE_CASE,
            )
            val pilih = semua.filter { kunci.containsMatchIn(it) || it.contains(" E/") }.takeLast(500)
            mapOf("log" to pilih.joinToString("\n").takeLast(100_000))
        }
        "appInfo" -> {
                val pi = packageManager.getPackageInfo(packageName, 0)
                mapOf(
                    "versionName" to pi.versionName,
                    "versionCode" to pi.longVersionCode,
                    "abis" to Build.SUPPORTED_ABIS.toList(),
                    "sdk" to Build.VERSION.SDK_INT,
                )
            }
            "canInstall" -> mapOf("granted" to packageManager.canRequestPackageInstalls())
            "writeReport" -> {
                val f = File(getExternalFilesDir(null), "spike-report.txt")
                f.writeText(call.argument<String>("text") ?: "")
                f.absolutePath
            }
            else -> throw IllegalArgumentException("Metode tidak dikenal: ${call.method}")
        }
    }

    // ---- Yang membuka activity lain (main thread) -------------------------

    private fun handleUi(call: MethodCall): Any? = when (call.method) {
        "openInstallPermission" -> {
            startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
            )
            mapOf("ok" to true)
        }
        "installApk" -> {
            val f = File(call.argument<String>("path")!!)
            val uri = FileProvider.getUriForFile(this, "$packageName.files", f)
            startActivity(
                Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, "application/vnd.android.package-archive")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            mapOf("ok" to true)
        }
        "openBatterySettings" -> {
            try {
                startActivity(
                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            } catch (e: Exception) {
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:$packageName"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
            mapOf("ok" to true)
        }
        "openNotificationSettings" -> {
            // Halaman notifikasi app ini di Pengaturan Android, buat nyalain
            // lagi kalau izinnya sempat ditolak.
            startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            mapOf("ok" to true)
        }
        "openUrl" -> {
            startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")!!))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            mapOf("ok" to true)
        }
        "shareText" -> {
            val kirim = Intent(Intent.ACTION_SEND)
                .setType("text/plain")
                .putExtra(Intent.EXTRA_TEXT, call.argument<String>("text") ?: "")
            startActivity(Intent.createChooser(kirim, call.argument<String>("title")))
            mapOf("ok" to true)
        }
        else -> throw IllegalArgumentException("Metode tidak dikenal: ${call.method}")
    }

    // ---- Hapus berkas ------------------------------------------------------

    /**
     * Berkas milik app langsung terhapus. Yang bukan (lagu lain di HP, atau
     * unduhan Mull dari pemasangan sebelumnya) dilempar SecurityException,
     * lalu Android yang nanya ke pengguna lewat dialognya sendiri.
     */
    private fun deleteMedia(uri: Uri, result: MethodChannel.Result) {
        pool.execute {
            try {
                val ok = contentResolver.delete(uri, null, null) > 0
                main.post { result.success(mapOf("deleted" to ok)) }
            } catch (e: SecurityException) {
                val sender = try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        MediaStore.createDeleteRequest(contentResolver, listOf(uri)).intentSender
                    } else {
                        (e as? RecoverableSecurityException)?.userAction?.actionIntent?.intentSender
                    }
                } catch (_: Throwable) {
                    null
                }
                main.post {
                    if (sender == null) {
                        result.error("failed", "Android nggak ngizinin berkas ini dihapus.", null)
                        return@post
                    }
                    pendingDelete?.success(mapOf("deleted" to false))
                    pendingDelete = result
                    pendingDeleteUri = uri
                    try {
                        @Suppress("DEPRECATION")
                        startIntentSenderForResult(sender, DELETE_REQUEST, null, 0, 0, 0)
                    } catch (t: Throwable) {
                        pendingDelete = null
                        result.error("failed", t.message ?: t.toString(), null)
                    }
                }
            } catch (e: Throwable) {
                main.post { result.error("failed", e.message ?: e.toString(), null) }
            }
        }
    }

    @Deprecated("Masih dipakai buat startIntentSenderForResult")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != DELETE_REQUEST) return
        val r = pendingDelete ?: return
        val uri = pendingDeleteUri
        pendingDelete = null
        pendingDeleteUri = null
        if (resultCode != RESULT_OK) {
            r.success(mapOf("deleted" to false, "canceled" to true))
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R || uri == null) {
            // Android 11+: dialog sistem sudah sekalian menghapus.
            r.success(mapOf("deleted" to true))
            return
        }
        // Android 10: izinnya baru diberikan, hapusnya diulang.
        pool.execute {
            val ok = try { contentResolver.delete(uri, null, null) > 0 } catch (_: Throwable) { false }
            main.post { r.success(mapOf("deleted" to ok)) }
        }
    }

    // ---- Izin notifikasi (Android 13+) ----------------------------------

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(mapOf("granted" to true))
            return
        }
        requestPermission(Manifest.permission.POST_NOTIFICATIONS, result)
    }

    /** Android 13+ punya izin khusus audio; di bawahnya masih izin penyimpanan. */
    private fun audioPermission(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }

    private fun hasAudioPermission(): Boolean =
        checkSelfPermission(audioPermission()) == PackageManager.PERMISSION_GRANTED

    private fun requestPermission(izin: String, result: MethodChannel.Result) {
        if (checkSelfPermission(izin) == PackageManager.PERMISSION_GRANTED) {
            result.success(mapOf("granted" to true))
            return
        }
        // Cuma satu permintaan boleh nunggu. Yang lama dijawab apa adanya.
        pendingPermission?.success(mapOf("granted" to false))
        pendingPermission = result
        requestPermissions(arrayOf(izin), PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST) return
        val ok = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(mapOf("granted" to ok))
        pendingPermission = null
    }

    // ---- MediaStore ------------------------------------------------------

    /**
     * Pindahkan satu berkas hasil unduhan ke penyimpanan bersama lewat
     * MediaStore, jadi kelihatan di app musik/galeri lain dan nggak ikut
     * terhapus waktu Mull di-uninstall. Nggak butuh izin penyimpanan karena
     * kita cuma nulis berkas yang kita bikin sendiri.
     */
    private fun publish(f: File, video: Boolean): Map<String, Any?> {
        val koleksi = if (video) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val folder = if (video) {
            "${Environment.DIRECTORY_MOVIES}/Mull"
        } else {
            "${Environment.DIRECTORY_MUSIC}/Mull"
        }

        val nilai = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, f.name)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeOf(f))
            put(MediaStore.MediaColumns.RELATIVE_PATH, folder)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = contentResolver.insert(koleksi, nilai)
            ?: throw IOException("MediaStore nggak mau nerima ${f.name}")

        try {
            contentResolver.openOutputStream(uri)?.use { out ->
                f.inputStream().use { it.copyTo(out) }
            } ?: throw IOException("Nggak bisa nulis ke ${f.name}")
        } catch (e: Throwable) {
            contentResolver.delete(uri, null, null)
            throw e
        }

        contentResolver.update(
            uri,
            ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
            null,
            null,
        )

        return mapOf(
            "name" to f.name,
            "size" to f.length(),
            "uri" to uri.toString(),
            "video" to video,
        )
    }

    private fun mimeOf(f: File): String = when (f.extension.lowercase()) {
        "m4a" -> "audio/mp4"
        "mp3" -> "audio/mpeg"
        "opus" -> "audio/opus"
        "ogg" -> "audio/ogg"
        "webm" -> "video/webm"
        "mkv" -> "video/x-matroska"
        "mp4" -> "video/mp4"
        else -> if (f.extension.isEmpty()) "application/octet-stream" else "audio/*"
    }

    /** Isi Music/Mull dan Movies/Mull, buat layar Pustaka. */
    private fun listLibrary(): List<Map<String, Any?>> {
        val hasil = mutableListOf<Map<String, Any?>>()

        for (video in listOf(false, true)) {
            val koleksi = if (video) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val folder = if (video) "${Environment.DIRECTORY_MOVIES}/Mull/" else "${Environment.DIRECTORY_MUSIC}/Mull/"

            // ARTIST cuma ada di koleksi audio. Terisi kalau yt-dlp sempat
            // menanam tag (--embed-metadata) dan MediaStore sudah memindainya.
            val kolom = buildList {
                add(MediaStore.MediaColumns._ID)
                add(MediaStore.MediaColumns.DISPLAY_NAME)
                add(MediaStore.MediaColumns.SIZE)
                add(MediaStore.MediaColumns.DURATION)
                add(MediaStore.MediaColumns.DATE_ADDED)
                add(MediaStore.MediaColumns.RELATIVE_PATH)
                add(MediaStore.MediaColumns.OWNER_PACKAGE_NAME)
                if (!video) {
                    add(MediaStore.Audio.Media.ALBUM)
                    add(MediaStore.Audio.Media.ARTIST)
                    add(MediaStore.Audio.Media.TITLE)
                }
            }.toTypedArray()

            // Lagu: kalau izin baca audio ada, ambil SEMUA yang ditandai musik
            // oleh MediaStore (rekaman suara, nada dering, notifikasi nggak ikut),
            // plus unduhan Mull. Tanpa izin, MediaStore cuma ngasih berkas
            // milik app ini sendiri, jadi tetap pakai filter folder.
            val semua = !video && hasAudioPermission()
            val (pilih, arg) = if (semua) {
                "${MediaStore.Audio.Media.IS_MUSIC}!=0 OR ${MediaStore.MediaColumns.RELATIVE_PATH}=?" to arrayOf(folder)
            } else {
                "${MediaStore.MediaColumns.RELATIVE_PATH}=?" to arrayOf(folder)
            }

            contentResolver.query(
                koleksi,
                kolom,
                pilih,
                arg,
                "${MediaStore.MediaColumns.DATE_ADDED} DESC",
            )?.use { c ->
                val iId = c.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                val iNama = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
                val iUkuran = c.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
                val iDurasi = c.getColumnIndex(MediaStore.MediaColumns.DURATION)
                val iTanggal = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)
                val iArtis = c.getColumnIndex(MediaStore.Audio.Media.ARTIST)
                val iJudul = c.getColumnIndex(MediaStore.Audio.Media.TITLE)
                val iAlbum = c.getColumnIndex(MediaStore.Audio.Media.ALBUM)
                val iFolder = c.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
                val iPemilik = c.getColumnIndex(MediaStore.MediaColumns.OWNER_PACKAGE_NAME)

                while (c.moveToNext()) {
                    val id = c.getLong(iId)
                    hasil += mapOf(
                        "uri" to ContentUris.withAppendedId(koleksi, id).toString(),
                        "name" to c.getString(iNama),
                        "title" to if (iJudul >= 0 && !c.isNull(iJudul)) c.getString(iJudul) else null,
                        "artist" to if (iArtis >= 0 && !c.isNull(iArtis)) c.getString(iArtis) else null,
                        "size" to c.getLong(iUkuran),
                        "durationMs" to if (iDurasi >= 0 && !c.isNull(iDurasi)) c.getLong(iDurasi) else null,
                        "addedAt" to c.getLong(iTanggal),
                        "album" to if (iAlbum >= 0 && !c.isNull(iAlbum)) c.getString(iAlbum) else null,
                        "folder" to if (iFolder >= 0 && !c.isNull(iFolder)) c.getString(iFolder) else null,
                        // Berkas unduhan Mull: cuma yang ini boleh dihapus dari app.
                        "mull" to (iFolder >= 0 && c.getString(iFolder) == folder),
                        // Dibuat oleh pemasangan app yang SEKARANG: bisa dihapus
                        // tanpa dialog sistem.
                        "own" to (iPemilik >= 0 && c.getString(iPemilik) == packageName),
                        "video" to video,
                    )
                }
            }
        }

        return hasil
    }

    /**
     * Sampul bawaan berkas (tag gambar di lagu, atau cuplikan video), dikecilkan
     * jadi JPEG. Null kalau berkasnya memang nggak punya gambar.
     */
    private fun thumbnail(uri: Uri, size: Int): ByteArray? = try {
        val bmp = contentResolver.loadThumbnail(uri, Size(size, size), null)
        ByteArrayOutputStream().use { out ->
            bmp.compress(Bitmap.CompressFormat.JPEG, 85, out)
            bmp.recycle()
            out.toByteArray()
        }
    } catch (e: Exception) {
        null
    }

    override fun onDestroy() {
        mic.stop()
        pool.shutdownNow()
        super.onDestroy()
    }

    private companion object {
        const val PERMISSION_REQUEST = 1001
        const val DELETE_REQUEST = 1002
    }
}
