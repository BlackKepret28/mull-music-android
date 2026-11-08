import 'package:flutter/material.dart';

import '../models/track.dart';
import '../widgets/empty_state.dart';

/// Cari lagu atau video. Pencarian sungguhan (lewat yt-dlp `ytsearch`)
/// disambung di commit berikutnya; sekarang baru kolom dan tata letaknya.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.onTapTrack});

  final void Function(Track track)? onTapTrack;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String q) {
    if (q.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pencarian belum aktif, nyusul sebentar lagi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onSubmitted: _submit,
          decoration: InputDecoration(
            hintText: 'Lagu, artis, atau tempel tautan',
            prefixIcon: const Icon(Icons.search, size: 22),
            suffixIcon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => _controller.clear(),
                    ),
            ),
          ),
        ),
      ),
      body: const EmptyState(
        icon: Icons.search,
        title: 'Mau dengar apa?',
        message: 'Tulis judul lagu, nama artis, atau tempel tautan YouTube.',
      ),
    );
  }
}
