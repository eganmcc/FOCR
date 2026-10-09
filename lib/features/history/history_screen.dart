import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../review/registration_field.dart';

final _thumbnailProvider = FutureProvider.family<Uint8List?, String>(
  (ref, captureId) => ref.watch(repositoryProvider).captureImage(captureId),
);

/// Saved records, newest first (US5, FR-014). Pending records can be corrected.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load history: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No numbers saved yet'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _RecordTile(record: list[i]),
              ),
      ),
    );
  }
}

class _RecordTile extends ConsumerWidget {
  const _RecordTile({required this.record});

  final RegistrationRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captureId = record.captureId;
    final thumb = captureId == null ? null : ref.watch(_thumbnailProvider(captureId)).value;
    final local = record.confirmedAt.toLocal();
    final pending = record.syncStatus == SyncStatus.pending;

    return ListTile(
      leading: SizedBox.square(
        dimension: 48,
        child: thumb == null
            ? const Icon(Icons.keyboard_outlined)
            : ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(thumb, fit: BoxFit.cover)),
      ),
      title: Text(record.number, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1)),
      subtitle: Text(
        '${MaterialLocalizations.of(context).formatMediumDate(local)} '
        '${TimeOfDay.fromDateTime(local).format(context)}'
        '${record.entryMethod == EntryMethod.auto ? '' : ' · ${record.entryMethod.name}'}'
        '${record.duplicateOverride ? ' · duplicate' : ''}',
      ),
      trailing: Chip(
        label: Text(pending ? 'Pending' : 'Synced'),
        avatar: Icon(pending ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined, size: 18),
        visualDensity: VisualDensity.compact,
      ),
      onTap: pending ? () => _edit(context, ref) : null,
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: record.number);
    final today = ref.read(clockProvider).now();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final validation = validateTyped(value.text, today);
          return AlertDialog(
            title: const Text('Correct number'),
            content: SizedBox(
              width: 360,
              child: RegistrationField(controller: controller, validation: validation, autofocus: true),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: validation.isValid
                    ? () async {
                        await ref.read(repositoryProvider).updateNumber(record.id, validation.number!);
                        if (context.mounted) Navigator.pop(context, true);
                      }
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Number updated')));
    }
  }
}
