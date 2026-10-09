import 'dart:typed_data';

import '../core/extraction/registration_number.dart';

enum EntryMethod {
  /// OCR value confirmed unchanged.
  auto,

  /// OCR value changed by the salesperson.
  edited,

  /// No OCR result; typed by hand.
  manual,
}

enum SyncStatus { pending, synced }

/// A processed image (data-model.md). The raw OCR text never leaves the device (FR-015).
class Capture {
  const Capture({
    required this.id,
    required this.imageJpeg,
    required this.rotationDegrees,
    required this.rawText,
    required this.createdAt,
  });

  final String id;

  /// Normalized JPEG, longest side ≤ 1280 px.
  final Uint8List imageJpeg;
  final int rotationDegrees;
  final String rawText;
  final DateTime createdAt;
}

class CaptureDraft {
  const CaptureDraft({required this.imageJpeg, required this.rotationDegrees, required this.rawText});

  final Uint8List imageJpeg;
  final int rotationDegrees;
  final String rawText;
}

/// A confirmed registration number (data-model.md).
class RegistrationRecord {
  const RegistrationRecord({
    required this.id,
    required this.number,
    required this.format,
    required this.applicationDate,
    required this.captureId,
    required this.entryMethod,
    required this.duplicateOverride,
    required this.syncStatus,
    required this.confirmedAt,
    this.syncedAt,
  });

  final String id;
  final String number;
  final RegistrationFormat format;

  /// Long format only.
  final DateTime? applicationDate;
  final String? captureId;
  final EntryMethod entryMethod;
  final bool duplicateOverride;
  final SyncStatus syncStatus;
  final DateTime confirmedAt;
  final DateTime? syncedAt;

  Map<String, Object?> toMap() => {
        'number': number,
        'format': format.name,
        'applicationDate': applicationDate == null ? null : _isoDate(applicationDate!),
        'captureId': captureId,
        'entryMethod': entryMethod.name,
        'duplicateOverride': duplicateOverride,
        'syncStatus': syncStatus.name,
        'confirmedAt': confirmedAt.toUtc().toIso8601String(),
        'syncedAt': syncedAt?.toUtc().toIso8601String(),
      };

  static RegistrationRecord fromMap(String id, Map<String, Object?> m) => RegistrationRecord(
        id: id,
        number: m['number']! as String,
        format: RegistrationFormat.values.byName(m['format']! as String),
        applicationDate: m['applicationDate'] == null ? null : DateTime.parse(m['applicationDate']! as String),
        captureId: m['captureId'] as String?,
        entryMethod: EntryMethod.values.byName(m['entryMethod']! as String),
        duplicateOverride: m['duplicateOverride']! as bool,
        syncStatus: SyncStatus.values.byName(m['syncStatus']! as String),
        confirmedAt: DateTime.parse(m['confirmedAt']! as String),
        syncedAt: m['syncedAt'] == null ? null : DateTime.parse(m['syncedAt']! as String),
      );

  RegistrationRecord copyWith({RegistrationNumber? number, EntryMethod? entryMethod}) => RegistrationRecord(
        id: id,
        number: number?.value ?? this.number,
        format: number?.format ?? format,
        applicationDate: number == null ? applicationDate : number.applicationDate,
        captureId: captureId,
        entryMethod: entryMethod ?? this.entryMethod,
        duplicateOverride: duplicateOverride,
        syncStatus: syncStatus,
        confirmedAt: confirmedAt,
        syncedAt: syncedAt,
      );
}

class RecordDraft {
  const RecordDraft({
    required this.number,
    required this.captureId,
    required this.entryMethod,
    this.duplicateOverride = false,
  });

  final RegistrationNumber number;
  final String? captureId;
  final EntryMethod entryMethod;
  final bool duplicateOverride;
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
