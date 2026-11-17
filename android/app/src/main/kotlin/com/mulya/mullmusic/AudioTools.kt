package com.mulya.mullmusic

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioManager
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AudioEffect
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaRecorder
import android.net.Uri
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Alat audio buat Kenali lagu. Semua keluaran berupa PCM 16-bit mono 16 kHz
 * (little-endian), bentuk yang dibutuhkan generator sidik jari Shazam di Dart.
 */
object PcmDecoder {
    const val RATE = 16000

    /**
     * Baca potongan audio dari berkas (content://, path) atau URL http.
     * Pakai MediaExtractor + MediaCodec bawaan Android, jadi m4a, mp3, opus,
     * dan webm kebaca tanpa ffmpeg. Balikin {pcm, durationMs}.
     */
    fun decode(
        ctx: Context,
        source: String,
        headers: Map<String, String>?,
        startMs: Long,
        lengthMs: Long,
    ): Map<String, Any?> {
        val ex = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            when {
                source.startsWith("content://") || source.startsWith("file://") ->
                    ex.setDataSource(ctx, Uri.parse(source), headers)
                source.startsWith("http://") || source.startsWith("https://") ->
                    ex.setDataSource(source, headers ?: emptyMap())
                else -> ex.setDataSource(source)
            }

            var track = -1
            var format: MediaFormat? = null
            for (i in 0 until ex.trackCount) {
                val f = ex.getTrackFormat(i)
                if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                    track = i
                    format = f
                    break
                }
            }
            if (track < 0 || format == null) throw IOException("Nggak ada suara di sumber ini.")
            ex.selectTrack(track)

            val durUs = if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else -1L
            val startUs = startMs * 1000
            if (startUs > 0) ex.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

            val mime = format.getString(MediaFormat.KEY_MIME)!!
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var floatPcm = false

            val mono = FloatBuilder()
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            val deadline = System.currentTimeMillis() + 90_000

            while (System.currentTimeMillis() < deadline) {
                val need = lengthMs * rate / 1000
                if (mono.size >= need) break

                if (!inputDone) {
                    val inIdx = codec.dequeueInputBuffer(10_000)
                    if (inIdx >= 0) {
                        val buf = codec.getInputBuffer(inIdx)!!
                        val n = ex.readSampleData(buf, 0)
                        if (n < 0) {
                            codec.queueInputBuffer(inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(inIdx, 0, n, ex.sampleTime, 0)
                            ex.advance()
                        }
                    }
                }

                val outIdx = codec.dequeueOutputBuffer(info, 10_000)
                when {
                    outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val of = codec.outputFormat
                        rate = of.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = of.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        floatPcm = of.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                            of.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
                    }
                    outIdx >= 0 -> {
                        val out = codec.getOutputBuffer(outIdx)!!
                        out.position(info.offset)
                        out.limit(info.offset + info.size)
                        tambahMono(out.slice().order(ByteOrder.nativeOrder()), floatPcm, channels, rate, info.presentationTimeUs, startUs, mono)
                        codec.releaseOutputBuffer(outIdx, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                    }
                }
            }

            val need = (lengthMs * rate / 1000).toInt()
            val samples = mono.take(min(need, mono.size))
            return mapOf(
                "pcm" to keBytes(resample(samples, rate)),
                "durationMs" to if (durUs > 0) durUs / 1000 else null,
            )
        } finally {
            try { codec?.stop() } catch (_: Throwable) {}
            try { codec?.release() } catch (_: Throwable) {}
            ex.release()
        }
    }

    /** Gabungkan kanal jadi satu, buang sampel yang masih sebelum titik mulai. */
    private fun tambahMono(
        buf: ByteBuffer,
        floatPcm: Boolean,
        channels: Int,
        rate: Int,
        ptsUs: Long,
        startUs: Long,
        mono: FloatBuilder,
    ) {
        val ch = channels.coerceAtLeast(1)
        val frames = if (floatPcm) buf.remaining() / 4 / ch else buf.remaining() / 2 / ch
        var skip = 0
        if (ptsUs < startUs) {
            skip = ((startUs - ptsUs) * rate / 1_000_000).toInt().coerceAtMost(frames)
        }
        if (floatPcm) {
            val fb = buf.asFloatBuffer()
            for (f in skip until frames) {
                var s = 0f
                for (c in 0 until ch) s += fb.get(f * ch + c)
                mono.add(s / ch * 32767f)
            }
        } else {
            val sb = buf.asShortBuffer()
            for (f in skip until frames) {
                var s = 0f
                for (c in 0 until ch) s += sb.get(f * ch + c).toFloat()
                mono.add(s / ch)
            }
        }
    }

    /**
     * Ubah ke 16 kHz. Turun: rata-rata tiap jendela (penyaring lolos-bawah
     * kasar, cukup buat sidik jari). Naik: interpolasi linear.
     */
    fun resample(src: FloatArray, rate: Int): FloatArray {
        if (rate == RATE || src.isEmpty()) return src
        val ratio = rate.toDouble() / RATE
        val n = (src.size / ratio).toInt()
        val out = FloatArray(n)
        if (ratio > 1) {
            for (i in 0 until n) {
                val a = floor(i * ratio).toInt()
                val b = min(src.size, ceil((i + 1) * ratio).toInt())
                var s = 0f
                for (j in a until b) s += src[j]
                out[i] = if (b > a) s / (b - a) else 0f
            }
        } else {
            for (i in 0 until n) {
                val p = i * ratio
                val a = p.toInt()
                val b = min(src.size - 1, a + 1)
                val t = (p - a).toFloat()
                out[i] = src[a] * (1 - t) + src[b] * t
            }
        }
        return out
    }

    fun keBytes(samples: FloatArray): ByteArray {
        val bb = ByteBuffer.allocate(samples.size * 2).order(ByteOrder.LITTLE_ENDIAN)
        for (s in samples) bb.putShort(s.coerceIn(-32768f, 32767f).toInt().toShort())
        return bb.array()
    }

    fun keBytes(samples: ShortArray, from: Int, count: Int): ByteArray {
        val bb = ByteBuffer.allocate(count * 2).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until count) bb.putShort(samples[(from + i) % samples.size])
        return bb.array()
    }
}

