import 'package:flutter/material.dart';

import 'models/track.dart';
import 'services/download_service.dart';
import 'services/player_service.dart';
import 'settings.dart';
import 'theme.dart';
import 'widgets/mull_ui.dart';
import 'ytdlp.dart';

/// Aksi yang dipakai banyak layar (Kenali lagu, Impor, Sedang diputar):
/// putar, unduh, dan baris menu di lembar bawah.

void _mintaIzinNotifikasi() => YtDlp.mintaIzinNotifikasi().ignore();

void putarDaftar(List<Track> daftar, int indeks) {
  _mintaIzinNotifikasi();
  MullAudioHandler.instance.putar(daftar, indeks);
}

void putarAcak(List<Track> daftar) {
  _mintaIzinNotifikasi();
  MullAudioHandler.instance.putarAcak(daftar);
}

void unduhLagu(BuildContext context, Track t, {bool video = false, bool diam = false}) {
  _mintaIzinNotifikasi();
  final unduhan = DownloadService.instance;
  unduhan.formatAudio = SettingsScope.of(context).formatAudio;
  unduhan.tambah(t, video: video);
  if (diam) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('"${t.title}" masuk antrean unduhan.')),
  );
}

void kabari(BuildContext context, String pesan) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(pesan)));
}

/// Satu baris di lembar menu: kotak ikon pastel + label.
class BarisMenu extends StatelessWidget {
  const BarisMenu({
    super.key,
    required this.ikon,
    required this.label,
    required this.onTap,
    this.nada = NadaIkon.lavender,
    this.bahaya = false,
    this.keterangan,
  });

  final IconData ikon;
  final String label;
  final String? keterangan;
  final VoidCallback onTap;
  final NadaIkon nada;
  final bool bahaya;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      leading: bahaya
          ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.dangerSoft, borderRadius: BorderRadius.circular(13)),
              child: Icon(ikon, size: 21, color: c.danger),
            )
          : KotakIkon(ikon: ikon, nada: nada),
      title: Text(label, style: bahaya ? TextStyle(color: c.danger) : null),
      subtitle: keterangan == null ? null : Text(keterangan!),
      onTap: onTap,
    );
  }
}
