import 'package:flutter/material.dart';

/// Pemilih bentuk pil dengan penanda yang meluncur.
///
/// Dipakai ganti `TabBar` bawaan: garis bawah Material kelihatan kaku di
/// sebelah panel kaca yang serba membulat.
class SegmentedPill extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.labels,
    required this.index,
    required this.onPilih,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, c) {
        const tinggi = 38.0;
        const sisip = 3.0;
        final lebarSatu = (c.maxWidth - sisip * 2) / labels.length;

        return Container(
          height: tinggi,
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(tinggi / 2),
          ),
          padding: const EdgeInsets.all(sisip),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: lebarSatu * index,
                width: lebarSatu,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular((tinggi - sisip * 2) / 2),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onPilih(i),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                                color: i == index ? cs.onPrimary : cs.onSurfaceVariant,
                              ),
                              child: Text(labels[i]),
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
      },
    );
  }
}
