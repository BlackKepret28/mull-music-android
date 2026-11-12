import 'package:flutter/material.dart';

import '../theme.dart';

/// Satu tujuan di navigasi bawah.
class NavItem {
  const NavItem({required this.icon, required this.iconAktif, required this.label});

  final IconData icon;
  final IconData iconAktif;
  final String label;
}

/// Ikon sengaja pakai keluarga "rounded", bukan "outlined" bawaan.
/// Sudutnya bulat, jadi nyambung sama panel kaca yang juga membulat;
/// yang outlined kelihatan kaku dan kuno di sebelahnya.
const navItems = <NavItem>[
  NavItem(icon: Icons.home_outlined, iconAktif: Icons.home_rounded, label: 'Beranda'),
  NavItem(icon: Icons.search_rounded, iconAktif: Icons.search_rounded, label: 'Cari'),
  NavItem(icon: Icons.album_outlined, iconAktif: Icons.album_rounded, label: 'Pustaka'),
  NavItem(
    icon: Icons.arrow_circle_down_outlined,
    iconAktif: Icons.arrow_circle_down_rounded,
    label: 'Unduhan',
  ),
];

/// Isi tab bar kaca yang melayang (MsaTabBar). Tab aktif dapat kapsul aksen
/// berisi ikon + label; tab lain cuma ikon abu. Panel kacanya dipasang di
/// [AppShell], bukan di sini.
///
/// Pakai ini daripada [NavigationBar] bawaan Material karena yang bawaan
/// selalu ngecat latarnya sendiri, jadi panel kacanya ketutupan.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.index, required this.onPilih});

  final int index;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    // Tab aktif dapat ruang lebih (40%) supaya labelnya muat utuh; tiga
    // sisanya cuma ikon, jadi cukup berbagi sisanya. Lebarnya dianimasikan.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: LayoutBuilder(
        builder: (context, k) {
          final n = navItems.length;
          final lebarAktif = k.maxWidth * 0.4;
          final lebarLain = (k.maxWidth - lebarAktif) / (n - 1);
          return Row(
            children: [
              for (var i = 0; i < n; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: i == index ? lebarAktif : lebarLain,
                  child: _Tombol(item: navItems[i], aktif: i == index, onTap: () => onPilih(i)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Tombol extends StatelessWidget {
  const _Tombol({required this.item, required this.aktif, required this.onTap});

  final NavItem item;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mull;
    final sudut = BorderRadius.circular(26);
    final warna = aktif ? c.accentStrong : c.textMuted;

    return Tooltip(
      message: item.label,
      child: Semantics(
        button: true,
        selected: aktif,
        label: item.label,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: sudut,
            color: aktif ? c.accent.withValues(alpha: context.gelap ? 0.22 : 0.13) : Colors.transparent,
            border: Border.all(
              color: aktif ? c.accent.withValues(alpha: context.gelap ? 0.32 : 0.18) : Colors.transparent,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: sudut,
              onTap: onTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(aktif ? item.iconAktif : item.icon, size: aktif ? 20 : 23, color: warna),
                  Flexible(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: aktif
                          ? Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                softWrap: false,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: warna),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Berapa tinggi ruang yang ditutupi bar bawah yang mengambang.
///
/// Daftar yang bisa digulir harus nambah ini ke padding bawahnya, supaya
/// baris terakhir nggak ketutup panel kaca.
class RuangBawah extends InheritedWidget {
  const RuangBawah({super.key, required this.tinggi, required super.child});

  final double tinggi;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RuangBawah>()?.tinggi ?? 0;

  @override
  bool updateShouldNotify(RuangBawah oldWidget) => oldWidget.tinggi != tinggi;
}
