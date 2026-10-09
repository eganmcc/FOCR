import 'dart:typed_data';

import '../core/extraction/registration_number.dart';
import 'models.dart';

/// Local, offline-first store for captures and confirmed records (contracts/interfaces.md).
abstract interface class SubmissionRepository {
  /// Returns the new capture id.
  Future<String> saveCapture(CaptureDraft draft);
  Future<void> deleteCapture(String captureId);

  /// Saves with `syncStatus = pending`.
  Future<RegistrationRecord> saveRecord(RecordDraft draft);

  /// Most recent record with this number, if any (FR-012).
  Future<RegistrationRecord?> findByNumber(String number);

  /// Only allowed while the record is pending. Throws [StateError] otherwise.
  Future<RegistrationRecord> updateNumber(String recordId, RegistrationNumber number);

  /// All records, newest first (FR-014).
  Stream<List<RegistrationRecord>> watchAll();

  Future<Uint8List?> captureImage(String captureId);
}
