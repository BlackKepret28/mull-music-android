import 'package:flutter/material.dart';

/// Kotak abu-abu yang berdenyut pelan, buat mengisi tempat selagi data datang.
///
/// Dipakai daripada satu lingkaran berputar di tengah layar: bentuk daftarnya
/// langsung kelihatan, jadi tunggunya kerasa lebih pendek walau waktunya sama.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _Denyut(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.08),
          shape: shape,
          borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Satu animasi denyut dipakai bareng semua anaknya, jadi seluruh kerangka
/// berdenyut serempak dan cuma ada satu ticker.
class _Denyut extends StatefulWidget {
  const _Denyut({required this.child});

  final Widget child;

  @override
  State<_Denyut> createState() => _DenyutState();
}

class _DenyutState extends State<_Denyut> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

/// Kerangka daftar lagu, bentuknya menyerupai [TrackTile] sungguhan.
class SkeletonTrackList extends StatelessWidget {
  const SkeletonTrackList({super.key, this.jumlah = 8, this.padding});

  final int jumlah;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding ?? const EdgeInsets.only(top: 4),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: jumlah,
      itemBuilder: (context, i) {
        // Lebar judul dibikin beda-beda biar nggak kelihatan seperti tabel.
        final lebarJudul = [0.82, 0.64, 0.74, 0.58][i % 4];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const SkeletonBox(width: 48, height: 48, radius: 6),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: lebarJudul,
                      child: const SkeletonBox(height: 13),
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: lebarJudul * 0.55,
                      child: const SkeletonBox(height: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
