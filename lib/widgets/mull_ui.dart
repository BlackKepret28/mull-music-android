import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../services/cover_color.dart';
import '../theme.dart';
import 'bottom_nav.dart';
import 'glass_surface.dart';

// Komponen dasar gaya MSA. Ukuran dan warnanya disalin dari
// `my_secret_app/lib/shared/widgets/msa_*.dart` supaya dua app Mulya terasa
// satu keluarga.

/// Latar putih keabuan + cahaya pastel (MsaBackground). Digambar pakai
/// RadialGradient, bukan filter blur, jadi ringan.
///
/// Kalau [warnaSampul] diisi (ada lagu yang diputar), cahaya pastelnya
/// diganti warna dari sampul lagu itu, tetap lembut.
class LatarMull extends StatelessWidget {
  const LatarMull({super.key, this.warnaSampul, this.halus = false});

  final Color? warnaSampul;

  /// Versi dua cahaya saja, buat halaman yang dibuka di atas tab
  /// (Pengaturan, detail playlist).
  final bool halus;

  /// Ubah satu warna sampul jadi empat cahaya yang senada.
  static List<Color> cahayaDari(Color asal, bool gelap) {
    final hsl = HSLColor.fromColor(asal);
    Color geser(double derajat) {
      final h = hsl.withHue((hsl.hue + derajat) % 360);
      return gelap
          ? h.withSaturation((hsl.saturation * 0.8).clamp(0.25, 0.6)).withLightness(0.32).toColor()
          : h.withSaturation((hsl.saturation * 0.9).clamp(0.35, 0.85)).withLightness(0.84).toColor();
    }

    return [geser(0), geser(28), geser(-28), geser(56)];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final o = c.blobOpacity;
    final sampul = warnaSampul;
    final cahaya = sampul == null
        ? [c.blobBlue, c.blobLavender, c.blobPeach, c.blobMint]
        : cahayaDari(sampul, context.gelap);

    return RepaintBoundary(
      child: ColoredBox(
        color: c.bg,
        child: LayoutBuilder(
          builder: (context, k) {
            final w = k.maxWidth;
            final h = k.maxHeight;
            final daftar = halus
                ? <Widget>[
                    _Cahaya(cahaya[1], o * 0.7, right: -0.40 * w, top: -0.12 * h, size: 0.9 * w),
                    _Cahaya(cahaya[0], o * 0.45, left: -0.40 * w, bottom: -0.10 * h, size: 0.9 * w),
                  ]
                : <Widget>[
                    _Cahaya(cahaya[0], o, left: -0.32 * w, top: -0.10 * h, size: 1.0 * w),
                    _Cahaya(cahaya[1], o, right: -0.40 * w, top: 0.04 * h, size: 0.9 * w),
                    _Cahaya(cahaya[2], o * 0.9, left: -0.35 * w, bottom: 0.06 * h, size: 0.95 * w),
                    _Cahaya(cahaya[3], o, right: -0.38 * w, bottom: -0.08 * h, size: 1.05 * w),
                  ];
            return Stack(clipBehavior: Clip.hardEdge, children: daftar);
          },
        ),
      ),
    );
  }
}

class _Cahaya extends StatelessWidget {
  const _Cahaya(this.warna, this.opasitas, {this.left, this.top, this.right, this.bottom, required this.size});

  final Color warna;
  final double opasitas;
  final double? left, top, right, bottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: size,
      height: size,
      // Warna berganti pelan waktu lagu ganti, bukan loncat.
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: warna),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOut,
        builder: (context, w, _) {
          final x = w ?? warna;
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  x.withValues(alpha: opasitas),
                  x.withValues(alpha: opasitas * 0.55),
                  x.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Kartu konten yang solid dan kalem (MsaCard), bukan kaca, biar teks enak
/// dibaca lama-lama.
class KartuMull extends StatelessWidget {
  const KartuMull({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = MullUkuran.kartu,
    this.onTap,
    this.onLongPress,
    this.warna,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? warna;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final sudut = BorderRadius.circular(radius);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: warna ?? c.surface,
        borderRadius: sudut,
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: c.cardShadow, blurRadius: 24, offset: const Offset(0, 6))],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: sudut,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Label bagian huruf kapital kecil, abu, jarak huruf renggang
/// ("ANTREAN", "TAMPILAN").
class LabelBagian extends StatelessWidget {
  const LabelBagian(this.teks, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 0, 0, 10)});

  final String teks;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              teks.toUpperCase(),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: context.mull.textMuted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Tautan aksi kecil warna aksen di kanan judul ("Lihat semua", "+ Baru").
class TautanAksi extends StatelessWidget {
  const TautanAksi({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.mull.accentStrong),
          ),
        ),
      ),
    );
  }
}

