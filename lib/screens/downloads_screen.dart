import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

/// Antrean dan riwayat unduhan. Antrean sungguhan nyusul.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key, this.onGoSearch});

  final VoidCallback? onGoSearch;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unduhan')),
      body: EmptyState(
        icon: Icons.download_outlined,
        title: 'Belum ada unduhan',
        message: 'Unduhan yang sedang jalan dan yang sudah selesai muncul di sini.',
        action: FilledButton(
          onPressed: onGoSearch,
          child: const Text('Cari lagu'),
        ),
      ),
    );
  }
}
