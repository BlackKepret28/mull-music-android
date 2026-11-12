import 'package:flutter/material.dart';

import '../theme.dart';

/// Kontrol segmen ala MSA (MsaSegmented): jalur pil abu, segmen terpilih
/// berupa pil pekat yang meluncur (putih di tema terang, gelap di tema gelap).
///
/// Dipakai ganti `TabBar` bawaan: garis bawah Material kelihatan kaku di
/// sebelah panel kaca yang serba membulat.
class SegmentedPill extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.labels,
    required this.index,
    required this.onPilih,
    this.tinggi = 44,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onPilih;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final n = labels.length;
    final sudutDalam = (tinggi - 8) / 2;

    return Container(
      height: tinggi,
      decoration: BoxDecoration(color: c.chipBg, borderRadius: BorderRadius.circular(tinggi / 2)),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment(n == 1 ? 0.0 : -1.0 + 2.0 * index / (n - 1), 0.0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surfaceSolid,
                  borderRadius: BorderRadius.circular(sudutDalam),
                  boxShadow: [BoxShadow(color: c.cardShadow, blurRadius: 10, offset: const Offset(0, 2))],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onPilih(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: MullTheme.font,
                            fontSize: 14,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w600,
                            color: i == index ? c.text : c.textMuted,
                          ),
                          child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