/// Judul kartu + aksi di kanan (MsaCardHeader).
class KepalaKartu extends StatelessWidget {
  const KepalaKartu({super.key, required this.judul, this.aksi});

  final String judul;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(judul, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        ?aksi,
      ],
    );
  }
}

/// Tombol ikon bulat (MsaIconButton). `kaca: true` buat yang melayang.
class TombolIkon extends StatelessWidget {
  const TombolIkon({
    super.key,
    required this.ikon,
    required this.tooltip,
    required this.onPressed,
    this.kaca = false,
    this.ukuran = 44,
    this.ukuranIkon = 22,
    this.warna,
    this.child,
  });

  final IconData ikon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool kaca;
  final double ukuran;
  final double ukuranIkon;
  final Color? warna;

  /// Ganti ikon dengan widget lain (mis. indikator muat).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final tinta = Material(
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: ukuran,
          height: ukuran,
          child: Center(child: child ?? Icon(ikon, size: ukuranIkon, color: warna ?? c.icon)),
        ),
      ),
    );
    final badan = kaca
        ? GlassSurface(radius: ukuran / 2, width: ukuran, height: ukuran, child: tinta)
        : SizedBox(width: ukuran, height: ukuran, child: tinta);
    return Tooltip(
      message: tooltip,
      child: Semantics(button: true, label: tooltip, excludeSemantics: true, child: badan),
    );
  }
}

/// Ikon garis berwarna di dalam kotak pastel bersudut bulat.
class KotakIkon extends StatelessWidget {
  const KotakIkon({super.key, required this.ikon, this.nada = NadaIkon.aksen, this.ukuran = 40});

  final IconData ikon;
  final NadaIkon nada;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    final (latar, depan) = context.mull.nada(nada);
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: BoxDecoration(color: latar, borderRadius: BorderRadius.circular(ukuran * 0.32)),
      child: Icon(ikon, size: ukuran * 0.52, color: depan),
    );
  }
}

/// Chip filter pil (MsaChip). Terpilih = aksen solid.
class ChipMull extends StatelessWidget {
  const ChipMull({super.key, required this.label, required this.terpilih, required this.onTap});

  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final sudut = BorderRadius.circular(18);
    return Semantics(
      selected: terpilih,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 36,
        decoration: BoxDecoration(
          color: terpilih ? c.accent : c.surface,
          borderRadius: sudut,
          border: Border.all(color: terpilih ? c.accent : c.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: sudut,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: terpilih ? FontWeight.w700 : FontWeight.w600,
                    color: terpilih ? c.onAccent : c.icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol bulat aksen solid dengan bayangan aksen lembut (FAB MSA).
/// Dipakai buat Putar di pemutar mini, layar Sedang diputar, dan playlist.
class TombolPutar extends StatelessWidget {
  const TombolPutar({
    super.key,
    required this.ikon,
    required this.tooltip,
    required this.onPressed,
    this.ukuran = 56,
    this.child,
  });

  final IconData ikon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double ukuran;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final aktif = onPressed != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: aktif || child != null ? 1 : 0.45,
      child: Container(
        width: ukuran,
        height: ukuran,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.35),
              blurRadius: ukuran * 0.4,
              offset: Offset(0, ukuran * 0.16),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: c.onAccent,
            disabledBackgroundColor: c.accent,
            disabledForegroundColor: c.onAccent,
            fixedSize: Size.square(ukuran),
          ),
          icon: child ?? Icon(ikon, size: ukuran * 0.5),
        ),
      ),
    );
  }
}

/// Petunjuk kecil rata tengah di akhir daftar.
class PetunjukAkhir extends StatelessWidget {
  const PetunjukAkhir(this.teks, {super.key});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 14, 32, 4),
      child: Text(
        teks,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, height: 1.4, color: context.mull.textSubtle),
      ),
    );
  }
}

/// Isi panel kaca header halaman (ala header "Catatan" di MSA): judul besar,
/// subjudul, tombol di kanan, lalu isi tambahan (kolom cari, chip, segmen).
class HeaderKaca extends StatelessWidget {
  const HeaderKaca({
    super.key,
    required this.judul,
    this.subjudul,
    this.depan,
    this.aksi = const [],
    this.bawah,
  });

  final String judul;
  final String? subjudul;

