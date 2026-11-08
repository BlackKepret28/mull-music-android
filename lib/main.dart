import 'dart:async';

import 'package:flutter/material.dart';

import 'ytdlp.dart';

// SPIKE: buktiin yt-dlp jalan di HP sebelum bikin UI beneran.
// Semua konten uji berlisensi Creative Commons.
const kMusicUrl = 'https://music.youtube.com/watch?v=owrhKIN3Y90'; // Kevin MacLeod - Carefree (CC-BY 4.0)
const kVideoUrl = 'https://www.youtube.com/watch?v=aqz-KE-bpKQ'; // Big Buck Bunny, Blender Foundation (CC-BY)
const kOtherUrl = 'https://commons.wikimedia.org/wiki/File:Big_Buck_Bunny_4K.webm'; // Wikimedia Commons (CC-BY 3.0)

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mull Music',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF6C7A89), useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C7A89),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const SpikePage(),
    );
  }
}

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  final _log = <String>[];
  final _scroll = ScrollController();
  StreamSubscription<YtDlpProgress>? _sub;
  bool _running = false;
  String? _currentId;
  String _progress = '';

  @override
  void initState() {
    super.initState();
    _sub = YtDlp.progress.listen((p) {
      setState(() => _progress = '${p.id}: ${p.progress.toStringAsFixed(1)}%  sisa ${p.eta} dtk');
    });
    YtDlp.autorun().then((auto) {
      if (auto) _runAll();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _add(String s) {
    debugPrint('MullSpike: $s');
    setState(() => _log.add(s));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  String _mb(num bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  Future<void> _step(String name, Future<void> Function() body) async {
    _add('--- $name');
    final sw = Stopwatch()..start();
    try {
      await body();
      _add('LULUS $name (${sw.elapsedMilliseconds} ms)');
    } catch (e) {
      _add('GAGAL $name (${sw.elapsedMilliseconds} ms): $e');
    }
  }

  Future<void> _download(String id, String url, List<String> args) async {
    _currentId = id;
    final r = await YtDlp.download(id, url, args: args);
    _currentId = null;
    final files = (r['files'] as List).cast<Map>();
    for (final f in files) {
      _add('  file: ${f['name']} (${_mb(f['size'] as num)})');
    }
    _add('  exit ${r['exitCode']}, ${r['ms']} ms');
    if (files.isEmpty) throw Exception('tidak ada file. stderr: ${r['err']}');
  }

  Future<void> _runAll() async {
    if (_running) return;
    setState(() {
      _running = true;
      _log.clear();
    });

    await _step('init', () async {
      final ms = await YtDlp.init();
      _add('  init pertama: $ms ms');
      _add('  yt-dlp bawaan: ${await YtDlp.version()}');
    });

    await _step('update yt-dlp (stable)', () async {
      final r = await YtDlp.update();
      _add('  ${r['status']} -> ${r['version']} (${r['ms']} ms)');
    });

    await _step('runtime JS (yt-dlp -v)', () async {
      final r = await YtDlp.exec(['-v', '--simulate', '--no-playlist', kVideoUrl]);
      final err = (r['err'] as String).split('\n');
      final keep = err.where((l) {
        final s = l.toLowerCase();
        return s.contains('js runtime') ||
            s.contains('jsc') ||
            s.contains('ejs') ||
            s.contains('challenge') ||
            s.contains('warning') ||
            s.contains('error');
      });
      for (final l in keep.take(15)) {
        _add('  $l');
      }
      final all = err.join('\n').toLowerCase();
      if (all.contains('no supported javascript runtime')) throw Exception('runtime JS tidak ketemu');
      if (all.contains('challenge solving failed')) throw Exception('challenge YouTube gagal dipecahkan');
      if (r['exitCode'] != 0) throw Exception('exit ${r['exitCode']}');
    });

    await _step('getInfo video YouTube', () async {
      final r = await YtDlp.getInfo(kVideoUrl);
      final formats = (r.info['formats'] as List? ?? const []).cast<Map>();
      final has720 = formats.any((f) => f['height'] == 720 && f['vcodec'] != 'none');
      _add('  "${r.info['title']}", ${formats.length} format, ada 720p: $has720, ${r.ms} ms');
      if (!has720) throw Exception('format 720p tidak ada');
    });

    await _step('unduh lagu YouTube Music (m4a/opus)', () => _download('musik', kMusicUrl, [
          '-f',
          'bestaudio[ext=m4a]/bestaudio[acodec=opus]/bestaudio',
        ]));

    await _step('unduh video 720p (mp4)', () => _download('video720', kVideoUrl, [
          '-f',
          'bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]/bv*[height<=720]+ba',
          '--merge-output-format',
          'mp4',
        ]));

    await _step('unduh situs non-YouTube (Wikimedia)', () => _download('lain', kOtherUrl, ['-f', 'worst']));

    final path = await YtDlp.writeReport(_log.join('\n'));
    _add('Laporan disimpan: $path');
    _add('SPIKE SELESAI');
    setState(() {
      _running = false;
      _progress = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    return Scaffold(
      appBar: AppBar(title: const Text('Mull Music: uji yt-dlp')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FilledButton(
                  onPressed: _running ? null : _runAll,
                  child: Text(_running ? 'Lagi jalan...' : 'Jalankan semua tes'),
                ),
                const SizedBox(width: 12),
                if (_currentId != null)
                  OutlinedButton(onPressed: () => YtDlp.cancel(_currentId!), child: const Text('Batal')),
              ],
            ),
          ),
          if (_progress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_progress, style: mono),
            ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _log.length,
              itemBuilder: (_, i) => Text(_log[i], style: mono),
            ),
          ),
        ],
      ),
    );
  }
}
