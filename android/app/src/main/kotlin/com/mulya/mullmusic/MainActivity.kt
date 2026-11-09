package com.mulya.mullmusic

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
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
 *   listLibrary() -> isi Music/Mull dan Movies/Mull dari MediaStore
 *   deleteMedia(uri) -> hapus satu berkas pustaka
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
            "listLibrary" -> mapOf("items" to listLibrary())
            "deleteMedia" -> {
                val uri = Uri.parse(call.argument<String>("uri")!!)
                mapOf("deleted" to (contentResolver.delete(uri, null, null) > 0))
            }
            "writeReport" -> {
                val f = File(getExternalFilesDir(null), "spike-report.txt")
                f.writeText(call.argument<String>("text") ?: "")
                f.absolutePath
            }
            else -> throw IllegalArgumentException("Metode tidak dikenal: ${call.method}")
        }
    }

    // ---- Izin notifikasi (Android 13+) ----------------------------------

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(mapOf("granted" to true))
            return
        }
        val izin = Manifest.permission.POST_NOTIFICATIONS
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
                if (!video) {
                    add(MediaStore.Audio.Media.ARTIST)
                    add(MediaStore.Audio.Media.TITLE)
                }
            }.toTypedArray()

            contentResolver.query(
                koleksi,
                kolom,
                "${MediaStore.MediaColumns.RELATIVE_PATH}=?",
                arrayOf(folder),
                "${MediaStore.MediaColumns.DATE_ADDED} DESC",
            )?.use { c ->
                val iId = c.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                val iNama = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
                val iUkuran = c.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
                val iDurasi = c.getColumnIndex(MediaStore.MediaColumns.DURATION)
                val iTanggal = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)
                val iArtis = c.getColumnIndex(MediaStore.Audio.Media.ARTIST)
                val iJudul = c.getColumnIndex(MediaStore.Audio.Media.TITLE)

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
                        "video" to video,
                    )
                }
            }
        }

        return hasil
    }

    override fun onDestroy() {
        pool.shutdownNow()
        super.onDestroy()
    }

    private companion object {
        const val PERMISSION_REQUEST = 1001
    }
}