  /// Tombol di kiri judul (mis. kembali).
  final Widget? depan;
  final List<Widget> aksi;
  final Widget? bawah;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    return GlassSurface(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (depan != null) ...[depan!, const SizedBox(width: 8)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      judul,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                    if (subjudul != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subjudul!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              ...aksi,
            ],
          ),
          if (bawah != null) ...[
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.only(right: 6), child: bawah!),
          ],
        ],
      ),
    );
  }
}

/// Kerangka halaman dengan header kaca yang melayang. Isinya menggulir di
/// belakang header dan kelihatan buram lewat kacanya.
///
/// [isi] menerima padding yang wajib dipakai: atas = tinggi header,
/// bawah = ruang bar bawah.
class HalamanKaca extends StatefulWidget {
  const HalamanKaca({super.key, required this.header, required this.isi});

  final Widget header;
  final Widget Function(BuildContext context, EdgeInsets padding) isi;

  @override
  State<HalamanKaca> createState() => _HalamanKacaState();
}

class _HalamanKacaState extends State<HalamanKaca> {
  /// Perkiraan awal; diganti ukuran asli setelah frame pertama.
  double _tinggi = 76;

  @override
  Widget build(BuildContext context) {
    final atas = MediaQuery.paddingOf(context).top + 8;
    final bawah = RuangBawah.of(context);
    final padding = EdgeInsets.only(
      top: atas + _tinggi + 14,
      bottom: (bawah > 0 ? bawah : MediaQuery.paddingOf(context).bottom) + 16,
    );

    return Stack(
      children: [
        Positioned.fill(child: widget.isi(context, padding)),
        Positioned(
          top: atas,
          left: 12,
          right: 12,
          child: _Ukur(
            onUkur: (h) {
              if ((h - _tinggi).abs() > 0.5) setState(() => _tinggi = h);
            },
            child: widget.header,
          ),
        ),
      ],
    );
  }
}

/// Lapor tinggi anaknya setiap kali berubah.
class _Ukur extends SingleChildRenderObjectWidget {
  const _Ukur({required this.onUkur, required super.child});

  final ValueChanged<double> onUkur;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderUkur(onUkur);

  @override
  void updateRenderObject(BuildContext context, _RenderUkur renderObject) {
    renderObject.onUkur = onUkur;
  }
}

class _RenderUkur extends RenderProxyBox {
  _RenderUkur(this.onUkur);

  ValueChanged<double> onUkur;
  double? _lama;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h == _lama) return;
    _lama = h;
    WidgetsBinding.instance.addPostFrameCallback((_) => onUkur(h));
  }
}

/// Lembar bawah ala MSA (`msa_sheets.dart`): kartu pekat bersudut 30 yang
/// melayang 10 px dari tepi layar, dengan pegangan kecil di atas.
Future<T?> tampilkanLembar<T>(BuildContext context, {String? judul, required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) {
      final c = ctx.mull;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Container(
            decoration: BoxDecoration(
              color: c.surfaceSolid,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: c.border),
              boxShadow: [BoxShadow(color: c.shadow, blurRadius: 40, offset: const Offset(0, 12))],
            ),
            child: SafeArea(
              top: false,
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(30),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 6),
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(color: c.checkBorder, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                      if (judul != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
                          child: Text(
                            judul,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                          ),
                        ),
                      builder(ctx),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Latar pastel. Waktu ada lagu diputar, cahayanya ikut warna sampulnya.
class LatarSampul extends StatefulWidget {
  const LatarSampul({super.key, required this.sampul, this.halus = false});

  final String? sampul;
  final bool halus;

  @override
  State<LatarSampul> createState() => _LatarSampulState();
}

class _LatarSampulState extends State<LatarSampul> {
  Color? _warna;

  @override
  void initState() {
    super.initState();
    _hitung();
  }

  @override
  void didUpdateWidget(LatarSampul lama) {
    super.didUpdateWidget(lama);
    // Cuma dihitung ulang kalau sampulnya ganti, bukan tiap pindah tab.
    if (lama.sampul != widget.sampul) _hitung();
  }

  Future<void> _hitung() async {
    final url = widget.sampul;
    if (url == null) {
      if (_warna != null) setState(() => _warna = null);
      return;
    }
    // Warna lama dibiarkan dulu sampai yang baru siap, biar nggak kedip.
    final w = await CoverColor.dari(url);
    if (!mounted || widget.sampul != url) return;
    setState(() => _warna = w);
  }

  @override
  Widget build(BuildContext context) => LatarMull(warnaSampul: _warna, halus: widget.halus);
}