/** FloatArray yang bisa memanjang. */
class FloatBuilder {
    private var data = FloatArray(16000 * 16)
    var size = 0
        private set

    fun add(v: Float) {
        if (size == data.size) data = data.copyOf(data.size * 2)
        data[size++] = v
    }

    fun take(n: Int): FloatArray = data.copyOf(n)
}

/**
 * Rekam mikrofon 16 kHz mono. Yang disimpan cuma 14 detik terakhir
 * (cincin), cukup buat satu potongan sidik jari 12 detik.
 */
class MicRecorder {
    private val ring = ShortArray(PcmDecoder.RATE * 14)
    private var written = 0L
    private var rec: AudioRecord? = null
    private var thread: Thread? = null
    private val efek = mutableListOf<AudioEffect>()

    @Volatile var level = 0.0
        private set

    @Volatile private var running = false

    private var t0 = 0L

    val seconds: Double get() = if (t0 == 0L) 0.0 else (System.currentTimeMillis() - t0) / 1000.0

    @SuppressLint("MissingPermission") // izinnya dicek dulu di MainActivity
    @Synchronized
    fun start(ctx: Context) {
        stop()
        val min = AudioRecord.getMinBufferSize(
            PcmDecoder.RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        // Sumber MIC biasa diproses buat suara orang (peredam derau + penguat
        // otomatis). Dites 12 Nov di Infinix: musiknya sempat "dibuang" sampai
        // nyaris hening 1,5 detik dan frekuensi tingginya hilang, jadi Shazam
        // nggak kenal. UNPROCESSED (mentah) kalau HP mendukung, cadangannya
        // VOICE_RECOGNITION (menurut CDD Android tanpa peredam/penguat).
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val mentah = am.getProperty(AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED) == "true"
        val sumber = buildList {
            if (mentah) add(MediaRecorder.AudioSource.UNPROCESSED)
            add(MediaRecorder.AudioSource.VOICE_RECOGNITION)
            add(MediaRecorder.AudioSource.MIC)
        }
        var ketemu: AudioRecord? = null
        for (src in sumber) {
            val coba = try {
                AudioRecord(src, PcmDecoder.RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, maxOf(min, PcmDecoder.RATE))
            } catch (_: Throwable) {
                null
            }
            if (coba?.state == AudioRecord.STATE_INITIALIZED) {
                ketemu = coba
                break
            }
            coba?.release()
        }
        val r = ketemu ?: throw IOException("Mikrofon nggak bisa dibuka. Mungkin lagi dipakai app lain.")
        // Matikan juga efek yang mungkin dipasang paksa oleh vendor HP.
        val sesi = r.audioSessionId
        efek.clear()
        try { if (NoiseSuppressor.isAvailable()) NoiseSuppressor.create(sesi)?.let { it.enabled = false; efek += it } } catch (_: Throwable) {}
        try { if (AutomaticGainControl.isAvailable()) AutomaticGainControl.create(sesi)?.let { it.enabled = false; efek += it } } catch (_: Throwable) {}
        try { if (AcousticEchoCanceler.isAvailable()) AcousticEchoCanceler.create(sesi)?.let { it.enabled = false; efek += it } } catch (_: Throwable) {}
        written = 0
        level = 0.0
        rec = r
        running = true
        r.startRecording()
        t0 = System.currentTimeMillis()
        thread = Thread {
            val buf = ShortArray(1600) // 0,1 detik
            while (running) {
                val n = r.read(buf, 0, buf.size)
                if (n <= 0) continue
                var sum = 0.0
                synchronized(ring) {
                    for (i in 0 until n) {
                        ring[((written + i) % ring.size).toInt()] = buf[i]
                        sum += buf[i].toDouble() * buf[i]
                    }
                    written += n
                }
                level = sqrt(sum / n) / 32768.0
            }
        }.apply {
            name = "mull-mic"
            start()
        }
    }

    /** PCM [seconds] detik terakhir (atau semua yang ada kalau belum segitu). */
    fun snapshot(seconds: Double): ByteArray = synchronized(ring) {
        val want = minOf((seconds * PcmDecoder.RATE).toLong(), written, ring.size.toLong()).toInt()
        val from = ((written - want) % ring.size).toInt()
        PcmDecoder.keBytes(ring, from, want)
    }

    @Synchronized
    fun stop() {
        running = false
        thread?.join(500)
        thread = null
        rec?.let {
            try { it.stop() } catch (_: Throwable) {}
            it.release()
        }
        efek.forEach { try { it.release() } catch (_: Throwable) {} }
        efek.clear()
        rec = null
        t0 = 0L
        level = 0.0
    }
}
