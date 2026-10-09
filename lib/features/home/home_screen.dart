import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../history/history_screen.dart';
import '../review/review_screen.dart';
import '../scan/scan_screen.dart';

/// Upload limit from the spec's edge cases.
const int maxUploadBytes = 20 * 1024 * 1024;

final _hasCameraProvider = FutureProvider<bool>((_) async {
  try {
    return (await availableCameras()).isNotEmpty;
  } on Object {
    return false;
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCamera = ref.watch(_hasCameraProvider).value ?? false;
    final pending =
        ref.watch(recordsProvider).value?.where((r) => r.syncStatus == SyncStatus.pending).length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('FOCR')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (hasCamera) ...[
              FilledButton.icon(
                key: const Key('scan'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan with camera'),
                style: _bigButton,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ScanScreen()),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.tonalIcon(
              key: const Key('upload'),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Upload screenshot / photo'),
              style: _bigButton,
              onPressed: () => _upload(context),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('manual'),
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text('Enter number manually'),
              style: _bigButton,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ReviewScreen()),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              subtitle: Text(pending == 0 ? 'Nothing pending' : '$pending waiting to sync'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _bigButton = ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)),
  );

  Future<void> _upload(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: false);
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open the image picker: $e')));
      return;
    }
    if (file == null) return;
    if (await file.length() > maxUploadBytes) {
      messenger.showSnackBar(const SnackBar(content: Text('Image is larger than 20 MB')));
      return;
    }
    final bytes = await file.readAsBytes();
    await navigator.push(MaterialPageRoute<void>(builder: (_) => ReviewScreen(sourceImage: bytes)));
  }
}
