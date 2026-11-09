import 'package:flutter/material.dart';

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

/// Navigasi bawah bikinan sendiri.
///
/// Pakai ini daripada [NavigationBar] bawaan Material karena yang bawaan
/// selalu ngecat latarnya sendiri, jadi panel kacanya ketutupan.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.index, required this.onPilih});

  final int index;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 62,
      child: Row(
        children: [
          for (var i = 0; i < navItems.length; i++)
            Expanded(
              child: _Tombol(
                item: navItems[i],
                aktif: i == index,
                warnaAktif: cs.primary,
                warnaMati: cs.onSurfaceVariant,
                onTap: () => onPilih(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tombol extends StatelessWidget {
  const _Tombol({
    required this.item,
    required this.aktif,
    required this.warnaAktif,
    required this.warnaMati,
    required this.onTap,
  });

  final NavItem item;
  final bool aktif;
  final Color warnaAktif;
  final Color warnaMati;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warna = aktif ? warnaAktif : warnaMati;

    return Semantics(
      selected: aktif,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pil aksen di belakang ikon yang aktif. Lebih kebaca daripada
            // cuma beda warna, apalagi di atas panel kaca.
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 44,
              height: 26,
              decoration: BoxDecoration(
                color: aktif ? warnaAktif.withValues(alpha: 0.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    aktif ? item.iconAktif : item.icon,
                    key: ValueKey(aktif),
                    size: 21,
                    color: warna,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                fontWeight: aktif ? FontWeight.w600 : FontWeight.w500,
                color: warna,
              ),
            ),
          ],
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
