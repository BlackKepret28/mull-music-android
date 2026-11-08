package com.mulya.mullmusic

import android.os.Handler
import android.os.Looper
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Jembatan Flutter <-> youtubedl-android (yt-dlp + Python + QuickJS + ffmpeg).
 *
 * MethodChannel "mull/ytdlp":
 *   init, version, updateYtDlp, getInfo(url, args?), download(id, url, args?), cancel(id),
 *   exec(args)  -> jalankan yt-dlp mentah (buat diagnosa spike, mis. -v)
 *   launchArgs  -> extra dari intent (mis. autorun=true dari adb)
 *   writeReport(text) -> simpan laporan spike ke files/spike-report.txt
 * EventChannel "mull/ytdlp/progress": {id, progress, eta, line}
 */
class MainActivity : FlutterActivity() {
    private val pool = Executors.newCachedThreadPool()
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    @Volatile private var initialized = false

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
            "writeReport" -> {
                val f = File(getExternalFilesDir(null), "spike-report.txt")
                f.writeText(call.argument<String>("text") ?: "")
                f.absolutePath
            }
            else -> throw IllegalArgumentException("Metode tidak dikenal: ${call.method}")
        }
    }

    override fun onDestroy() {
        pool.shutdownNow()
        super.onDestroy()
    }
}
